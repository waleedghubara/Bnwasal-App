const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// All notification routes are protected
router.get('/', authenticateToken, notificationController.getNotifications);
router.put('/read-all', authenticateToken, notificationController.markAllRead);
router.put('/:id/read', authenticateToken, notificationController.markRead);
router.delete('/clear-all', authenticateToken, notificationController.clearAllNotifications);
router.delete('/:id', authenticateToken, notificationController.deleteNotification);
router.post('/test-send', authenticateToken, authorizeRoles('admin'), notificationController.testSend);
router.get('/target-users', authenticateToken, authorizeRoles('admin'), notificationController.getTargetUsers);
router.post('/send', authenticateToken, authorizeRoles('admin'), notificationController.sendBulkNotification);

module.exports = router;
