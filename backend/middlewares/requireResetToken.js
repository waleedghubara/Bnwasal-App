const { verifyResetToken } = require('../utils/tokenHelper');

const requireResetToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ status: 0, message: 'Reset token is required' });
  }

  const decoded = verifyResetToken(token);
  if (!decoded?.id) {
    return res.status(401).json({
      status: 0,
      message: 'Reset token is invalid or expired',
    });
  }

  req.user = { id: decoded.id, type: 'reset_password' };
  next();
};

module.exports = { requireResetToken };
