const { verifyAccessToken } = require('../utils/tokenHelper');

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      status: 0,
      message: 'Access Token is required'
    });
  }

  const decoded = verifyAccessToken(token);
  if (!decoded) {
    return res.status(401).json({
      status: 0,
      message: 'Token is invalid or expired'
    });
  }

  // Device ID Binding verification
  const requestDeviceId = req.headers['x-device-id'];
  if (decoded.deviceId && decoded.deviceId !== requestDeviceId) {
    return res.status(401).json({
      status: 0,
      message: 'Device binding verification failed. This session belongs to another device.',
      errorCode: 'DEVICE_MISMATCH'
    });
  }

  req.user = decoded;

  try {
    const { getPool } = require('../config/db');
    const pool = getPool();
    const [users] = await pool.query(
      'SELECT id, role, status, permissions FROM users WHERE id = ?',
      [decoded.id]
    );
    if (users.length === 0) {
      return res.status(401).json({ status: 0, message: 'User not found' });
    }
    const dbUser = users[0];
    if (dbUser.status === 'banned') {
      return res.status(403).json({ status: 0, message: 'هذا الحساب محظور', is_banned: true });
    }
    if (dbUser.role !== 'admin' && dbUser.role !== 'employee' && dbUser.status !== 'active') {
      return res.status(403).json({
        status: 0,
        message: 'الحساب غير مفعل',
        errorCode: 'ACCOUNT_INACTIVE',
      });
    }
    req.user.role = dbUser.role;
    req.user.status = dbUser.status;
    if (dbUser.permissions) {
      req.user.permissions =
        typeof dbUser.permissions === 'string'
          ? dbUser.permissions.split(',').map((p) => p.trim()).filter(Boolean)
          : dbUser.permissions;
    }
  } catch (err) {
    console.error('authenticateToken user lookup failed:', err);
    return res.status(500).json({ status: 0, message: 'Authentication error' });
  }

  // Maintenance check: non-admin users are blocked if maintenance mode is on
  if (req.user.role !== 'admin') {
    try {
      const { getPool } = require('../config/db');
      const pool = getPool();
      const [rows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_mode'");
      if (rows.length > 0 && rows[0].value === '1') {
        const [msgRows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_message'");
        const message = msgRows.length > 0 ? msgRows[0].value : 'التطبيق في وضع الصيانة حالياً';
        return res.status(503).json({ status: 0, message, maintenance: true });
      }
    } catch (_) {}
  }

  next();
};

const authenticateTokenAllowPending = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      status: 0,
      message: 'Access Token is required'
    });
  }

  const decoded = verifyAccessToken(token);
  if (!decoded) {
    return res.status(401).json({
      status: 0,
      message: 'Token is invalid or expired'
    });
  }

  // Device ID Binding verification
  const requestDeviceId = req.headers['x-device-id'];
  if (decoded.deviceId && decoded.deviceId !== requestDeviceId) {
    return res.status(401).json({
      status: 0,
      message: 'Device binding verification failed. This session belongs to another device.',
      errorCode: 'DEVICE_MISMATCH'
    });
  }

  req.user = decoded;

  try {
    const { getPool } = require('../config/db');
    const pool = getPool();
    const [users] = await pool.query(
      'SELECT id, role, status, permissions FROM users WHERE id = ?',
      [decoded.id]
    );
    if (users.length === 0) {
      return res.status(401).json({ status: 0, message: 'User not found' });
    }
    const dbUser = users[0];
    if (dbUser.status === 'banned') {
      return res.status(403).json({ status: 0, message: 'هذا الحساب محظور', is_banned: true });
    }
    if (
      dbUser.role !== 'admin' &&
      dbUser.role !== 'employee' &&
      dbUser.status !== 'active' &&
      dbUser.status !== 'pending_verification'
    ) {
      return res.status(403).json({
        status: 0,
        message: 'الحساب غير مفعل',
        errorCode: 'ACCOUNT_INACTIVE',
      });
    }
    req.user.role = dbUser.role;
    req.user.status = dbUser.status;
    if (dbUser.permissions) {
      req.user.permissions =
        typeof dbUser.permissions === 'string'
          ? dbUser.permissions.split(',').map((p) => p.trim()).filter(Boolean)
          : dbUser.permissions;
    }
  } catch (err) {
    console.error('authenticateTokenAllowPending user lookup failed:', err);
    return res.status(500).json({ status: 0, message: 'Authentication error' });
  }

  // Maintenance check: non-admin users are blocked if maintenance mode is on
  if (req.user.role !== 'admin') {
    try {
      const { getPool } = require('../config/db');
      const pool = getPool();
      const [rows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_mode'");
      if (rows.length > 0 && rows[0].value === '1') {
        const [msgRows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_message'");
        const message = msgRows.length > 0 ? msgRows[0].value : 'التطبيق في وضع الصيانة حالياً';
        return res.status(503).json({ status: 0, message, maintenance: true });
      }
    } catch (_) {}
  }

  next();
};

// Maintenance mode middleware — blocks non-admin users when maintenance is on
// Must be placed after authenticateToken in the middleware chain.
const checkMaintenance = async (req, res, next) => {
  try {
    const { getPool } = require('../config/db');
    const pool = getPool();
    const [rows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_mode'");
    if (rows.length > 0 && rows[0].value === '1') {
      // Admin users bypass maintenance
      if (req.user && req.user.role === 'admin') return next();
      const [msgRows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'maintenance_message'");
      const message = msgRows.length > 0 ? msgRows[0].value : 'التطبيق في وضع الصيانة حالياً';
      return res.status(503).json({ status: 0, message, maintenance: true });
    }
  } catch (_) {}
  next();
};

const authorizeRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        status: 0,
        message: 'Unauthorized: Authentication required'
      });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        status: 0,
        message: 'Access Denied: Insufficient permissions'
      });
    }
    next();
  };
};

// Allow access if user is admin OR has one of the required permissions (for employees)
const authorizeByPermission = (...requiredPermissions) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        status: 0,
        message: 'Unauthorized: Authentication required'
      });
    }
    // Admin always has full access
    if (req.user.role === 'admin') return next();
    // Employee must have at least one of the required permissions
    if (req.user.role === 'employee' && req.user.permissions) {
      const perms = Array.isArray(req.user.permissions)
        ? req.user.permissions
        : (typeof req.user.permissions === 'string' ? req.user.permissions.split(',').map(p => p.trim()).filter(Boolean) : []);
      // If no specific permissions required, any permission is enough
      if (requiredPermissions.length === 0) {
        if (perms.length > 0) return next();
      } else {
        const hasPermission = requiredPermissions.some(p => perms.includes(p));
        if (hasPermission) return next();
      }
    }
    return res.status(403).json({
      status: 0,
      message: 'Access Denied: Insufficient permissions'
    });
  };
};

// Allow admin or any employee with at least one permission
const authorizeAnyEmployee = authorizeByPermission;

module.exports = {
  authenticateToken,
  authenticateTokenAllowPending,
  authorizeRoles,
  authorizeByPermission,
  authorizeAnyEmployee,
  checkMaintenance
};
