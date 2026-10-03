const mongoose = require('mongoose');

const saleItemSchema = new mongoose.Schema(
  {
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    productName: { type: String, default: '' },
    quantity: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    costPrice: { type: Number, default: 0 },
  },
  { _id: false }
);

// A product handed back by the customer. `exchangePairId` ties a return to the
// replacement item that was issued in the same exchange, when there was one.
const saleReturnSchema = new mongoose.Schema(
  {
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    productName: { type: String, default: '' },
    quantity: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    costPrice: { type: Number, default: 0 },
    restockedQuantity: { type: Number, default: 0, min: 0 },
    reason: { type: String, default: '' },
    kind: { type: String, enum: ['return', 'exchange'], default: 'return' },
    exchangeItemId: { type: mongoose.Schema.Types.ObjectId, default: null },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    date: { type: Date, default: Date.now },
  },
  { _id: true }
);

// A replacement product handed to the customer as part of an exchange.
const saleExchangeSchema = new mongoose.Schema(
  {
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    productName: { type: String, default: '' },
    quantity: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    costPrice: { type: Number, default: 0 },
    pairedReturnQuantity: { type: Number, default: 0, min: 0 },
    note: { type: String, default: '' },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    date: { type: Date, default: Date.now },
  },
  { _id: true }
);

// Append-only money trail for the invoice: the original sale payment, later
// top-ups, refunds given for returns, and exchange settlements.
const salePaymentSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['sale', 'payment', 'refund', 'exchange_settlement'],
      required: true,
    },
    amount: { type: Number, required: true, min: 0 },
    method: {
      type: String,
      enum: ['cash', 'bank', 'easypaisa', 'jazzcash', 'credit'],
      default: 'cash',
    },
    note: { type: String, default: '' },
    date: { type: Date, default: Date.now },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { _id: false }
);

const saleSchema = new mongoose.Schema(
  {
    invoiceNo: { type: String, required: true, unique: true },
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    customerName: { type: String, default: 'Walk-in Customer' },
    customerPhone: { type: String, default: '' },
    items: { type: [saleItemSchema], required: true },
    subtotal: { type: Number, required: true, min: 0, default: 0 },
    discount: { type: Number, default: 0, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    paidAmount: { type: Number, default: 0, min: 0 },
    // Negative means the shop owes the customer (an unrefunded return).
    dueAmount: { type: Number, default: 0 },
    profit: { type: Number, default: 0 },
    paymentMethod: {
      type: String,
      enum: ['cash', 'bank', 'easypaisa', 'jazzcash', 'credit'],
      default: 'cash',
    },
    notes: { type: String, default: '' },

    // --- Returns / exchanges -------------------------------------------------
    returns: { type: [saleReturnSchema], default: [] },
    exchanges: { type: [saleExchangeSchema], default: [] },
    // Value of everything handed back. Stock is always restocked on a return.
    returnTotal: { type: Number, default: 0, min: 0 },
    // Value of everything handed out as a replacement.
    exchangeTotal: { type: Number, default: 0, min: 0 },
    // What the customer owes after returns and exchanges:
    // totalAmount - returnTotal + exchangeTotal
    netTotal: { type: Number, default: 0, min: 0 },
    // Value of refunds the manager has handed back (never above paidAmount).
    refundTotal: { type: Number, default: 0, min: 0 },
    hasAdjustments: { type: Boolean, default: false },
    payments: { type: [salePaymentSchema], default: [] },

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

// Single source of truth for money so every controller recomputes identically.
saleSchema.methods.recalculateTotals = function recalculateTotals() {
  const round = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;

  const returnTotal = round((this.returns || []).reduce((sum, r) => sum + (r.totalAmount || 0), 0));
  const exchangeTotal = round((this.exchanges || []).reduce((sum, e) => sum + (e.totalAmount || 0), 0));

  const itemSubtotal = round((this.items || []).reduce((sum, i) => sum + (i.totalAmount || 0), 0));
  // `subtotal` stays as the original bill so the issued invoice never changes
  // retroactively; only the derived figures move.
  const grossTotal = round(Math.max(this.subtotal || itemSubtotal, 0) - (this.discount || 0));

  const netTotal = Math.max(round(grossTotal - returnTotal + exchangeTotal), 0);

  // paidAmount is the running sum of the payment ledger: money in minus refunds.
  // It is deliberately NOT capped at netTotal - when goods come back before the
  // customer has been refunded, paid legitimately exceeds net and the gap is the
  // money still owed to them.
  const ledgerNet = round(
    (this.payments || []).reduce(
      (sum, p) => sum + (p.type === 'refund' ? -(p.amount || 0) : p.amount || 0),
      0
    )
  );
  const paidAmount = Math.max(ledgerNet, 0);
  const refundTotal = round((this.payments || []).reduce(
    (sum, p) => sum + (p.type === 'refund' ? p.amount || 0 : 0),
    0
  ));

  // Profit is rebuilt from the surviving goods so reports stay truthful.
  const itemProfit = round(
    (this.items || []).reduce(
      (sum, i) => sum + ((i.unitPrice || 0) - (i.costPrice || 0)) * (i.quantity || 0),
      0
    )
  );
  const returnProfit = round(
    (this.returns || []).reduce(
      (sum, r) => sum - ((r.unitPrice || 0) - (r.costPrice || 0)) * (r.quantity || 0),
      0
    )
  );
  const exchangeProfit = round(
    (this.exchanges || []).reduce(
      (sum, e) => sum + ((e.unitPrice || 0) - (e.costPrice || 0)) * (e.quantity || 0),
      0
    )
  );

  this.returnTotal = returnTotal;
  this.exchangeTotal = exchangeTotal;
  this.netTotal = netTotal;
  this.paidAmount = paidAmount;
  this.refundTotal = refundTotal;
  this.dueAmount = round(netTotal - paidAmount);
  this.profit = round(itemProfit + returnProfit + exchangeProfit);
  this.hasAdjustments = (this.returns || []).length > 0 || (this.exchanges || []).length > 0;

  return this;
};

saleSchema.index({ shop: 1, createdAt: -1 });
saleSchema.index({ isDeleted: 1 });
saleSchema.index({ shop: 1, customerPhone: 1 });

module.exports = mongoose.model('Sale', saleSchema);
