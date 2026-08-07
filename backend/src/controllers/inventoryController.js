const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const Notification = require('../models/Notification');
const Shop = require('../models/Shop');
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
  const { fromShopId, toShopId, productId, quantity, date, notes } = req.body;
  if (!fromShopId || !toShopId || !productId || !quantity || quantity <= 0) {
    throw new ApiError(400, 'Source shop, destination shop, product and a positive quantity are required.');
  }
  if (fromShopId === toShopId) {
    throw new ApiError(400, 'Source and destination shops must be different.');
  }

  const [fromShop, toShop] = await Promise.all([
    Shop.findById(fromShopId),
    Shop.findById(toShopId),
  ]);
  if (!fromShop || fromShop.isDeleted) throw new ApiError(404, 'Source shop not found.');
  if (!toShop || toShop.isDeleted) throw new ApiError(404, 'Destination shop not found.');

  // Managers may only transfer when their assigned shop is one of the two
  // endpoints (push stock out of their branch or pull stock into it).
  if (req.user.role === 'manager') {
    const mine = req.user.assignedShop._id.toString();
    const from = fromShop._id.toString();
    const to = toShop._id.toString();
    if (from !== mine && to !== mine) {
      throw new ApiError(403, 'Transfers must involve your assigned shop.');
    }
  }

  const fromProduct = await Product.findOne({ _id: productId, shop: fromShopId, isDeleted: false });
  if (!fromProduct) throw new ApiError(404, 'Source product not found in the selected shop.');

  // Resolve the matching product in the destination shop (by name). If it does
  // not exist yet, create it so stock moves against the same logical product.
  let toProduct = await Product.findOne({
    shop: toShopId,
    name: fromProduct.name,
    isDeleted: false,
  });
  let destinationCreated = false;
  if (!toProduct) {
    const short = toShop.name.replace(/\s+/g, '').slice(0, 12);
    toProduct = await Product.create({
      name: fromProduct.name,
      sku: fromProduct.sku ? `${short}-${fromProduct.sku}` : '',
      barcode: fromProduct.barcode,
      category: fromProduct.category,
      brand: fromProduct.brand,
      supplier: fromProduct.supplier,
      costPrice: fromProduct.costPrice,
      sellingPrice: fromProduct.sellingPrice,
      quantity: 0,
      lowStockThreshold: fromProduct.lowStockThreshold,
      description: fromProduct.description,
      images: fromProduct.images,
      shop: toShopId,
    });
    destinationCreated = true;
  }

  const qty = Number(quantity);
  if (fromProduct.quantity < qty) {
    throw new ApiError(400, `Insufficient stock. Only ${fromProduct.quantity} available in "${fromProduct.name}" at ${fromShop.name}.`);
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
      reason: notes || `Transferred to ${toShop.name}`,
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
      reason: notes || `Transferred from ${fromShop.name}`,
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
    remarks: `Transferred ${qty} x "${fromProduct.name}" from ${fromShop.name} to ${toShop.name}`,
    shopId: fromProduct.shop,
  });

  await maybeNotifyLowStock(fromProduct, req.user);

  res.status(201).json(
    ApiResponse.created('Stock transferred successfully', {
      from: fromProduct,
      to: toProduct,
      fromShop: { id: fromShop._id, name: fromShop.name },
      toShop: { id: toShop._id, name: toShop.name },
      destinationCreated,
    })
  );
});

// Active shops a transfer can involve. Managers need the full list because a
// transfer may either start or end at any location (branch <-> warehouse).
const transferShops = asyncHandler(async (req, res) => {
  const shops = await Shop.find({ isDeleted: false }).sort({ createdAt: 1 });
  res.json(
    ApiResponse.ok(
      'Transfer shops fetched',
      shops.map((s) => ({ id: s._id, name: s.name, address: s.address || '' }))
    )
  );
});

// Products of a given shop, used to build the source-product dropdown of the
// transfer form when transferring from another location.
const shopProducts = asyncHandler(async (req, res) => {
  const shopId = req.params.shopId;
  if (!require('mongoose').Types.ObjectId.isValid(shopId)) {
    throw new ApiError(400, 'Invalid shop id.');
  }
  const products = await Product.find({ shop: shopId, isDeleted: false })
    .populate('category', 'name')
    .sort({ createdAt: 1 })
    .select('name sku quantity sellingPrice costPrice category lowStockThreshold');
  res.json(ApiResponse.ok('Shop products fetched', products));
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

module.exports = { stockIn, stockOut, transferStock, transferShops, shopProducts, inventoryHistory };
