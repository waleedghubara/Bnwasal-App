const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const directPaymentController = require('../controllers/directPaymentController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// ─── Multer config for receipt images ─────────────────────────────────────────
const receiptsDir = path.join(__dirname, '..', 'uploads', 'receipts');
if (!fs.existsSync(receiptsDir)) {
  fs.mkdirSync(receiptsDir, { recursive: true });
}

const receiptStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, receiptsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `receipt_${Date.now()}_${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});

const uploadReceipt = multer({
  storage: receiptStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('يُسمح فقط بصور jpg, jpeg, png, webp'));
    }
  },
});

// ─── Multer config for payment method icons ────────────────────────────────────
const paymentIconsDir = path.join(__dirname, '..', 'uploads', 'payment-icons');
if (!fs.existsSync(paymentIconsDir)) {
  fs.mkdirSync(paymentIconsDir, { recursive: true });
}

const iconStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, paymentIconsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `icon_${Date.now()}_${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});

const uploadIcon = multer({
  storage: iconStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.webp', '.svg'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('يُسمح فقط بصور jpg, jpeg, png, webp, svg'));
    }
  },
});

// ─── Public/Merchant routes ────────────────────────────────────────────────────
// Get available payment methods (no auth required)
router.get('/methods', directPaymentController.getPaymentMethods);

// Submit a payment receipt (merchant only)
router.post(
  '/submit',
  authenticateToken,
  authorizeRoles('merchant'),
  uploadReceipt.single('receiptImage'),
  directPaymentController.submitDirectPayment
);

// Check payment status by ref (merchant only)
router.get(
  '/status/:paymentRef',
  authenticateToken,
  authorizeRoles('merchant'),
  directPaymentController.checkPaymentStatus
);

// ─── Admin routes ──────────────────────────────────────────────────────────────
// List all direct payments
router.get(
  '/list',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  directPaymentController.listDirectPayments
);

// Approve or reject a payment
router.put(
  '/:id/review',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  directPaymentController.reviewDirectPayment
);

// Update payment methods config
router.put(
  '/methods',
  authenticateToken,
  authorizeRoles('admin'),
  directPaymentController.updatePaymentMethods
);

// Upload a payment method icon image (admin only)
router.post(
  '/methods/icon',
  authenticateToken,
  authorizeRoles('admin'),
  uploadIcon.single('iconImage'),
  directPaymentController.uploadMethodIcon
);

module.exports = router;
