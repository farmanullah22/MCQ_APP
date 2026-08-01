const express = require('express');
const auditController = require('../controllers/auditController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// Entire audit module is admin-only. Managers cannot view or modify logs.
router.use(restrictTo('admin'));

router.get('/', auditController.listAuditLogs);
router.get('/stats', auditController.auditStats);
router.get('/action-types', auditController.actionTypes);
router.get('/export', auditController.exportLogs);
router.get('/:id', auditController.getAuditLog);
router.post('/:id/restore', auditController.restoreRecord);

module.exports = router;
