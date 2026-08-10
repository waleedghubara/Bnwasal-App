const express = require('express');
const router = express.Router();
const shipmentController = require('../controllers/shipmentController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');

// 1. Create Shipment (Protected - Merchant only, upload up to 10 images)
router.post(
  '/',
  authenticateToken,
  authorizeRoles('merchant'),
  upload.array('images', 10),
  shipmentController.createShipment
);

// 2. Get All Shipments (Protected - Merchant / Captain / Admin)
router.get(
  '/',
  authenticateToken,
  shipmentController.getShipments
);

// Update Shipment
router.put(
  '/:id',
  authenticateToken,
  authorizeRoles('merchant'),
  upload.array('images', 10),
  shipmentController.updateShipment
);

// Delete Shipment
router.delete(
  '/:id',
  authenticateToken,
  authorizeRoles('merchant'),
  shipmentController.deleteShipment
);

// 3. Get Shipment Details (Protected)
const messageController = require('../controllers/messageController');

// 3. Get Shipment Details (Protected)
router.get(
  '/:id',
  authenticateToken,
  shipmentController.getShipmentById
);

// 3.1 Get Shipment Status History Logs
router.get(
  '/:id/logs',
  authenticateToken,
  shipmentController.getShipmentLogs
);

// 4. Update Shipment Status (Protected)
router.put(
  '/:id/status',
  authenticateToken,
  shipmentController.updateShipmentStatus
);

// 4.1 Confirm Pickup (Protected - Merchant only)
router.post(
  '/:id/confirm-pickup',
  authenticateToken,
  authorizeRoles('merchant'),
  shipmentController.confirmPickup
);

// 4.2 Confirm Delivery (Protected - Merchant / Admin)
router.post(
  '/:id/confirm-delivery',
  authenticateToken,
  shipmentController.confirmDelivery
);

// 4.3 Captain Response to Assignment (Protected - Captain only)
router.put(
  '/:id/captain-response',
  authenticateToken,
  authorizeRoles('captain'),
  shipmentController.handleCaptainResponse
);


// 5. Send Message (Protected)
router.post(
  '/:shipmentId/messages',
  authenticateToken,
  messageController.sendMessage
);

// 6. Get Messages (Protected)
router.get(
  '/:shipmentId/messages',
  authenticateToken,
  messageController.getMessages
);

// 7. Compute Pricing (Protected - Admin/Employee only)
router.post(
  '/:id/compute-pricing',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  shipmentController.computePricing
);

// 8. Claim Shipment (Protected - Admin/Employee only)
router.post(
  '/:id/claim',
  authenticateToken,
  authorizeRoles('admin', 'employee'),
  shipmentController.claimShipment
);

module.exports = router;
