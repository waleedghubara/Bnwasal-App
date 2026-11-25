const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');
const { authenticateToken } = require('../middlewares/authMiddleware');
const { walletLimiter } = require('../middlewares/rateLimiters');
const upload = require('../middlewares/uploadMiddleware');

// ─── Authenticated Routes ─────────────────────────────────────────────────────

// Get wallet balance + recent transactions
router.get('/data', authenticateToken, walletController.getWalletData);

// Get all transactions (paginated & filterable for captain: earnings, commission, settlements)
router.get('/transactions', authenticateToken, walletController.getTransactions);

// Get captain account statement (daily, weekly, monthly)
router.get('/statement', authenticateToken, walletController.getAccountStatement);

// Export captain account statement (excel / pdf)
router.get('/statement/export', authenticateToken, walletController.exportAccountStatement);

// Get captain dues and settlements summary
router.get('/dues', authenticateToken, walletController.getCaptainDues);

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

// Direct deposit via InstaPay / Mobile Wallets with receipt upload
router.post(
  '/direct-deposit',
  authenticateToken,
  upload.single('receiptImage'),
  walletController.submitDirectDeposit
);

// Withdraw money from wallet → places request pending admin approval
router.post('/withdraw', authenticateToken, walletController.withdraw);

// ─── Public Routes (called by Kashier servers) ────────────────────────────────

// Kashier webhook — server-to-server notification of payment result
router.post('/kashier-webhook', walletController.kashierWebhook);

// Redirect page shown after payment completes inside WebView
router.get('/payment-callback', walletController.paymentCallback);

module.exports = router;
