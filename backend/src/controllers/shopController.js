const Shop = require('../models/Shop');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const listShops = asyncHandler(async (req, res) => {
  if (req.user.role === 'manager') {
    const shop = await Shop.findById(req.user.assignedShop._id).populate('manager', 'name email phone');
    if (!shop || shop.isDeleted) throw new ApiError(404, 'Assigned shop not found.');
    return res.json(ApiResponse.ok('Shop fetched', [shop]));
  }
  const shops = await Shop.find({ isDeleted: false })
    .populate('manager', 'name email phone')
    .sort({ createdAt: 1 });
  res.json(ApiResponse.ok('Shops fetched', shops));
});

const getShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id).populate('manager', 'name email phone');
  if (!shop || shop.isDeleted) throw new ApiError(404, 'Shop not found.');
  if (req.user.role === 'manager' && req.user.assignedShop._id.toString() !== shop._id.toString()) {
    throw new ApiError(403, 'You can only view your assigned shop.');
  }
  res.json(ApiResponse.ok('Shop fetched', shop));
});

const createShop = asyncHandler(async (req, res) => {
  const { name, address, contactNumber, manager } = req.body;
  if (!name) throw new ApiError(400, 'Shop name is required.');

  const shop = await Shop.create({ name, address, contactNumber, manager });

  if (manager) {
    await User.findByIdAndUpdate(manager, { $set: { assignedShop: shop._id } });
  }

  await recordAudit(req, {
    actionType: 'CREATE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    newData: shop.toObject(),
    remarks: `Shop "${shop.name}" created`,
  });

  res.status(201).json(ApiResponse.created('Shop created', shop));
});

const updateShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id);
  if (!shop || shop.isDeleted) throw new ApiError(404, 'Shop not found.');
  const oldData = shop.toObject();

  const { name, address, contactNumber, manager } = req.body;
  if (name !== undefined) shop.name = name;
  if (address !== undefined) shop.address = address;
  if (contactNumber !== undefined) shop.contactNumber = contactNumber;
  if (manager !== undefined) shop.manager = manager;
  await shop.save();

  if (manager !== undefined) {
    const previous = await Shop.findById(req.params.id);
    const prevManager = previous.manager;
    if (prevManager && prevManager.toString() !== manager.toString()) {
      await User.findByIdAndUpdate(prevManager, { $set: { assignedShop: null } });
    }
    await User.findByIdAndUpdate(manager, { $set: { assignedShop: shop._id } });
  }

  await recordAudit(req, {
    actionType: 'UPDATE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData,
    newData: shop.toObject(),
    remarks: `Shop "${shop.name}" updated`,
  });

  res.json(ApiResponse.ok('Shop updated', shop));
});

const deleteShop = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const shop = await Shop.findById(req.params.id);
  if (!shop) throw new ApiError(404, 'Shop not found.');

  const oldData = shop.toObject();
  shop.isDeleted = true;
  shop.deletedBy = req.user._id;
  shop.deletedAt = new Date();
  shop.deleteReason = deleteReason || '';
  await shop.save();

  await recordAudit(req, {
    actionType: 'DELETE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Shop "${shop.name}" soft-deleted`,
  });

  res.json(ApiResponse.ok('Shop deleted'));
});

const restoreShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id);
  if (!shop) throw new ApiError(404, 'Shop not found.');

  shop.isDeleted = false;
  shop.deletedBy = null;
  shop.deletedAt = null;
  shop.deleteReason = '';
  await shop.save();

  await recordAudit(req, {
    actionType: 'RESTORE_PRODUCT',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData: null,
    newData: shop.toObject(),
    status: 'restored',
    remarks: `Shop "${shop.name}" restored`,
  });

  res.json(ApiResponse.ok('Shop restored', shop));
});

module.exports = { listShops, getShop, createShop, updateShop, deleteShop, restoreShop };
