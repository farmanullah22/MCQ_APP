const mongoose = require('mongoose');
const Sale = require('../models/Sale');
const Product = require('../models/Product');
const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const generateInvoiceNo = async () => {
  const date = new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const rand = Math.floor(1000 + Math.random() * 9000);
  let invoiceNo = `INV-${y}${m}${d}-${rand}`;
  while (await Sale.findOne({ invoiceNo })) {
    invoiceNo = `INV-${y}${m}${d}-${rand++}`;
  }
  return invoiceNo;
};

// Managers must never see margins, so every cost price is stripped from the
// payload they receive.
const MANAGER_SAFE_SELECT = '-profit -items.costPrice -returns.costPrice -exchanges.costPrice';
const managerSelect = (req) => (req.user.role === 'manager' ? MANAGER_SAFE_SELECT : '');

const round = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;

const loadSaleForEdit = async (req, id) => {
  const sale = await Sale.findById(id);
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  if (req.user.role === 'manager' && sale.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage sales of your assigned shop.');
  }
  return sale;
};

// Guards against returning more units than were actually sold. Returns and
// exchanges accumulate across multiple visits to the same invoice.
const buildReturnableBalances = (sale) => {
  const sold = new Map();
  for (const item of sale.items || []) {
    const key = item.product.toString();
    sold.set(key, (sold.get(key) || 0) + item.quantity);
  }
  for (const ret of sale.returns || []) {
    const key = ret.product.toString();
    sold.set(key, (sold.get(key) || 0) - ret.quantity);
  }
  return sold;
};

// Pushes a message onto the admin notification feed. Notifications are a
// side-channel, so a failure here must never fail the business operation.
const notifyAdmins = async (title, body, type, data) => {
  try {
    const User = require('../models/User');
    const admins = await User.find({ role: 'admin', isActive: true });
    if (admins.length === 0) return;
    await Notification.insertMany(
      admins.map((admin) => ({ user: admin._id, title, body, type, data }))
    );
  } catch (err) {
    console.warn(`[notifyAdmins] skipped "${title}": ${err.message}`);
  }
};

// Mirrors the invoice's money movement onto the customer's running balance so
// receivables and the ledger never drift from the invoices. A positive delta
// raises what they owe, a negative one credits money back against their dues.
// Best-effort: the invoice is already saved by the time this runs, so a failure
// must be logged rather than turned into a failed request.
const syncCustomerLedger = async (sale, delta, note, userId) => {
  const phone = (sale.customerPhone || '').trim();
  if (!phone || !delta) return;

  try {
    const Customer = require('../models/Customer');
    const customer = await Customer.findOne({
      isDeleted: false,
      shop: sale.shop,
      phone: { $regex: `^${phone.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
    });
    if (!customer) return;

    if (delta > 0) {
      customer.balance += delta;
      customer.transactions.push({ amount: delta, type: 'charge', note, date: new Date(), by: userId });
    } else {
      const amount = Math.abs(delta);
      customer.balance = Math.max(customer.balance - amount, 0);
      customer.transactions.push({ amount, type: 'payment', note, date: new Date(), by: userId });
    }
    await customer.save();
  } catch (err) {
    console.warn(`[syncCustomerLedger] ${note}: ${err.message}`);
  }
};

const listSales = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.from || req.query.to) {
    filter.createdAt = {};
    if (req.query.from) filter.createdAt.$gte = new Date(req.query.from);
    if (req.query.to) filter.createdAt.$lte = new Date(req.query.to);
  }
  if (req.query.paymentMethod) filter.paymentMethod = req.query.paymentMethod;

  const [sales, total] = await Promise.all([
    Sale.find(filter)
      .populate('shop', 'name')
      .populate('createdBy', 'name role')
      // Managers must not see profit margins or cost prices.
      .select(managerSelect(req))
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Sale.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Sales fetched', { sales, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id)
    .populate('shop', 'name address contactNumber')
    .populate('createdBy', 'name role')
    .select(managerSelect(req));
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  res.json(ApiResponse.ok('Sale fetched', sale));
});

const createSale = asyncHandler(async (req, res) => {
  const { customerName, customerPhone, items, discount, paymentMethod, notes, paidAmount } = req.body;
  if (!items || !Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, 'At least one product item is required.');
  }

  const shopId =
    req.user.role === 'manager'
      ? req.user.assignedShop._id
      : req.body.shopId || (await require('../models/Shop').findOne({ isDeleted: false }))._id;
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const saleItems = [];
  let subtotal = 0;
  let profit = 0;

  for (const item of items) {
    const product = await Product.findById(item.productId).populate('category', 'name');
    if (!product || product.isDeleted) throw new ApiError(404, `Product not found for item.`);
    if (product.shop.toString() !== shopId.toString()) {
      throw new ApiError(400, `"${product.name}" does not belong to this shop.`);
    }
    const qty = Number(item.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Quantity must be positive.');
    if (product.quantity < qty) {
      throw new ApiError(400, `Insufficient stock for "${product.name}" (only ${product.quantity} left).`);
    }

    const unitPrice = item.unitPrice !== undefined ? Number(item.unitPrice) : product.sellingPrice;
    const itemTotal = qty * unitPrice;
    product.quantity -= qty;
    await product.save();

    saleItems.push({
      product: product._id,
      productName: product.name,
      quantity: qty,
      unitPrice,
      totalAmount: itemTotal,
      costPrice: product.costPrice,
    });
    subtotal += itemTotal;
    profit += (unitPrice - product.costPrice) * qty;
  }

  const discountValue = Number(discount) || 0;
  if (discountValue > subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');

  const totalAmount = subtotal - discountValue;
  const paidValue = Math.min(Math.max(Number(paidAmount) || 0, 0), totalAmount);
  const dueValue = totalAmount - paidValue;

  const invoiceNo = await generateInvoiceNo();
  const method = paymentMethod || 'cash';
  const sale = new Sale({
    invoiceNo,
    shop: shopId,
    customerName: customerName || 'Walk-in Customer',
    customerPhone: customerPhone || '',
    items: saleItems,
    subtotal,
    discount: discountValue,
    totalAmount,
    paidAmount: paidValue,
    dueAmount: dueValue,
    profit,
    paymentMethod: method,
    notes: notes || '',
    createdBy: req.user._id,
    payments: paidValue
      ? [{ type: 'sale', amount: paidValue, method, note: 'Payment at the time of sale', by: req.user._id }]
      : [],
  });
  // Derived fields (netTotal, refundTotal, ...) are filled in here.
  sale.recalculateTotals();
  await sale.save();

  await recordAudit(req, {
    actionType: 'CREATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    newData: sale.toObject(),
    remarks: `Sale ${invoiceNo} created - Rs. ${sale.totalAmount}`,
    shopId,
  });

  // Notify admins about the new sale
  await notifyAdmins(
    'New Sale',
    `New sale ${invoiceNo} of Rs. ${sale.totalAmount}`,
    'new_sale',
    { saleId: sale._id, invoiceNo }
  );

  // Send the PDF receipt to the customer's WhatsApp number (if one is given
  // and WhatsApp is configured). Failures never affect the sale itself.
  const whatsappService = require('../services/whatsappService');
  sale.whatsappReceipt = await whatsappService.sendWhatsAppReceipt(sale, sale.customerPhone);

  // Link the sale to a registered customer (matched by phone) and update
  // their purchase history. Credit sales also increase the outstanding due.
  const phone = (sale.customerPhone || '').trim();
  if (phone) {
    const Customer = require('../models/Customer');
    const customer = await Customer.findOne({
      isDeleted: false,
      shop: shopId,
      phone: { $regex: `^${phone.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
    });
    if (customer) {
      customer.totalSpent += sale.totalAmount;
      customer.purchaseCount += 1;
      customer.lastPurchaseAt = new Date();
      if (sale.dueAmount > 0) {
        customer.balance += sale.dueAmount;
        customer.transactions.push({
          amount: sale.dueAmount,
          type: 'charge',
          note: `Sale ${invoiceNo} (paid ${paidValue}, due ${dueValue})`,
          date: new Date(),
          by: req.user._id,
        });
      }
      if (sale.paidAmount > 0) {
        customer.transactions.push({
          amount: sale.paidAmount,
          type: 'payment',
          note: `Payment received on sale ${invoiceNo}`,
          date: new Date(),
          by: req.user._id,
        });
      }
      await customer.save();
    }
  }

  res.status(201).json(ApiResponse.created('Sale created successfully', sale));
});

const updateSale = asyncHandler(async (req, res) => {
  const sale = await loadSaleForEdit(req, req.params.id);
  const oldData = sale.toObject();

  // Item lines are deliberately not editable here - adding, returning and
  // exchanging stock all move inventory, so they live in their own endpoints.
  const allowed = ['customerName', 'customerPhone', 'discount', 'paymentMethod', 'notes'];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) sale[field] = req.body[field];
  });
  if (sale.discount > sale.subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');
  sale.totalAmount = round(sale.subtotal - sale.discount);
  sale.recalculateTotals();
  await sale.save();

  await recordAudit(req, {
    actionType: 'UPDATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks: `Sale ${sale.invoiceNo} updated`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale updated', sale));
});

const deleteSale = asyncHandler(async (req, res) => {
  const { deleteReason, restock = false } = req.body;
  const sale = await loadSaleForEdit(req, req.params.id);
  const oldData = sale.toObject();

  if (restock) {
    // Unwind the net effect of the whole invoice: units originally sold, minus
    // anything already handed back, plus replacements given during exchanges.
    const deltas = new Map();
    const apply = (product, qty) => {
      const key = product.toString();
      deltas.set(key, (deltas.get(key) || 0) + qty);
    };
    sale.items.forEach((i) => apply(i.product, i.quantity));
    sale.returns.forEach((r) => apply(r.product, -r.quantity));
    sale.exchanges.forEach((e) => apply(e.product, e.quantity));

    for (const [productId, delta] of deltas) {
      if (delta === 0) continue;
      await Product.findByIdAndUpdate(productId, { $inc: { quantity: delta } });
    }
  }

  sale.isDeleted = true;
  sale.deletedBy = req.user._id;
  sale.deletedAt = new Date();
  sale.deleteReason = deleteReason || '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'DELETE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Sale ${sale.invoiceNo} soft-deleted${restock ? ' (restocked)' : ''}`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale deleted'));
});

const restoreSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id);
  if (!sale) throw new ApiError(404, 'Sale not found.');

  sale.isDeleted = false;
  sale.deletedBy = null;
  sale.deletedAt = null;
  sale.deleteReason = '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'RESTORE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData: null,
    newData: sale.toObject(),
    status: 'restored',
    remarks: `Sale ${sale.invoiceNo} restored`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale restored', sale));
});

// Re-reads a product for an adjustment, checking shop ownership and stock.
const loadAdjustableProduct = async (productId, shopId, qty) => {
  if (!productId) throw new ApiError(400, 'Every line needs a product.');
  if (!mongoose.isValidObjectId(productId)) throw new ApiError(400, 'Invalid product id.');
  const product = await Product.findById(productId).populate('category', 'name');
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  if (product.shop.toString() !== shopId.toString()) {
    throw new ApiError(400, `"${product.name}" does not belong to this shop.`);
  }
  if (product.quantity < qty) {
    throw new ApiError(
      400,
      `Insufficient stock for "${product.name}" (only ${product.quantity} left).`
    );
  }
  return product;
};

// Adds extra products to an invoice that already exists. Stock leaves the shop
// and the totals are recomputed, so this behaves like appending to the bill.
const addSaleItems = asyncHandler(async (req, res) => {
  const { items, notes } = req.body;
  if (!Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, 'At least one product item is required.');
  }

  const sale = await loadSaleForEdit(req, req.params.id);
  const oldData = sale.toObject();

  let addedValue = 0;
  for (const item of items) {
    const qty = Number(item.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Quantity must be positive.');

    const product = await loadAdjustableProduct(item.productId, sale.shop, qty);
    const unitPrice =
      item.unitPrice !== undefined ? Number(item.unitPrice) : product.sellingPrice;

    await Product.findByIdAndUpdate(product._id, { $inc: { quantity: -qty } });
    sale.items.push({
      product: product._id,
      productName: product.name,
      quantity: qty,
      unitPrice,
      totalAmount: round(qty * unitPrice),
      costPrice: product.costPrice,
    });
    addedValue += qty * unitPrice;
  }

  sale.subtotal = round(sale.subtotal + addedValue);
  sale.totalAmount = round(sale.subtotal - sale.discount);
  if (notes) sale.notes = notes;
  sale.recalculateTotals();
  await sale.save();

  await recordAudit(req, {
    actionType: 'UPDATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks: `Products added to ${sale.invoiceNo} - Rs. ${round(addedValue)}`,
    shopId: sale.shop,
  });

  await syncCustomerLedger(
    sale,
    round(sale.dueAmount - (oldData.dueAmount || 0)),
    `Products added to sale ${sale.invoiceNo}`,
    req.user._id
  );

  res.json(ApiResponse.ok('Products added to sale', sale));
});

// Shared engine behind both the plain-return and the exchange flows.
// `incoming` are products being handed back (restocked), `outgoing` are
// replacements being handed out (decremented). Extras let the caller settle the
// resulting price difference as a payment or a refund in the same request.
// Deliberately a plain async function, not an asyncHandler-wrapped one: the
// route handlers below take the config and are the ones that wrap, so
// asyncHandler keeps a real `next` to forward rejections to on the first hop.
const applyAdjustments = async (req, res, { requireIncoming, requireOutgoing }) => {
  const { incoming = [], outgoing = [], reason = '', note = '', settlement } = req.body;
  if (requireIncoming && (!Array.isArray(incoming) || incoming.length === 0)) {
    throw new ApiError(400, 'Select at least one product to return.');
  }
  if (requireOutgoing && (!Array.isArray(outgoing) || outgoing.length === 0)) {
    throw new ApiError(400, 'Select at least one replacement product.');
  }

  const sale = await loadSaleForEdit(req, req.params.id);
  const oldData = sale.toObject();
  const balances = buildReturnableBalances(sale);
  const kind = requireOutgoing ? 'exchange' : 'return';

  // 1. Take the goods back and put the stock straight back on the shelf.
  for (const entry of incoming) {
    if (!entry || !entry.productId) {
      throw new ApiError(400, 'Every returned line needs a product.');
    }
    const qty = Number(entry.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Return quantity must be positive.');

    const key = entry.productId.toString();
    const product = await Product.findById(entry.productId).populate('category', 'name');
    if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
    if (!product.shop || product.shop.toString() !== sale.shop.toString()) {
      throw new ApiError(400, `"${product.name}" does not belong to this shop.`);
    }

    const remaining = balances.get(key) || 0;
    if (qty > remaining) {
      throw new ApiError(
        400,
        remaining > 0
          ? `Cannot return ${qty} x "${product.name}" - only ${remaining} still on this invoice.`
          : `"${product.name}" was not sold on this invoice.`
      );
    }
    balances.set(key, remaining - qty);

    const unitPrice =
      entry.unitPrice !== undefined
        ? Number(entry.unitPrice)
        : (sale.items.find((i) => i.product.toString() === key) || {}).unitPrice || 0;

    await Product.findByIdAndUpdate(product._id, { $inc: { quantity: qty } });

    const record = sale.returns.create({
      product: product._id,
      productName: product.name,
      quantity: qty,
      unitPrice,
      totalAmount: round(qty * unitPrice),
      costPrice: product.costPrice,
      restockedQuantity: qty,
      reason,
      kind,
      by: req.user._id,
    });
    sale.returns.push(record);
  }

  // 2. Hand out the replacements and take their stock.
  for (const entry of outgoing) {
    const qty = Number(entry.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Replacement quantity must be positive.');

    const product = await loadAdjustableProduct(entry.productId, sale.shop, qty);
    const unitPrice =
      entry.unitPrice !== undefined ? Number(entry.unitPrice) : product.sellingPrice;

    await Product.findByIdAndUpdate(product._id, { $inc: { quantity: -qty } });

    const paired = incoming.find((i) => i.productId.toString() === entry.productId.toString());
    const record = sale.exchanges.create({
      product: product._id,
      productName: product.name,
      quantity: qty,
      unitPrice,
      totalAmount: round(qty * unitPrice),
      costPrice: product.costPrice,
      pairedReturnQuantity: paired ? Number(paired.quantity) || 0 : 0,
      note,
      by: req.user._id,
    });
    sale.exchanges.push(record);

    // Cross-link the replacement back onto the return for traceability.
    if (paired) {
      const returnRecord = sale.returns.find(
        (r) => r.product.toString() === entry.productId.toString() && !r.exchangeItemId
      );
      if (returnRecord) returnRecord.exchangeItemId = record._id;
    }
  }

  // returnTotal/exchangeTotal are derived, so they only reflect this request
  // once the ledger has been rebuilt. Report what THIS adjustment moved rather
  // than the invoice-wide running totals.
  const prevReturnTotal = sale.returnTotal;
  const prevExchangeTotal = sale.exchangeTotal;
  sale.recalculateTotals();
  const returnValue = round(sale.returnTotal - prevReturnTotal);
  const exchangeValue = round(sale.exchangeTotal - prevExchangeTotal);

  // 3. Settle the difference the manager took from the customer (or owes back).
  let settlementResult = null;
  if (settlement && Number(settlement.amount) > 0) {
    const direction = settlement.direction === 'refund' ? 'refund' : 'payment';
    const paidNow = round(
      sale.payments.reduce(
        (sum, p) => sum + (p.type === 'refund' ? -p.amount : p.amount),
        0
      )
    );
    const amount = round(Number(settlement.amount));

    if (direction === 'refund') {
      if (amount > paidNow) {
        throw new ApiError(
          400,
          `Refund of Rs. ${amount} exceeds the Rs. ${paidNow} collected on this invoice.`
        );
      }
      // A return only entitles the customer to the value handed back, less
      // anything already handed over as a replacement or refunded earlier.
      const refundedSoFar = round(
        sale.payments
          .filter((p) => p.type === 'refund')
          .reduce((sum, p) => sum + p.amount, 0)
      );
      const entitled = round(sale.returnTotal - sale.exchangeTotal);
      const refundable = Math.max(entitled - refundedSoFar, 0);
      if (amount > refundable) {
        throw new ApiError(
          400,
          refundable > 0
            ? `Refund of Rs. ${amount} exceeds the Rs. ${refundable} refundable on this return.`
            : 'Nothing is refundable - this return has already been settled.'
        );
      }
    } else {
      // Only the shortfall created by this adjustment may be collected.
      const shortfall = round(Math.max(sale.dueAmount, 0));
      if (amount > shortfall) {
        throw new ApiError(
          400,
          `Payment of Rs. ${amount} exceeds the Rs. ${shortfall} due on this invoice.`
        );
      }
    }

    const method = settlement.method || sale.paymentMethod || 'cash';
    sale.payments.push({
      type: direction === 'refund' ? 'refund' : kind === 'exchange' ? 'exchange_settlement' : 'payment',
      amount,
      method,
      note: settlement.note || (kind === 'exchange' ? 'Exchange settlement' : 'Return settlement'),
      by: req.user._id,
    });
    settlementResult = { direction, amount, method };
  }

  // Recompute once more so paid/due reflect the settlement entry.
  sale.recalculateTotals();
  await sale.save();

  await recordAudit(req, {
    actionType: kind === 'exchange' ? 'EXCHANGE_SALE_ITEM' : 'RETURN_SALE_ITEM',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks:
      kind === 'exchange'
        ? `Exchange on ${sale.invoiceNo} - returned Rs. ${returnValue}, replaced Rs. ${exchangeValue}`
        : `Return on ${sale.invoiceNo} - Rs. ${returnValue} restocked`,
    shopId: sale.shop,
  });

  await notifyAdmins(
    kind === 'exchange' ? 'Sale Exchange' : 'Sale Return',
    `${kind === 'exchange' ? 'Exchange' : 'Return'} on ${sale.invoiceNo} - returned Rs. ${returnValue}${
      kind === 'exchange' ? `, replaced Rs. ${exchangeValue}` : ''
    }`,
    kind === 'exchange' ? 'sale_exchange' : 'sale_return',
    { saleId: sale._id, invoiceNo: sale.invoiceNo }
  );

  // Money owed to the shop moves with the invoice; refunds credit it back.
  await syncCustomerLedger(
    sale,
    round(sale.dueAmount - (oldData.dueAmount || 0)),
    `${kind === 'exchange' ? 'Exchange' : 'Return'} on sale ${sale.invoiceNo}`,
    req.user._id
  );

  res.json(
    ApiResponse.ok(
      kind === 'exchange' ? 'Exchange recorded' : 'Return recorded',
      { sale, settlement: settlementResult }
    )
  );
};

const returnSaleItems = asyncHandler((req, res) =>
  applyAdjustments(req, res, { requireIncoming: true, requireOutgoing: false })
);

const exchangeSaleItems = asyncHandler((req, res) =>
  applyAdjustments(req, res, { requireIncoming: true, requireOutgoing: true })
);

// Records a standalone top-up or refund against an invoice, outside of any
// return or exchange.
const recordSalePayment = asyncHandler(async (req, res) => {
  const { type = 'payment', amount, method, note = '' } = req.body;
  const value = Number(amount);
  if (!value || value <= 0) throw new ApiError(400, 'Amount must be greater than zero.');
  if (!['payment', 'refund'].includes(type)) {
    throw new ApiError(400, 'Type must be either "payment" or "refund".');
  }

  const sale = await loadSaleForEdit(req, req.params.id);
  const oldData = sale.toObject();

  if (type === 'refund') {
    const collected = round(
      sale.payments.reduce((sum, p) => sum + (p.type === 'refund' ? -p.amount : p.amount), 0)
    );
    if (value > collected) {
      throw new ApiError(
        400,
        `Refund of Rs. ${value} exceeds the Rs. ${collected} collected on this invoice.`
      );
    }
  } else {
    const outstanding = round(sale.dueAmount);
    if (value > outstanding) {
      throw new ApiError(
        400,
        `Payment of Rs. ${value} exceeds the Rs. ${outstanding} still due on this invoice.`
      );
    }
  }

  const payMethod = method || sale.paymentMethod || 'cash';
  sale.payments.push({ type, amount: value, method: payMethod, note, by: req.user._id });
  sale.recalculateTotals();
  await sale.save();

  await recordAudit(req, {
    actionType: type === 'refund' ? 'REFUND_SALE' : 'SALE_PAYMENT',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks:
      type === 'refund'
        ? `Refund of Rs. ${value} on ${sale.invoiceNo}`
        : `Payment of Rs. ${value} on ${sale.invoiceNo}`,
    shopId: sale.shop,
  });

  await syncCustomerLedger(
    sale,
    round(sale.dueAmount - (oldData.dueAmount || 0)),
    `${type === 'refund' ? 'Refund' : 'Payment'} on sale ${sale.invoiceNo}`,
    req.user._id
  );

  res.json(ApiResponse.ok(type === 'refund' ? 'Refund recorded' : 'Payment recorded', sale));
});

module.exports = {
  listSales,
  getSale,
  createSale,
  updateSale,
  deleteSale,
  restoreSale,
  addSaleItems,
  returnSaleItems,
  exchangeSaleItems,
  recordSalePayment,
};
