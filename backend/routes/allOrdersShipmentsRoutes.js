const express = require('express');
const router = express.Router();
const { getAllOrdersShipments } = require('../controllers/allOrdersShipmentsController');
const { authenticateToken, authorizeAnyEmployee } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, authorizeAnyEmployee(), getAllOrdersShipments);

module.exports = router;
