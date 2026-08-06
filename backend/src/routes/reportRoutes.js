const express = require('express');
const reportController = require('../controllers/reportController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// Reports contain revenue/profit/financial analytics -> admin only.
router.use(restrictTo('admin'));

router.get('/', reportController.buildReport);
router.get('/sales', reportController.salesReport);
router.get('/expenses', reportController.expenseReport);
router.get('/inventory', reportController.inventoryReport);
router.get('/export', reportController.exportExcel);

module.exports = router;
