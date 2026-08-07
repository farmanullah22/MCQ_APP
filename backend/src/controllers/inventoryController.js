const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const assertShopAccess = (product, user) => {
  if (user.role === 'manager' && product.shop.toString() !== user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage inventory of your assigned shop.');
  }
};

const maybeNotifyLowStock = async (product, user) => {
  if (product.quantity <= product.lowStockThreshold) {
    const User = require('../models/User');
    const Shop = require('../models/Shop');
    const [admins, shop] = await Promise.all([
      User.find({ role: 'admin', isActive: true }),
      Shop.findById(product.shop),
    ]);
    const recipients = [
      ...admins.map((a) => a._id),
      ...(shop && shop.manager ? [shop.manager] : []),
    ];
    const title = 'Low Stock Alert';
    const body = `Product "${product.name}" is low on stock (${product.quantity} left).`;
    await Notification.insertMany(
      recipients.map((user) => ({ user, title, body, type: 'low_stock', data: { productId: product._id } }))
    );
  }
};

const stockIn = asyncHandler(async (req, res) => {
  const { productId, quantity, supplier, date, notes } = req.body;
  if (!productId || !quantity || quantity <= 0) {
    throw new ApiError(400, 'Product and a positive quantity are required.');
  }

  const product = await Product.findById(productId);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  assertShopAccess(product, req.user);

  const previousStock = product.quantity;
  product.quantity += Number(quantity);
  await product.save();

  await InventoryLog.create({
    shop: product.shop,
    product: product._id,
    productName: product.name,
    actionType: 'stock_in',
    quantity: Number(quantity),
    previousStock,
    newStock: product.quantity,
    supplier: supplier || '',
    reason: notes || 'Stock In',
    reference: req.body.reference || '',
    date: date || new Date(),
    performedBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'STOCK_IN',
    module: 'inventory',
    recordId: product._id,
    recordType: 'Product',
    oldData: { quantity: previousStock },
    newData: { quantity: product.quantity, stockIn: Number(quantity) },
    remarks: `Stock in ${quantity} x "${product.name}"`,
    shopId: product.shop,
  });

  res.status(201).json(ApiResponse.created('Stock added successfully', { product }));
});

const stockOut = asyncHandler(async (req, res) => {
  const { productId, quantity, reason, date, notes } = req.body;
  if (!productId || !quantity || quantity <= 0) {
    throw new ApiError(400, 'Product and a positive quantity are required.');
  }

  const product = await Product.findById(productId);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  assertShopAccess(product, req.user);

  const previousStock = product.quantity;
  if (product.quantity < Number(quantity)) {
    throw new ApiError(400, `Insufficient stock. Only ${product.quantity} available.`);
  }
  product.quantity -= Number(quantity);
  await product.save();

  await InventoryLog.create({
    shop: product.shop,
    product: product._id,
    productName: product.name,
    actionType: 'stock_out',
    quantity: Number(quantity),
    previousStock,
    newStock: product.quantity,
    reason: reason || notes || 'Stock Out',
    reference: req.body.reference || '',
    date: date || new Date(),
    performedBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'STOCK_OUT',
    module: 'inventory',
    recordId: product._id,
    recordType: 'Product',
    oldData: { quantity: previousStock },
    newData: { quantity: product.quantity, stockOut: Number(quantity) },
    remarks: `Stock out ${quantity} x "${product.name}"${reason ? ` - ${reason}` : ''}`,
    shopId: product.shop,
  });

  await maybeNotifyLowStock(product, req.user);

  res.status(201).json(ApiResponse.created('Stock removed successfully', { product }));
});

const transferStock = asyncHandler(async (req, res) => {
  const { fromProductId, toProductId, quantity, date, notes } = req.body;
  if (!fromProductId || !toProductId || !quantity || quantity <= 0) {
    throw new ApiError(400, 'Source product, destination product and a positive quantity are required.');
  }
  if (fromProductId === toProductId) {
    throw new ApiError(400, 'Source and destination products must be different.');
  }

  const [fromProduct, toProduct] = await Promise.all([
    Product.findById(fromProductId),
    Product.findById(toProductId),
  ]);
  if (!fromProduct || fromProduct.isDeleted) throw new ApiError(404, 'Source product not found.');
  if (!toProduct || toProduct.isDeleted) throw new ApiError(404, 'Destination product not found.');
  assertShopAccess(fromProduct, req.user);
  assertShopAccess(toProduct, req.user);

  const qty = Number(quantity);
  if (fromProduct.quantity < qty) {
    throw new ApiError(400, `Insufficient stock. Only ${fromProduct.quantity} available in "${fromProduct.name}".`);
  }

  const fromPrevious = fromProduct.quantity;
  const toPrevious = toProduct.quantity;
  fromProduct.quantity -= qty;
  toProduct.quantity += qty;
  await Promise.all([fromProduct.save(), toProduct.save()]);

  await InventoryLog.create([
    {
      shop: fromProduct.shop,
      product: fromProduct._id,
      productName: fromProduct.name,
      actionType: 'stock_out',
      quantity: qty,
      previousStock: fromPrevious,
      newStock: fromProduct.quantity,
      reason: notes || `Transferred to ${toProduct.name}`,
      reference: req.body.reference || '',
      date: date || new Date(),
      performedBy: req.user._id,
    },
    {
      shop: toProduct.shop,
      product: toProduct._id,
      productName: toProduct.name,
      actionType: 'stock_in',
      quantity: qty,
      previousStock: toPrevious,
      newStock: toProduct.quantity,
      supplier: '',
      reason: notes || `Transferred from ${fromProduct.name}`,
      reference: req.body.reference || '',
      date: date || new Date(),
      performedBy: req.user._id,
    },
  ]);

  await recordAudit(req, {
    actionType: 'STOCK_TRANSFER',
    module: 'inventory',
    recordId: fromProduct._id,
    recordType: 'Product',
    oldData: { fromQuantity: fromPrevious, toQuantity: toPrevious },
    newData: { fromQuantity: fromProduct.quantity, toQuantity: toProduct.quantity, transferred: qty },
    remarks: `Transferred ${qty} x "${fromProduct.name}" -> "${toProduct.name}"`,
    shopId: fromProduct.shop,
  });

  await maybeNotifyLowStock(fromProduct, req.user);

  res.status(201).json(
    ApiResponse.created('Stock transferred successfully', { from: fromProduct, to: toProduct })
  );
});

const inventoryHistory = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = {};
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.actionType) filter.actionType = req.query.actionType;
  if (req.query.productId) filter.product = req.query.productId;
  if (req.query.from || req.query.to) {
    filter.date = {};
    if (req.query.from) filter.date.$gte = new Date(req.query.from);
    if (req.query.to) filter.date.$lte = new Date(req.query.to);
  }

  const [logs, total] = await Promise.all([
    InventoryLog.find(filter)
      .populate('performedBy', 'name role')
      .populate('shop', 'name')
      .sort({ date: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    InventoryLog.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Inventory history fetched', { logs, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

module.exports = { stockIn, stockOut, transferStock, inventoryHistory };
