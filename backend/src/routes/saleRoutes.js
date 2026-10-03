const express = require('express');
const saleController = require('../controllers/saleController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, saleController.listSales);
router.get('/:id', saleController.getSale);

// Admin is view-only. Sale mutations are manager (operational) actions.
router.post('/', restrictTo('manager'), saleController.createSale);
router.put('/:id', restrictTo('manager'), saleController.updateSale);
router.delete('/:id', restrictTo('manager'), saleController.deleteSale);
router.post('/:id/restore', restrictTo('manager'), saleController.restoreSale);

// Invoice adjustments. All of these move stock and money, so they stay
// manager-only and are audited individually.
router.post('/:id/items', restrictTo('manager'), saleController.addSaleItems);
router.post('/:id/return', restrictTo('manager'), saleController.returnSaleItems);
router.post('/:id/exchange', restrictTo('manager'), saleController.exchangeSaleItems);
router.post('/:id/payment', restrictTo('manager'), saleController.recordSalePayment);

module.exports = router;
