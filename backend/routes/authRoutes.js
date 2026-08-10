const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken, authenticateTokenAllowPending, authorizeRoles } = require('../middlewares/authMiddleware');
const { requireResetToken } = require('../middlewares/requireResetToken');
const {
  ipLoginLimiter,
  userLoginLimiter,
  ipRegisterLimiter,
  userRegisterLimiter,
  ipOtpLimiter,
  userOtpLimiter,
  ipResetPasswordLimiter,
  userResetPasswordLimiter,
  authLimiter
} = require('../middlewares/rateLimiters');
const upload = require('../middlewares/uploadMiddleware');

// 1. Register Route (Optional avatar profileImage)
router.post('/register', ipRegisterLimiter, userRegisterLimiter, upload.single('profileImage'), authController.register);

// 2. Verify OTP Route
router.post('/verify-otp', ipOtpLimiter, userOtpLimiter, authController.verifyOtp);

// 3. Resend OTP Route
router.post('/resend-otp', ipOtpLimiter, userOtpLimiter, authController.resendOtp);

// 4. Login Route
router.post('/login', ipLoginLimiter, userLoginLimiter, authController.login);

// 5. Refresh Token Route
router.post('/refresh-token', authLimiter, authController.refreshToken);

// 6. Logout Route (Protected)
router.post('/logout', authenticateTokenAllowPending, authController.logout);

// 7. Get Profile Route (Protected)
router.get('/profile', authenticateTokenAllowPending, authController.getProfile);

// 12. Update Profile Route (Protected, optional avatar)
router.put('/profile', authenticateTokenAllowPending, upload.single('profileImage'), authController.updateProfile);

// 13. Change Password Route (Protected)
router.put('/change-password', authenticateTokenAllowPending, authController.changePassword);

// 8. Upload Documents Route (Protected, allowed for both merchant and captain roles)
router.post(
  '/driver/upload-documents',
  authenticateTokenAllowPending,
  authorizeRoles('captain', 'merchant'),
  upload.fields([
    { name: 'nationalIdFront', maxCount: 1 },
    { name: 'nationalIdBack', maxCount: 1 }
  ]),
  authController.uploadDriverDocuments
);

// 9. Forgot Password Route
router.post('/forgot-password', ipResetPasswordLimiter, userResetPasswordLimiter, authController.forgotPassword);

// 10. Verify Reset OTP Route
router.post('/verify-reset-otp', ipResetPasswordLimiter, userResetPasswordLimiter, authController.verifyResetOtp);

// 11. Reset Password Route (dedicated reset token only)
router.post('/reset-password', ipResetPasswordLimiter, userResetPasswordLimiter, requireResetToken, authController.resetPassword);

// 14. Update FCM Token Route (Protected)
router.put('/fcm-token', authenticateTokenAllowPending, authController.updateFcmToken);

// 15. Web Push Subscription Route (Protected)
router.post('/web-push-subscribe', authenticateTokenAllowPending, authController.subscribeWebPush);

// 16. Get VAPID Public Key Route (Public)
router.get('/vapid-public-key', (req, res) => {
  res.json({ status: 1, publicKey: process.env.VAPID_PUBLIC_KEY });
});

// 17. Admin Login Route
router.post('/admin-login', ipLoginLimiter, userLoginLimiter, authController.adminLogin);

module.exports = router;
