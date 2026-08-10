const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const { getPool } = require('../config/db');
const config = require('../config/rateLimitConfig');

// Ensure logs directory exists
const logDir = path.join(__dirname, '../logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Logging Helper
const logAbuse = async (type, identifier, ip, reason) => {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [ABUSE_DETECTED] Type: ${type}, ID: ${identifier}, IP: ${ip}, Reason: ${reason}\n`;
  
  // 1. Log to file
  fs.appendFileSync(path.join(logDir, 'security_abuse.log'), logMessage);
  console.warn(logMessage.trim());

  // 2. Log to Database table security_incidents
  try {
    const pool = getPool();
    if (pool) {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS security_incidents (
          id INT AUTO_INCREMENT PRIMARY KEY,
          type VARCHAR(50),
          identifier VARCHAR(100),
          ip VARCHAR(45),
          reason TEXT,
          createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB;
      `);
      await pool.query(
        'INSERT INTO security_incidents (type, identifier, ip, reason) VALUES (?, ?, ?, ?)',
        [type, identifier, ip, reason]
      );
    }
  } catch (err) {
    console.error('Failed to log security incident to DB:', err.message);
  }
};

// Limiter Factory
const createLimiter = ({ type, windowMs, max, message, isUserLimiter = false }) => {
  const options = {
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    validate: { keyGeneratorIpFallback: false },
    handler: async (req, res, next, options) => {
      const identifier = req.body?.email || req.body?.phone || (req.user && req.user.id?.toString()) || 'anonymous';
      const reason = `Rate limit exceeded: ${options.max} requests per ${options.windowMs / 1000 / 60} mins (${isUserLimiter ? 'User Limiter' : 'IP Limiter'})`;
      await logAbuse(type, identifier, req.ip, reason);
      
      return res.status(429).json({
        status: 0,
        message: message || 'Too many requests. Please try again later.'
      });
    }
  };

  if (isUserLimiter) {
    options.keyGenerator = (req) => {
      // Track by body email or phone, or authenticated user's ID, fallback to IP
      return req.body?.email || req.body?.phone || (req.user && req.user.id?.toString()) || req.ip;
    };
  }

  return rateLimit(options);
};

// Limiters instantiation from configuration
const ipLoginLimiter = createLimiter({
  type: 'IP_LOGIN_ABUSE',
  ...config.ipLimits.login,
  isUserLimiter: false
});

const userLoginLimiter = createLimiter({
  type: 'USER_LOGIN_ABUSE',
  ...config.userLimits.login,
  isUserLimiter: true
});

const ipRegisterLimiter = createLimiter({
  type: 'IP_REGISTER_ABUSE',
  ...config.ipLimits.register,
  isUserLimiter: false
});

const userRegisterLimiter = createLimiter({
  type: 'USER_REGISTER_ABUSE',
  ...config.userLimits.register,
  isUserLimiter: true
});

const ipOtpLimiter = createLimiter({
  type: 'IP_OTP_ABUSE',
  ...config.ipLimits.otp,
  isUserLimiter: false
});

const userOtpLimiter = createLimiter({
  type: 'USER_OTP_ABUSE',
  ...config.userLimits.otp,
  isUserLimiter: true
});

const ipResetPasswordLimiter = createLimiter({
  type: 'IP_PASSWORD_RESET_ABUSE',
  ...config.ipLimits.passwordReset,
  isUserLimiter: false
});

const userResetPasswordLimiter = createLimiter({
  type: 'USER_PASSWORD_RESET_ABUSE',
  ...config.userLimits.passwordReset,
  isUserLimiter: true
});

// Legacy/Compatibility exports (fallback)
const authLimiter = ipRegisterLimiter;
const otpLimiter = ipOtpLimiter;
const loginLimiter = ipLoginLimiter;

// Existing limiters for other endpoints (kept intact)
const negotiationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 0, message: 'Too many negotiation requests. Please try again later.' },
});

const walletLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 0, message: 'Too many wallet requests. Please try again later.' },
});

const contactLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 0, message: 'Too many contact submissions. Please try again later.' },
});

module.exports = {
  // Legacy
  authLimiter,
  otpLimiter,
  loginLimiter,
  negotiationLimiter,
  walletLimiter,
  contactLimiter,
  
  // Dual limiters
  ipLoginLimiter,
  userLoginLimiter,
  ipRegisterLimiter,
  userRegisterLimiter,
  ipOtpLimiter,
  userOtpLimiter,
  ipResetPasswordLimiter,
  userResetPasswordLimiter
};
