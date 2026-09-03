const PDFDocument = require('pdfkit');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const InventoryLog = require('../models/InventoryLog');
const Product = require('../models/Product');
const Shop = require('../models/Shop');
const config = require('../config');
const { sendMail } = require('./emailService');
const { startOfDay, endOfDay } = require('../utils/stats');

const currency = (n) => `Rs. ${Number(n || 0).toLocaleString('en-PK')}`;

const buildDailyReport = async () => {
  const now = new Date();
  const dayStart = startOfDay(now);
  const dayEnd = endOfDay(now);

  const [sales, expenses, inventoryLogs, shops, lowStockProducts] = await Promise.all([
    Sale.find({ isDeleted: false, createdAt: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 }),
    Expense.find({ isDeleted: false, expenseDate: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .sort({ expenseDate: -1 }),
    InventoryLog.find({ date: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .populate('performedBy', 'name')
      .populate('product', 'name')
      .sort({ date: -1 }),
    Shop.find({ isDeleted: false }),
    Product.find({ isDeleted: false, $expr: { $lte: ['$quantity', '$lowStockThreshold'] } })
      .populate('shop', 'name')
      .sort({ quantity: 1 }),
  ]);

  const totalSales = sales.reduce((s, r) => s + r.totalAmount, 0);
  const totalExpenses = expenses.reduce((s, r) => s + r.amount, 0);
  const totalProfit = sales.reduce((s, r) => s + r.profit, 0);
  const totalStockIn = inventoryLogs.filter((l) => l.actionType === 'stock_in').length;
  const totalStockOut = inventoryLogs.filter((l) => l.actionType === 'stock_out').length;

  return {
    date: now,
    summary: {
      totalSales,
      totalExpenses,
      totalProfit,
      salesCount: sales.length,
      expensesCount: expenses.length,
      totalStockIn,
      totalStockOut,
      totalTransactions: sales.length + expenses.length + inventoryLogs.length,
      shopsCount: shops.length,
      lowStockCount: lowStockProducts.length,
    },
    sales,
    expenses,
    inventoryLogs,
    lowStockProducts,
  };
};

const generateDailyReportPDF = async () => {
  const report = await buildDailyReport();
  const d = report.date;
  const dateStr = d.toLocaleDateString('en-PK', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    // ---- HEADER ----
    doc.fontSize(22).font('Helvetica-Bold').text('MUALLIM CARPETS', { align: 'center' });
    doc.fontSize(10).font('Helvetica').text('Daily Data Report', { align: 'center' });
    doc.fontSize(9).text(dateStr, { align: 'center' });
    doc.moveDown(0.5);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke('#D4AF37');
    doc.moveDown(0.8);

    // ---- SUMMARY BOX ----
    doc.fontSize(13).font('Helvetica-Bold').text('Daily Summary');
    doc.moveDown(0.3);
    const sy = doc.y;
    doc.fontSize(9).font('Helvetica');
    const summaryLines = [
      `Total Sales: ${currency(report.summary.totalSales)} (${report.summary.salesCount} transactions)`,
      `Total Expenses: ${currency(report.summary.totalExpenses)} (${report.summary.expensesCount} transactions)`,
      `Net Profit: ${currency(report.summary.totalProfit)}`,
      `Stock In: ${report.summary.totalStockIn}  |  Stock Out: ${report.summary.totalStockOut}`,
      `Total Transactions: ${report.summary.totalTransactions}`,
      `Active Shops: ${report.summary.shopsCount}  |  Low Stock Alerts: ${report.summary.lowStockCount}`,
    ];
    for (const line of summaryLines) {
      doc.text(line);
    }
    doc.moveDown(0.8);

    // ---- SALES TABLE ----
    if (report.sales.length > 0) {
      doc.fontSize(13).font('Helvetica-Bold').text('Sales');
      doc.moveDown(0.3);
      const headers = ['#', 'Invoice', 'Shop', 'Customer', 'Amount', 'Profit', 'Payment'];
      const rows = report.sales.map((s, i) => [
        `${i + 1}`,
        s.invoiceNo,
        (s.shop && s.shop.name) || '-',
        s.customerName,
        currency(s.totalAmount),
        currency(s.profit),
        (s.paymentMethod || '').toUpperCase(),
      ]);
      drawTable(doc, headers, rows);
      doc.moveDown(0.8);
    }

    // ---- EXPENSES TABLE ----
    if (report.expenses.length > 0) {
      doc.fontSize(13).font('Helvetica-Bold').text('Expenses');
      doc.moveDown(0.3);
      const headers = ['#', 'Category', 'Shop', 'Amount', 'Description'];
      const rows = report.expenses.map((e, i) => [
        `${i + 1}`,
        (e.category || '').toUpperCase(),
        (e.shop && e.shop.name) || '-',
        currency(e.amount),
        (e.description || '-').slice(0, 40),
      ]);
      drawTable(doc, headers, rows);
      doc.moveDown(0.8);
    }

    // ---- INVENTORY TRANSACTIONS TABLE ----
    if (report.inventoryLogs.length > 0) {
      doc.fontSize(13).font('Helvetica-Bold').text('Inventory Transactions');
      doc.moveDown(0.3);
      const headers = ['#', 'Type', 'Product', 'Qty', 'Shop', 'By'];
      const rows = report.inventoryLogs.map((l, i) => [
        `${i + 1}`,
        l.actionType === 'stock_in' ? 'STOCK IN' : 'STOCK OUT',
        (l.product && l.product.name) || (l.productName || '-'),
        `${l.quantity}`,
        (l.shop && l.shop.name) || '-',
        (l.performedBy && l.performedBy.name) || '-',
      ]);
      drawTable(doc, headers, rows);
      doc.moveDown(0.8);
    }

    // ---- LOW STOCK ALERTS ----
    if (report.lowStockProducts.length > 0) {
      doc.fontSize(13).font('Helvetica-Bold').text('Low Stock Alerts');
      doc.moveDown(0.3);
      const headers = ['#', 'Product', 'Shop', 'Stock', 'Threshold'];
      const rows = report.lowStockProducts.map((p, i) => [
        `${i + 1}`,
        p.name,
        (p.shop && p.shop.name) || '-',
        `${p.quantity}`,
        `${p.lowStockThreshold}`,
      ]);
      drawTable(doc, headers, rows);
    }

    // ---- FOOTER ----
    doc.moveDown(1.5);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke('#D4AF37');
    doc.moveDown(0.4);
    doc.fontSize(8).font('Helvetica').fillColor('#888888')
      .text('Generated by MCQ (Muallim Carpets) Business Management System', { align: 'center' });

    doc.end();
  });
};

function drawTable(doc, headers, rows) {
  const x0 = 40;
  const colWidths = computeColWidths(headers, rows, 515);
  const fontH = 8;
  const rowH = 16;

  // Header row
  doc.font('Helvetica-Bold').fontSize(fontH).fillColor('#111111');
  let x = x0;
  for (let i = 0; i < headers.length; i++) {
    doc.text(headers[i], x + 4, doc.y, { width: colWidths[i] - 8, align: 'left' });
    x += colWidths[i];
  }
  doc.moveDown(0.1);
  doc.moveTo(x0, doc.y).lineTo(x0 + 515, doc.y).stroke('#CCCCCC');
  doc.moveDown(0.3);

  // Data rows
  doc.font('Helvetica').fontSize(fontH).fillColor('#333333');
  for (const row of rows) {
    if (doc.y > 760) {
      doc.addPage();
      doc.fontSize(fontH).font('Helvetica-Bold').fillColor('#111111');
      let rx = x0;
      for (let i = 0; i < headers.length; i++) {
        doc.text(headers[i], rx + 4, doc.y, { width: colWidths[i] - 8, align: 'left' });
        rx += colWidths[i];
      }
      doc.moveDown(0.1);
      doc.moveTo(x0, doc.y).lineTo(x0 + 515, doc.y).stroke('#CCCCCC');
      doc.moveDown(0.3);
      doc.font('Helvetica').fontSize(fontH).fillColor('#333333');
    }
    let x = x0;
    for (let i = 0; i < row.length; i++) {
      const align = i === row.length - 1 ? 'right' : 'left';
      doc.text(row[i] || '', x + 4, doc.y, { width: colWidths[i] - 8, align });
      x += colWidths[i];
    }
    doc.moveDown(0.1);
    doc.moveTo(x0, doc.y).lineTo(x0 + 515, doc.y).stroke('#EEEEEE');
    doc.moveDown(0.25);
  }
}

function computeColWidths(headers, rows, totalWidth) {
  const maxLens = headers.map((h, i) => {
    const hLen = h.length;
    const maxRow = rows.reduce((m, r) => Math.max(m, (r[i] || '').length), 0);
    return Math.max(hLen, maxRow);
  });
  const sum = maxLens.reduce((a, b) => a + b, 0);
  return maxLens.map((l) => Math.max(40, Math.round((l / sum) * totalWidth)));
}

const sendDailyReportEmail = async () => {
  try {
    if (!config.email.enabled) {
      console.log('[DailyReport] Skipped — SMTP not configured.');
      return;
    }
    const recipient = config.email.to;
    if (!recipient) {
      console.log('[DailyReport] Skipped — REPORT_RECIPIENT_EMAIL not set.');
      return;
    }
    console.log('[DailyReport] Generating PDF report...');
    const pdfBuffer = await generateDailyReportPDF();
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10);

    await sendMail({
      to: recipient,
      subject: `MCQ Daily Report — ${dateStr}`,
      html: `<p>Hi Admin,</p>
<p>Please find attached the daily data report for <strong>${dateStr}</strong>.</p>
<p>This report includes:</p>
<ul>
  <li>Daily sales summary &amp; details</li>
  <li>Expenses summary</li>
  <li>Inventory transactions (stock in / stock out)</li>
  <li>Low stock alerts</li>
</ul>
<p>Best regards,<br/>MCQ Business Management System</p>`,
      attachments: [
        {
          filename: `MCQ_Daily_Report_${dateStr}.pdf`,
          content: pdfBuffer,
          contentType: 'application/pdf',
        },
      ],
    });
    console.log('[DailyReport] Email sent successfully.');
  } catch (err) {
    console.error('[DailyReport] Error:', err.message);
  }
};

module.exports = { buildDailyReport, generateDailyReportPDF, sendDailyReportEmail };
