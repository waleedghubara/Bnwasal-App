/**
 * Configurable Rate Limiting Settings
 * Dual protection values: IP limits and User-based identifier limits
 */
module.exports = {
  // IP limits config (blocks entire IP if triggered)
  ipLimits: {
    login: { windowMs: 15 * 60 * 1000, max: 20, message: 'Too many login attempts from this IP. Please try again in 15 minutes.' },
    register: { windowMs: 15 * 60 * 1000, max: 10, message: 'Too many registration attempts from this IP. Please try again in 15 minutes.' },
    otp: { windowMs: 15 * 60 * 1000, max: 15, message: 'Too many OTP requests from this IP. Please try again in 15 minutes.' },
    passwordReset: { windowMs: 15 * 60 * 1000, max: 8, message: 'Too many password reset attempts from this IP. Please try again in 15 minutes.' },
  },
  
  // User/Identifier-based limits config (blocks target account/identifier)
  userLimits: {
    login: { windowMs: 15 * 60 * 1000, max: 5, message: 'Too many login attempts on this account. Please try again in 15 minutes.' },
    register: { windowMs: 15 * 60 * 1000, max: 3, message: 'Too many registration attempts on this identifier. Please try again in 15 minutes.' },
    otp: { windowMs: 15 * 60 * 1000, max: 5, message: 'Too many OTP requests for this account. Please try again in 15 minutes.' },
    passwordReset: { windowMs: 15 * 60 * 1000, max: 3, message: 'Too many password reset requests for this account. Please try again in 15 minutes.' },
  }
};
