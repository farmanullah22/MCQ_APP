const Product = require('../models/Product');
const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const buildProductQuery = (req) => {
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') {
    filter.shop = req.user.assignedShop._id;
  } else if (req.shopId) {
    filter.shop = req.shopId;
  }

  const { search, category, brand, supplier, lowStock } = req.query;
  if (search) {
    filter.$or = [
      { name: { $regex: search, $options: 'i' } },
      { sku: { $regex: search, $options: 'i' } },
      { barcode: { $regex: search, $options: 'i' } },
    ];
  }
  if (category) filter.category = category;
  if (brand) filter.brand = { $regex: brand, $options: 'i' };
  if (supplier) filter.supplier = { $regex: supplier, $options: 'i' };
  if (lowStock === 'true') {
    filter.$expr = { $lte: ['$quantity', '$lowStockThreshold'] };
  }
  return filter;
};

const listProducts = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 50;
  const filter = buildProductQuery(req);

  const [products, total] = await Promise.all([
    Product.find(filter)
      .populate('category', 'name')
      .populate('shop', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Product.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Products fetched', { products, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id)
    .populate('category', 'name')
    .populate('shop', 'name');
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop._id.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }
  res.json(ApiResponse.ok('Product fetched', product));
});

const createProduct = asyncHandler(async (req, res) => {
  const {
    name,
    sku,
    barcode,
    category,
    brand,
    supplier,
    costPrice,
    sellingPrice,
    quantity,
    lowStockThreshold,
    description,
    images,
  } = req.body;

  if (!name) throw new ApiError(400, 'Product name is required.');
  if (costPrice === undefined || sellingPrice === undefined) {
    throw new ApiError(400, 'Cost price and selling price are required.');
  }

  const shopId =
    req.user.role === 'manager'
      ? req.user.assignedShop._id
      : req.body.shopId || req.shopId || (await require('../models/Shop').findOne({ isDeleted: false }))._id;
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const product = await Product.create({
    name,
    sku: sku || '',
    barcode: barcode || '',
    category: category || null,
    brand: brand || '',
    supplier: supplier || '',
    costPrice,
    sellingPrice,
    quantity: quantity || 0,
    lowStockThreshold: lowStockThreshold !== undefined ? lowStockThreshold : 5,
    description: description || '',
    images: images || [],
    shop: shopId,
  });

  await recordAudit(req, {
    actionType: 'CREATE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    newData: product.toObject(),
    remarks: `Product "${product.name}" created`,
    shopId,
  });

  res.status(201).json(ApiResponse.created('Product created', product));
});

const updateProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }
  const oldData = product.toObject();

  const allowed = [
    'name',
    'sku',
    'barcode',
    'category',
    'brand',
    'supplier',
    'costPrice',
    'sellingPrice',
    'lowStockThreshold',
    'description',
    'images',
  ];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) product[field] = req.body[field];
  });
  await product.save();
  await product.populate('category', 'name').populate('shop', 'name');

  await recordAudit(req, {
    actionType: 'UPDATE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData,
    newData: product.toObject(),
    remarks: `Product "${product.name}" updated`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product updated', product));
});

const deleteProduct = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const product = await Product.findById(req.params.id).populate('category', 'name');
  if (!product) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }

  const oldData = product.toObject();
  product.isDeleted = true;
  product.deletedBy = req.user._id;
  product.deletedAt = new Date();
  product.deleteReason = deleteReason || '';
  await product.save();

  await recordAudit(req, {
    actionType: 'DELETE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Product "${product.name}" soft-deleted${deleteReason ? ` - ${deleteReason}` : ''}`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product deleted'));
});

const restoreProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (!product) throw new ApiError(404, 'Product not found.');

  product.isDeleted = false;
  product.deletedBy = null;
  product.deletedAt = null;
  product.deleteReason = '';
  await product.save();

  await recordAudit(req, {
    actionType: 'RESTORE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData: null,
    newData: product.toObject(),
    status: 'restored',
    remarks: `Product "${product.name}" restored`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product restored', product));
});

const lowStockProducts = asyncHandler(async (req, res) => {
  const filter = { isDeleted: false, $expr: { $lte: ['$quantity', '$lowStockThreshold'] } };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;

  const products = await Product.find(filter).populate('category', 'name').populate('shop', 'name').sort({ quantity: 1 });
  res.json(ApiResponse.ok('Low stock products fetched', products));
});

module.exports = { listProducts, getProduct, createProduct, updateProduct, deleteProduct, restoreProduct, lowStockProducts };
