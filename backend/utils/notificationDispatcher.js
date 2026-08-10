const webpush = require('web-push');
const { getPool } = require('../config/db');
const { sendPushNotification, createDbNotification } = require('./notificationHelper');

// VAPID keys are generated once and stored — configure via env or auto-generate on first run
const VAPID_PUBLIC_KEY = process.env.VAPID_PUBLIC_KEY || null;
const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY || null;

if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY) {
  webpush.setVapidDetails(
    'mailto:support@bnwasal.com',
    VAPID_PUBLIC_KEY,
    VAPID_PRIVATE_KEY
  );
  console.log('🔑 Web Push VAPID keys configured from environment');
}

const sendWebPush = async (userId, title, body, data = {}) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query('SELECT webPushSubscription FROM users WHERE id = ?', [userId]);
    if (rows.length === 0 || !rows[0].webPushSubscription) return null;

    const subscription = typeof rows[0].webPushSubscription === 'string'
      ? JSON.parse(rows[0].webPushSubscription)
      : rows[0].webPushSubscription;

    const payload = JSON.stringify({ title, body, ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' });

    await webpush.sendNotification(subscription, payload);
    return true;
  } catch (error) {
    if (error.statusCode === 410 || error.statusCode === 404) {
      console.log(`🗑️ Removing expired web push subscription for user ${userId}`);
      try {
        const pool = getPool();
        await pool.query('UPDATE users SET webPushSubscription = NULL WHERE id = ?', [userId]);
      } catch (_) {}
    } else {
      console.error(`❌ Web Push error for user ${userId}:`, error.message);
    }
    return null;
  }
};

const sendSocketNotification = (io, userId, notification) => {
  if (!io) return;
  io.to(`user_${userId}`).emit('notification', notification);
};

const sendNotification = async (io, userId, title, body, category = 'system', data = {}) => {
  const notification = { title, body, category, data, createdAt: new Date().toISOString() };

  // 1. Save to database
  await createDbNotification(userId, title, body, category);

  // 2. Send FCM (Android)
  try {
    const pool = getPool();
    const [rows] = await pool.query('SELECT fcmToken, webPushSubscription FROM users WHERE id = ?', [userId]);
    if (rows.length > 0) {
      const user = rows[0];
      if (user.fcmToken) {
        sendPushNotification(user.fcmToken, title, body, data);
      }
      // 3. Send Web Push (Windows / Web)
      if (user.webPushSubscription) {
        sendWebPush(userId, title, body, data);
      }
    }
  } catch (err) {
    console.error('❌ Error fetching user push tokens:', err.message);
  }

  // 4. Emit via Socket.IO for real-time delivery
  sendSocketNotification(io, userId, notification);

  return notification;
};

const getVapidPublicKey = () => {
  return VAPID_PUBLIC_KEY;
};

module.exports = {
  sendNotification,
  sendWebPush,
  sendSocketNotification,
  getVapidPublicKey
};
