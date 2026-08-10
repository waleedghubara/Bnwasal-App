const express = require('express');
const router = express.Router();
const dispatcherController = require('../controllers/dispatcherController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

router.get('/available-captains', authenticateToken, authorizeRoles('admin', 'employee'), dispatcherController.getAvailableCaptains);
router.post('/assign', authenticateToken, authorizeRoles('admin', 'employee'), dispatcherController.assignCaptain);

module.exports = router;
