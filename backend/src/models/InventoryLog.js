const mongoose = require('mongoose');

const inventoryLogSchema = new mongoose.Schema(
  {
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    productName: { type: String, default: '' },
    actionType: { type: String, enum: ['stock_in', 'stock_out'], required: true },
    quantity: { type: Number, required: true, min: 0 },
    previousStock: { type: Number, required: true, default: 0 },
    newStock: { type: Number, required: true, default: 0 },
    supplier: { type: String, default: '' },
    reason: { type: String, default: '' },
    reference: { type: String, default: '' },
    date: { type: Date, default: Date.now },
    performedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

inventoryLogSchema.index({ shop: 1, date: -1 });
inventoryLogSchema.index({ product: 1 });

module.exports = mongoose.model('InventoryLog', inventoryLogSchema);
