/**
 * Middleware to validate API key for public endpoints.
 *
 * The client must send the API key in the `X-API-Key` header.
 * Keys are stored in config/api-keys.js.
 */
const apiKeys = require('../config/api-keys');
const { isProduction } = require('../utils/securityConfig');

const validateApiKey = (req, res, next) => {
  const providedKey = req.headers['x-api-key'];

  if (!providedKey) {
    return res.status(401).json({
      status: 0,
      message: 'API key is required. Send it in the X-API-Key header.',
    });
  }

  const validKeys = Object.values(apiKeys)
    .map((v) => (typeof v === 'string' ? v : v?.public || v?.secret))
    .filter(Boolean);

  if (validKeys.length === 0) {
    if (isProduction()) {
      return res.status(503).json({ status: 0, message: 'Public API is not configured' });
    }
    return res.status(401).json({ status: 0, message: 'Invalid API key.' });
  }

  if (!validKeys.includes(providedKey)) {
    return res.status(403).json({
      status: 0,
      message: 'Invalid API key.',
    });
  }

  next();
};

module.exports = { validateApiKey };
