const express = require('express');
const router = express.Router();
const reviewController = require('../controllers/reviewController');
const { authenticateToken } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, reviewController.getMyReviews);
router.get('/given', authenticateToken, reviewController.getGivenReviews);
router.get('/status/:shipmentId', authenticateToken, reviewController.checkReviewStatus);
router.get('/user/:userId', authenticateToken, reviewController.getUserRating);
router.post('/', authenticateToken, reviewController.createReview);

module.exports = router;
