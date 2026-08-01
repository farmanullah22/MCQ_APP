const express = require('express');
const saleController = require('../controllers/saleController');
const router = express.Router();

router.get('/', saleController.listSales);
router.get('/:id', saleController.getSale);

router.post('/', saleController.createSale);
router.put('/:id', saleController.updateSale);
router.delete('/:id', saleController.deleteSale);
router.post('/:id/restore', saleController.restoreSale);

module.exports = router;
