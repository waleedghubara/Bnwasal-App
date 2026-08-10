const express = require('express');
const router = express.Router();
const tripController = require('../controllers/tripController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// All trip routes are protected and restricted to drivers (captains)
router.get('/', authenticateToken, authorizeRoles('captain'), tripController.getTrips);
router.post('/', authenticateToken, authorizeRoles('captain'), tripController.createTrip);
router.put('/:id', authenticateToken, authorizeRoles('captain'), tripController.updateTrip);
router.delete('/:id', authenticateToken, authorizeRoles('captain'), tripController.deleteTrip);

module.exports = router;
