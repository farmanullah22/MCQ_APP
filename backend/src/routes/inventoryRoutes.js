const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// Admin is view-only. Stock in/out are manager (operational) actions.
router.post('/in', restrictTo('manager'), inventoryController.stockIn);
router.post('/out', restrictTo('manager'), inventoryController.stockOut);
router.get('/history', inventoryController.inventoryHistory);

module.exports = router;
