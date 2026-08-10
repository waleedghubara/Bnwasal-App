const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

router.post('/pay-delivery', authenticateToken, authorizeRoles('merchant'), paymentController.payDeliveryFee);

module.exports = router;
