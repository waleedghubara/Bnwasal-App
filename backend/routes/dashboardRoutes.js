const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticateToken, authorizeAnyEmployee } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, authorizeAnyEmployee(), dashboardController.getDashboard);

module.exports = router;
