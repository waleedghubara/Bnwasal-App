const express = require('express');
const router = express.Router();
const { getReferralSummary, convertPoints } = require('../controllers/referralController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Get referral summary, statistics, and list of invited friends
router.get('/summary', authenticateToken, getReferralSummary);

// Convert accumulated referral points to wallet balance
router.post('/convert-points', authenticateToken, convertPoints);

module.exports = router;
