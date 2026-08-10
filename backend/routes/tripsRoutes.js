const express = require('express');
const router = express.Router();
const tripsController = require('../controllers/tripsController');
const { authenticateToken, authorizeRoles, authorizeByPermission } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, authorizeByPermission('trips', 'todayTrips'), tripsController.getAllTrips);
router.get('/today', authenticateToken, authorizeByPermission('todayTrips', 'trips'), tripsController.getTodayTrips);
router.get('/date/:date', authenticateToken, authorizeByPermission('trips', 'todayTrips'), tripsController.getTripsByDate);
router.get('/captain/:captainId', authenticateToken, authorizeByPermission('trips', 'todayTrips'), tripsController.getTripsByCaptain);
router.post('/', authenticateToken, authorizeRoles('admin'), tripsController.createTrip);

module.exports = router;
