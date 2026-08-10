const express = require('express');
const router = express.Router();
const { getPublicStats } = require('../controllers/publicStatsController');
const { validateApiKey } = require('../middlewares/validateApiKey');

// GET /api/public/stats  —  landing page statistics (protected by API key)
router.get('/stats', validateApiKey, getPublicStats);

module.exports = router;
