const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// 1. Create Order (Protected - Merchant only)
router.post(
  '/',
  authenticateToken,
  authorizeRoles('merchant'),
  orderController.createOrder
);

// 2. Get All Orders (Protected)
router.get(
  '/',
  authenticateToken,
  orderController.getOrders
);

// Update Order
router.put(
  '/:id',
  authenticateToken,
  authorizeRoles('merchant'),
  orderController.updateOrder
);

// Delete Order
router.delete(
  '/:id',
  authenticateToken,
  authorizeRoles('merchant'),
  orderController.deleteOrder
);

// 3. Get Order Details (Protected)
router.get(
  '/:id',
  authenticateToken,
  orderController.getOrderById
);

// 3.1 Get Order Status History Logs
router.get(
  '/:id/logs',
  authenticateToken,
  orderController.getOrderLogs
);

// 4. Update Order Status (Protected)
router.put(
  '/:id/status',
  authenticateToken,
  orderController.updateOrderStatus
);

// 4.1 Confirm Pickup (Protected - Merchant only)
router.post(
  '/:id/confirm-pickup',
  authenticateToken,
  authorizeRoles('merchant'),
  orderController.confirmPickup
);

// 4.2 Confirm Delivery (Protected - Merchant / Admin)
router.post(
  '/:id/confirm-delivery',
  authenticateToken,
  orderController.confirmDelivery
);

// 4.3 Captain Response to Assignment (Protected - Captain only)
router.put(
  '/:id/captain-response',
  authenticateToken,
  authorizeRoles('captain'),
  orderController.handleCaptainResponse
);

// 5. Compute Pricing (Protected - Admin/Employee only)
router.post(
  '/:id/compute-pricing',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  orderController.computePricing
);

// 6. Claim Order (Protected - Admin/Employee only)
router.post(
  '/:id/claim',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  orderController.claimOrder
);

module.exports = router;

