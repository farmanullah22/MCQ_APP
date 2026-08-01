const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const router = express.Router();

router.post('/in', inventoryController.stockIn);
router.post('/out', inventoryController.stockOut);
router.get('/history', inventoryController.inventoryHistory);

module.exports = router;
