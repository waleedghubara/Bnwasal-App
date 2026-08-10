const { getPool } = require('../config/db');

/**
 * Always reload role/status from DB (banned users disconnected).
 */
async function refreshSocketUser(socket) {
  if (!socket?.userId) return false;
  try {
    const pool = getPool();
    const [rows] = await pool.query(
      'SELECT role, status, firstName, lastName, storeName, profileImage FROM users WHERE id = ?',
      [socket.userId]
    );
    if (rows.length === 0) return false;

    const u = rows[0];
    if (u.status === 'banned' || u.status === 'inactive') {
      socket.disconnect(true);
      return false;
    }

    socket.role = u.role;
    socket.userName =
      u.role === 'admin' || u.role === 'employee'
        ? `${u.firstName || ''} ${u.lastName || ''}`.trim() || 'الدعم الفني'
        : u.storeName || `${u.firstName || ''} ${u.lastName || ''}`.trim() || 'مستخدم';
    socket.userAvatar = u.profileImage || null;
    return true;
  } catch (err) {
    console.error('refreshSocketUser:', err);
    return false;
  }
}

module.exports = { refreshSocketUser };
