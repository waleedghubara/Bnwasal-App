const express = require('express');
const router = express.Router();
const adminWalletController = require('../controllers/adminWalletController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// Only allow admin and employee roles to view wallet details
router.get('/transactions', authenticateToken, authorizeRoles('admin', 'employee'), adminWalletController.getTransactions);
router.get('/users', authenticateToken, authorizeRoles('admin', 'employee'), adminWalletController.getWalletUsers);
router.get('/summary', authenticateToken, authorizeRoles('admin', 'employee'), adminWalletController.getWalletSummary);

module.exports = router;
