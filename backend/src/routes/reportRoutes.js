const express = require('express');
const reportController = require('../controllers/reportController');
const router = express.Router();

router.get('/', reportController.buildReport);
router.get('/sales', reportController.salesReport);
router.get('/expenses', reportController.expenseReport);
router.get('/inventory', reportController.inventoryReport);
router.get('/export', reportController.exportExcel);

module.exports = router;
