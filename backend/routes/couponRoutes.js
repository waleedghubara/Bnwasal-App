const express = require('express');
const router = express.Router();
const couponController = require('../controllers/couponController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// Public route to validate coupon (Protected - Authenticated users)
router.get('/validate', authenticateToken, couponController.validateCoupon);

// Admin-only routes
router.post('/admin', authenticateToken, authorizeRoles('admin', 'employee'), couponController.createCoupon);
router.get('/admin', authenticateToken, authorizeRoles('admin', 'employee'), couponController.getCoupons);
router.delete('/admin/:id', authenticateToken, authorizeRoles('admin', 'employee'), couponController.deleteCoupon);
router.put('/admin/:id/status', authenticateToken, authorizeRoles('admin', 'employee'), couponController.toggleCouponStatus);

module.exports = router;
