const express = require('express');
const router = express.Router();
const negotiationController = require('../controllers/negotiationController');
const { authenticateToken } = require('../middlewares/authMiddleware');
const { negotiationLimiter } = require('../middlewares/rateLimiters');

router.use(negotiationLimiter);

router.post('/offer', authenticateToken, negotiationController.submitOffer);

// Submit a counter-offer
router.post('/counter-offer', authenticateToken, negotiationController.submitCounterOffer);

// Accept a pending offer
router.post('/accept', authenticateToken, negotiationController.acceptOffer);

// Reject a pending offer (returns entity to Pending Review)
router.post('/reject', authenticateToken, negotiationController.rejectOffer);

// Get full offer timeline for a shipment or order
router.get('/offers', authenticateToken, negotiationController.getOffers);

module.exports = router;
