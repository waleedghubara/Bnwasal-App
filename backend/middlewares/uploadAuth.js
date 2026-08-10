const path = require('path');
const { verifyAccessToken } = require('../utils/tokenHelper');
const { isProduction } = require('../utils/securityConfig');

const SENSITIVE_PATTERN = /nationalid|national_id|driver|document|idfront|idback/i;

/**
 * Protects uploads. Production requires Bearer token for all files (UPLOADS_REQUIRE_AUTH=1).
 */
function uploadsAuthMiddleware(req, res, next) {
  if (req.method !== 'GET') {
    return res.status(405).json({ status: 0, message: 'Method not allowed' });
  }

  const basename = path.basename(req.path);
  // Only require authentication for sensitive documents (like national IDs, driver licenses, etc.)
  const requiresAuth = SENSITIVE_PATTERN.test(basename);

  if (!requiresAuth) {
    return next();
  }

  const header = req.headers.authorization;
  const queryToken = isProduction() ? null : req.query.access_token;
  const token =
    (header && header.startsWith('Bearer ') ? header.slice(7) : null) || queryToken;

  if (!token || !verifyAccessToken(token)) {
    return res.status(401).json({ status: 0, message: 'Unauthorized' });
  }

  next();
}

module.exports = { uploadsAuthMiddleware };
