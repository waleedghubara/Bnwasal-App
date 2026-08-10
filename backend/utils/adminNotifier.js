const { getPool } = require('../config/db');
const { sendNotification } = require('./notificationDispatcher');

const notifyAdmins = async (io, title, body, category = 'admin', data = {}, excludeUserId = null) => {
  try {
    const pool = getPool();
    const [admins] = await pool.query(
      `SELECT id FROM users WHERE role IN ('admin','employee')`
    );

    if (admins.length === 0) return;

    for (const admin of admins) {
      if (excludeUserId && admin.id === excludeUserId) continue;
      sendNotification(io, admin.id, title, body, category, { ...data, type: category });
    }

    if (io) {
      io.to('admins').emit('admin_notification', { title, body, category, data: { ...data, type: category }, createdAt: new Date().toISOString() });
    }

    const count = excludeUserId ? admins.filter(a => a.id !== excludeUserId).length : admins.length;
    console.log(`🔔 Admin notification sent to ${count} admin(s): ${title}`);
  } catch (err) {
    console.error('❌ adminNotifier error:', err.message);
  }
};

module.exports = { notifyAdmins };
