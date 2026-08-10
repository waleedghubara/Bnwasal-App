const express = require('express');
const router = express.Router();
const supportController = require('../controllers/supportController');
const { authenticateToken } = require('../middlewares/authMiddleware');
const { verifyAccessToken } = require('../utils/tokenHelper');
const upload = require('../middlewares/uploadMiddleware');
const { contactLimiter } = require('../middlewares/rateLimiters');
const { isProduction } = require('../utils/securityConfig');

// Optional authentication middleware for guest messages
const parseTokenOptional = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (token) {
    const decoded = verifyAccessToken(token);
    if (decoded) {
      req.user = decoded;
    }
  }
  next();
};

// 1. Submit contact us form (public/optional auth)
router.post('/contact', contactLimiter, parseTokenOptional, supportController.submitContactMessage);

// 1b. Get and delete contact us forms (admin/employee dashboard)
router.get('/contacts', authenticateToken, supportController.getContactMessages);
router.delete('/contacts/:id', authenticateToken, supportController.deleteContactMessage);

// 2. Get support messages
router.get('/chat', authenticateToken, supportController.getSupportMessages);

// 3. Send support message (supports image uploads)
router.post('/chat', authenticateToken, upload.single('image'), supportController.sendSupportMessage);

// 4. Get active support threads list (for admin)
router.get('/threads', authenticateToken, supportController.getSupportThreads);

// 5. Create active support test admin user
router.post('/create-test-admin', upload.single('image'), supportController.createTestAdmin);

// 6. Serve the support admin HTML dashboard
// 6. Lookup user/order/shipment by email, phone, order number, or shipment number
router.get('/lookup', authenticateToken, supportController.lookupEntity);

// 7. Serve the support admin HTML dashboard
const path = require('path');
router.get('/dashboard', (req, res) => {
  if (isProduction()) {
    return res.status(404).json({ status: 0, message: 'Not found' });
  }
  res.sendFile(path.join(__dirname, '../public/support-admin.html'));
});

module.exports = router;

