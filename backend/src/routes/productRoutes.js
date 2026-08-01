const express = require('express');
const productController = require('../controllers/productController');
const router = express.Router();

router.get('/', productController.listProducts);
router.get('/low-stock', productController.lowStockProducts);
router.get('/:id', productController.getProduct);

router.post('/', productController.createProduct);
router.put('/:id', productController.updateProduct);
router.delete('/:id', productController.deleteProduct);
router.post('/:id/restore', productController.restoreProduct);

module.exports = router;
