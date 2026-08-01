const express = require('express');
const authController = require('../controllers/authController');
const { protect, restrictTo } = require('../middleware/auth');
const router = express.Router();

router.post('/login', authController.login);

router.post('/logout', protect, authController.logout);
router.get('/profile', protect, authController.getProfile);
router.put('/profile', protect, authController.updateProfile);
router.put('/change-password', protect, authController.changePassword);

router.post('/managers', protect, restrictTo('admin'), authController.registerManager);
router.get('/managers', protect, restrictTo('admin'), authController.listManagers);
router.put('/managers/:id', protect, restrictTo('admin'), authController.updateManager);

module.exports = router;
