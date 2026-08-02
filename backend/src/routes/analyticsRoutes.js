const express = require('express');
const analyticsController = require('../controllers/analyticsController');
const { scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, analyticsController.getAnalytics);

module.exports = router;
