const { getPool } = require('../config/db');

// 1. GET ALL NOTIFICATIONS FOR LOGGED IN USER
const getNotifications = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    const [rows] = await pool.query(
      `SELECT id, title, body, category, isRead, createdAt
       FROM notifications
       WHERE userId = ?
       ORDER BY createdAt DESC`,
      [userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحميل الإشعارات بنجاح',
      data: rows.map(row => ({
        id: row.id.toString(),
        title: row.title,
        body: row.body,
        category: row.category,
        isRead: row.isRead === 1 || row.isRead === true,
        createdAt: row.createdAt
      }))
    });
  } catch (error) {
    next(error);
  }
};

// 2. MARK A SPECIFIC NOTIFICATION AS READ
const markRead = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const { id } = req.params;

    const [notif] = await pool.query(
      'SELECT id, userId FROM notifications WHERE id = ?',
      [id]
    );

    if (notif.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الإشعار غير موجود'
      });
    }

    if (notif[0].userId !== userId) {
      return res.status(403).json({
        status: 0,
        message: 'غير مصرح لك بتحديث هذا الإشعار'
      });
    }

    await pool.query(
      'UPDATE notifications SET isRead = 1 WHERE id = ?',
      [id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحديد الإشعار كمقروء'
    });
  } catch (error) {
    next(error);
  }
};

// 3. MARK ALL NOTIFICATIONS AS READ
const markAllRead = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    await pool.query(
      'UPDATE notifications SET isRead = 1 WHERE userId = ?',
      [userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحديد جميع الإشعارات كمقروءة'
    });
  } catch (error) {
    next(error);
  }
};

// 4. DELETE A SPECIFIC NOTIFICATION
const deleteNotification = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const { id } = req.params;

    const [notif] = await pool.query(
      'SELECT id, userId FROM notifications WHERE id = ?',
      [id]
    );

    if (notif.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الإشعار غير موجود'
      });
    }

    if (notif[0].userId !== userId) {
      return res.status(403).json({
        status: 0,
        message: 'غير مصرح لك بحذف هذا الإشعار'
      });
    }

    await pool.query(
      'DELETE FROM notifications WHERE id = ?',
      [id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم حذف الإشعار بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 5. CLEAR ALL NOTIFICATIONS FOR USER
const clearAllNotifications = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    await pool.query(
      'DELETE FROM notifications WHERE userId = ?',
      [userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم مسح جميع الإشعارات بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 6. SEND TEST NOTIFICATION TO SELF
const testSend = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { title, body } = req.body;
    const io = req.app.get('io');
    const { sendNotification } = require('../utils/notificationDispatcher');

    await sendNotification(
      io,
      userId,
      title || '🔔 إشعار تجريبي',
      body || 'هذا إشعار وهمي للتجربة — تم إرساله بنجاح ✅',
      'system',
      { type: 'test' }
    );

    res.status(200).json({
      status: 1,
      message: '✅ تم إرسال الإشعار التجريبي'
    });
  } catch (error) {
    next(error);
  }
};

// 7. GET TARGET USERS FOR NOTIFICATION (admin only)
const getTargetUsers = async (req, res, next) => {
  try {
    const pool = getPool();
    const { targetType, search } = req.query;
    let whereClause = '';
    const params = [];
    if (targetType === 'merchants') {
      whereClause = "WHERE role = 'merchant'";
    } else if (targetType === 'captains') {
      whereClause = "WHERE role = 'captain'";
    } else {
      whereClause = "WHERE role IN ('merchant','captain')";
    }
    if (search) {
      whereClause += ' AND (firstName LIKE ? OR lastName LIKE ? OR email LIKE ? OR phone LIKE ?)';
      const s = `%${search}%`;
      params.push(s, s, s, s);
    }
    const [rows] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, profileImage, role, storeName, fcmToken, webPushSubscription
       FROM users ${whereClause}
       ORDER BY createdAt DESC`,
      params
    );
    const users = rows.map((u) => ({
      id: u.id,
      name: u.storeName ? `${u.storeName} (${u.firstName} ${u.lastName})` : `${u.firstName} ${u.lastName}`,
      email: u.email,
      phone: u.phone,
      role: u.role,
      profileImage: u.profileImage,
      fcmToken: u.fcmToken,
      webPushSubscription: u.webPushSubscription,
    }));
    res.status(200).json({ status: 1, data: { users } });
  } catch (error) {
    next(error);
  }
};

// 9. SEND BULK NOTIFICATION (admin only — requires admin role)
const sendBulkNotification = async (req, res, next) => {
  try {
    const pool = getPool();
    const { targetType, specificUserId, specificUserIds, title, body } = req.body;
    const io = req.app.get('io');
    const { sendNotification } = require('../utils/notificationDispatcher');

    if (!title || !body) {
      return res.status(400).json({ status: 0, message: 'العنوان والنص مطلوبان' });
    }

    let whereClause = '';
    const params = [];
    if (targetType === 'specific' && specificUserIds && specificUserIds.length > 0) {
      const placeholders = specificUserIds.map(() => '?').join(',');
      whereClause = `WHERE id IN (${placeholders})`;
      params.push(...specificUserIds);
    } else if (targetType === 'specific' && specificUserId) {
      whereClause = 'WHERE id = ?';
      params.push(specificUserId);
    } else if (targetType === 'merchants') {
      whereClause = "WHERE role = 'merchant'";
    } else if (targetType === 'captains') {
      whereClause = "WHERE role = 'captain'";
    } else {
      whereClause = "WHERE role IN ('merchant','captain')";
    }

    const [users] = await pool.query(
      `SELECT id FROM users ${whereClause}`,
      params
    );

    let sent = 0;
    for (const user of users) {
      try {
        await sendNotification(io, user.id, title, body, 'admin', { type: 'bulk' });
        sent++;
      } catch (_) {}
    }

    res.status(200).json({
      status: 1,
      message: `✅ تم إرسال الإشعار إلى ${sent} مستخدم${sent > 1 ? 'ين' : ''}`,
      data: { sent },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNotifications,
  markRead,
  markAllRead,
  deleteNotification,
  clearAllNotifications,
  testSend,
  getTargetUsers,
  sendBulkNotification
};
