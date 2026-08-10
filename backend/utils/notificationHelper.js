const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

try {
  // Load the service account JSON from the workspace root (parent of backend folder)
  const serviceAccountPath = path.join(__dirname, '../../wedeliver123-b73fc29a45eb.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('🔥 Firebase Admin initialized successfully');
  } else {
    console.error('❌ Firebase Service Account JSON not found at:', serviceAccountPath);
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin:', error);
}

const sendPushNotification = async (token, title, body, data = {}) => {
  if (!token) {
    console.log('⚠️ Skipping push notification: No token provided');
    return null;
  }
  try {
    // Sanitize data payload for FCM:
    // 1. All values must be strings.
    // 2. Rename forbidden reserved keys: 'from' -> 'fromAddress', 'to' -> 'toAddress'.
    const sanitizedData = {};
    if (data && typeof data === 'object') {
      for (const [key, value] of Object.entries(data)) {
        if (value === null || value === undefined) continue;
        let targetKey = key;
        if (key === 'from') targetKey = 'fromAddress';
        else if (key === 'to') targetKey = 'toAddress';
        sanitizedData[targetKey] = String(value);
      }
    }
    sanitizedData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

    const message = {
      token: token,
      notification: {
        title: title,
        body: body
      },
      data: sanitizedData,
      android: {
        priority: 'high',
        notification: {
          sound: 'app_notification',
          channelId: 'we_deliver_alerts_v1'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'app_notification.wav'
          }
        }
      }
    };
    const response = await admin.messaging().send(message);
    console.log('✉️ Push notification sent successfully:', response);
    return response;
  } catch (error) {
    const errCode = error?.errorInfo?.code || error?.code || '';
    if (errCode === 'messaging/registration-token-not-registered') {
      console.log('⚠️ FCM registration token is no longer registered. Cleaning up...');
      try {
        const { getPool } = require('../config/db');
        const pool = getPool();
        await pool.query('UPDATE users SET fcmToken = NULL WHERE fcmToken = ?', [token]);
        console.log(`🗑️ Cleaned up expired FCM token from DB`);
      } catch (dbErr) {
        console.error('❌ Failed to clean up expired FCM token from DB:', dbErr.message);
      }
    } else {
      console.error('❌ Error sending push notification:', error);
    }
    return null;
  }
};

const createDbNotification = async (userId, title, body, category = 'system') => {
  try {
    const { getPool } = require('../config/db');
    const pool = getPool();
    await pool.query(
      'INSERT INTO notifications (userId, title, body, category) VALUES (?, ?, ?, ?)',
      [userId, title, body, category]
    );
    console.log(`🔔 Saved notification in database for user ${userId}: ${title}`);
  } catch (error) {
    console.error('❌ Error saving notification to database:', error);
  }
};

module.exports = {
  sendPushNotification,
  createDbNotification
};
