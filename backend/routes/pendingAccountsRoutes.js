const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticateToken, authorizeRoles, authorizeByPermission } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, authorizeByPermission('pendingAccounts'), adminController.getPendingAccounts);
router.get('/:id', authenticateToken, authorizeByPermission('pendingAccounts'), adminController.getPendingAccountDetail);
router.patch('/:id/approve', authenticateToken, authorizeRoles('admin'), adminController.approvePendingAccount);
router.patch('/:id/reject', authenticateToken, authorizeRoles('admin'), adminController.rejectPendingAccount);

module.exports = router;
