const express = require('express');
const router = express.Router();
const adminWithdrawalController = require('../controllers/adminWithdrawalController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// Only allow admin and employee roles to manage withdrawals
router.get('/', authenticateToken, authorizeRoles('admin', 'employee'), adminWithdrawalController.getWithdrawals);
router.post('/:id/approve', authenticateToken, authorizeRoles('admin', 'employee'), adminWithdrawalController.approveWithdrawal);
router.post('/:id/reject', authenticateToken, authorizeRoles('admin', 'employee'), adminWithdrawalController.rejectWithdrawal);

module.exports = router;
