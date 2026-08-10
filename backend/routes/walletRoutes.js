const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');
const { authenticateToken } = require('../middlewares/authMiddleware');
const { walletLimiter } = require('../middlewares/rateLimiters');

// ─── Authenticated Routes ─────────────────────────────────────────────────────

// Get wallet balance + recent transactions
router.get('/data', authenticateToken, walletController.getWalletData);

// Get all transactions (paginated)
router.get('/transactions', authenticateToken, walletController.getTransactions);

// Create a Kashier deposit session → returns sessionUrl for WebView
router.post(
  '/create-deposit-session',
  authenticateToken,
  walletLimiter,
  walletController.createDepositSession
);

router.post(
  '/check-session',
  authenticateToken,
  walletLimiter,
  walletController.checkDepositSession
);

// Withdraw money from wallet → places request pending admin approval
router.post('/withdraw', authenticateToken, walletController.withdraw);

// ─── Public Routes (called by Kashier servers) ────────────────────────────────

// Kashier webhook — server-to-server notification of payment result
router.post('/kashier-webhook', walletController.kashierWebhook);

// Redirect page shown after payment completes inside WebView
router.get('/payment-callback', walletController.paymentCallback);

module.exports = router;
