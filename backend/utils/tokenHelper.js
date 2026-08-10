const jwt = require('jsonwebtoken');
const { isProduction } = require('./securityConfig');

const { assertSecurityConfig } = require('./securityConfig');
const JWT_SECRET = process.env.JWT_SECRET || 'dev_jwt_secret_fallback_key_min_32_chars';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev_jwt_refresh_secret_fallback_key_min_32_chars';
const RESET_JWT_SECRET = process.env.RESET_JWT_SECRET || 'dev_reset_jwt_secret_fallback_key_min_32_chars';

assertSecurityConfig({ JWT_SECRET, JWT_REFRESH_SECRET, RESET_JWT_SECRET });

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN || (isProduction() ? '24h' : '7d');
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '30d';
const RESET_JWT_EXPIRES_IN = process.env.RESET_JWT_EXPIRES_IN || '15m';

const generateAccessToken = (user, deviceId) => {
  const payload = {
    id: user.id,
    email: user.email,
    role: user.role,
    status: user.status,
    type: 'access',
    deviceId: deviceId || null,
  };
  if (user.permissions) {
    payload.permissions =
      typeof user.permissions === 'string'
        ? user.permissions.split(',').map((p) => p.trim()).filter(Boolean)
        : user.permissions;
  }
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
};

const generateRefreshToken = (user, deviceId) => {
  return jwt.sign({ id: user.id, type: 'refresh', deviceId: deviceId || null }, JWT_REFRESH_SECRET, {
    expiresIn: JWT_REFRESH_EXPIRES_IN,
  });
};

const generateResetToken = (userId) => {
  return jwt.sign({ id: userId, type: 'reset_password' }, RESET_JWT_SECRET, {
    expiresIn: RESET_JWT_EXPIRES_IN,
  });
};

const verifyAccessToken = (token) => {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.type && decoded.type !== 'access') return null;
    if (decoded.purpose === 'reset_password') return null;
    return decoded;
  } catch {
    return null;
  }
};

const verifyRefreshToken = (token) => {
  try {
    const decoded = jwt.verify(token, JWT_REFRESH_SECRET);
    if (decoded.type && decoded.type !== 'refresh') return null;
    return decoded;
  } catch {
    return null;
  }
};

const verifyResetToken = (token) => {
  try {
    const decoded = jwt.verify(token, RESET_JWT_SECRET);
    if (decoded.type !== 'reset_password') return null;
    return decoded;
  } catch {
    return null;
  }
};

/** Extract Bearer token from Socket.IO handshake */
const extractBearerFromHandshake = (handshake) => {
  const authToken = handshake.auth?.token;
  if (authToken && typeof authToken === 'string') return authToken;

  const header = handshake.headers?.authorization || handshake.headers?.Authorization;
  if (header && header.startsWith('Bearer ')) {
    return header.slice(7).trim();
  }
  return null;
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  generateResetToken,
  verifyAccessToken,
  verifyRefreshToken,
  verifyResetToken,
  extractBearerFromHandshake,
  isProduction,
};
