const crypto = require('crypto');
const { isProduction } = require('../utils/securityConfig');

const API_CRYPTO_STATIC_KEY = process.env.API_CRYPTO_STATIC_KEY || 'fallback_api_crypto_static_key_we_deliver_2026';

const verifyRequestSignature = (req, res, next) => {
  // Bypass validation for landing page requests that use API keys
  if (req.headers['x-api-key']) {
    return next();
  }

  // Bypass validation for non-API requests (like invite links or HTML/CSS assets)
  if (!req.originalUrl.startsWith('/api/')) {
    return next();
  }

  // Bypass validation for dev/public landing endpoints
  if (req.path === '/' || req.path.startsWith('/api/public') || req.path === '/api/auth/vapid-public-key') {
    return next();
  }

  const signature = req.headers['x-signature'];
  const timestampHeader = req.headers['x-timestamp'];
  const deviceId = req.headers['x-device-id'];

  if (!signature || !timestampHeader || !deviceId) {
    return res.status(400).json({
      status: 0,
      message: 'Secure request validation failed. Missing required security headers.',
      errorCode: 'SECURE_HEADERS_MISSING'
    });
  }

  // Enforce freshness (5 minutes expiration window, unless bypassed)
  const timestamp = parseInt(timestampHeader, 10);
  const now = Date.now();
  const bypassTimestamp = process.env.BYPASS_TIMESTAMP_CHECK === 'true';
  if (!bypassTimestamp && (isNaN(timestamp) || Math.abs(now - timestamp) > 5 * 60 * 1000)) {
    return res.status(400).json({
      status: 0,
      message: 'Secure request validation failed. Request timestamp has expired or is invalid.',
      errorCode: 'SECURE_TIMESTAMP_EXPIRED'
    });
  }

  // Allow bypassing signature check in dev/test environments
  const bypassSignature = process.env.BYPASS_SIGNATURE_CHECK === 'true';
  if (bypassSignature) {
    return next();
  }

  // Recompute signature: HMAC-SHA256(timestamp + deviceId, secretKey)
  const dataToSign = timestampHeader + deviceId;
  const computedSignature = crypto
    .createHmac('sha256', API_CRYPTO_STATIC_KEY)
    .update(dataToSign)
    .digest('hex');

  // Constant-time comparison to prevent timing attacks
  try {
    // Normalize: the client may send hex or lowercase hex — normalize both sides
    const clientSig = signature.toLowerCase().trim();
    const serverSig = computedSignature.toLowerCase().trim();

    // Validate that client signature looks like a valid hex string
    if (!/^[0-9a-f]+$/.test(clientSig)) {
      return res.status(401).json({
        status: 0,
        message: 'Secure request validation failed. Invalid signature format.',
        errorCode: 'SECURE_SIGNATURE_INVALID'
      });
    }

    const sigBuffer = Buffer.from(clientSig, 'hex');
    const compBuffer = Buffer.from(serverSig, 'hex');
    if (sigBuffer.length !== compBuffer.length || !crypto.timingSafeEqual(sigBuffer, compBuffer)) {
      return res.status(401).json({
        status: 0,
        message: 'Secure request validation failed. Invalid signature.',
        errorCode: 'SECURE_SIGNATURE_INVALID'
      });
    }
  } catch (err) {
    return res.status(401).json({
      status: 0,
      message: 'Secure request validation failed. Signature decoding error.',
      errorCode: 'SECURE_SIGNATURE_INVALID'
    });
  }

  next();
};

module.exports = { verifyRequestSignature };
