const { getPool } = require('../config/db');

const getMerchants = async (req, res, next) => {
  try {
    const pool = getPool();
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';
    const status = req.query.status || '';

    let where = "WHERE u.role = 'merchant'";
    const params = [];
    if (search) {
      where += ' AND (u.firstName LIKE ? OR u.lastName LIKE ? OR u.email LIKE ? OR u.phone LIKE ? OR u.storeName LIKE ?)';
      const s = `%${search}%`;
      params.push(s, s, s, s, s);
    }
    if (status) {
      where += ' AND u.status = ?';
      params.push(status);
    }

    const [countRows] = await pool.query(
      `SELECT COUNT(*) as total FROM users u ${where}`, params
    );
    const total = countRows[0].total;

    const [rows] = await pool.query(
      `SELECT u.id, u.firstName, u.lastName, u.email, u.phone, u.storeName,
              u.city, u.status, u.profileImage, u.walletBalance,
              u.createdAt, u.updatedAt,
              (SELECT COUNT(*) FROM orders WHERE merchantId = u.id) as totalOrders,
              (SELECT COUNT(*) FROM shipments WHERE merchantId = u.id) as totalShipments
       FROM users u ${where}
       ORDER BY u.createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const activeUsers = req.app.get('activeUsers');
    const merchants = rows.map((m) => ({
      ...m,
      isOnline: activeUsers ? activeUsers.has(String(m.id)) : false,
    }));

    res.status(200).json({
      status: 1,
      data: { merchants, total, page, limit },
    });
  } catch (error) {
    next(error);
  }
};

const getMerchantDetail = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, storeName,
              city, status, profileImage, walletBalance,
              nationalId, nationalIdFront, nationalIdBack,
              createdAt, updatedAt
       FROM users WHERE id = ? AND role = 'merchant'`,
      [id]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'التاجر غير موجود' });
    }

    const merchant = users[0];

    // Orders stats
    const [orderStats] = await pool.query(
      `SELECT
         COUNT(*) as totalOrders,
         SUM(CASE WHEN status = 'تم التسليم' THEN 1 ELSE 0 END) as completedOrders,
         SUM(CASE WHEN status = 'ملغي' THEN 1 ELSE 0 END) as cancelledOrders,
         COALESCE(SUM(orderPrice + deliveryFee), 0) as totalRevenue
       FROM orders WHERE merchantId = ?`,
      [id]
    );

    // Shipments stats
    const [shipmentStats] = await pool.query(
      `SELECT
         COUNT(*) as totalShipments,
         SUM(CASE WHEN status = 'تم التسليم' THEN 1 ELSE 0 END) as completedShipments,
         SUM(CASE WHEN status = 'ملغي' THEN 1 ELSE 0 END) as cancelledShipments,
         COALESCE(SUM(price), 0) as totalShipmentRevenue
       FROM shipments WHERE merchantId = ?`,
      [id]
    );

    // Wallet transactions
    const [walletStats] = await pool.query(
      `SELECT
         COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END), 0) as totalDeposits,
         COALESCE(SUM(CASE WHEN type = 'withdraw' THEN amount ELSE 0 END), 0) as totalWithdrawals
       FROM wallet_transactions WHERE userId = ? AND status = 'success'`,
      [id]
    );

    // Recent activity (last 10 orders + shipments)
    const [recentOrders] = await pool.query(
      `SELECT 'order' as type, id, orderNumber as refNumber, status, createdAt
       FROM orders WHERE merchantId = ?
       ORDER BY createdAt DESC LIMIT 5`,
      [id]
    );
    const [recentShipments] = await pool.query(
      `SELECT 'shipment' as type, id, shipmentNumber as refNumber, status, createdAt
       FROM shipments WHERE merchantId = ?
       ORDER BY createdAt DESC LIMIT 5`,
      [id]
    );
    const recentActivity = [...recentOrders, ...recentShipments]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 10);

    // Documents - fetch from driver_documents (where app uploads are saved)
    const [docs] = await pool.query(
      'SELECT nationalId, nationalIdFront, nationalIdBack FROM driver_documents WHERE userId = ?',
      [id]
    );
    const driverDocs = docs.length > 0 ? docs[0] : null;

    const documents = {
      nationalId: merchant.nationalId || (driverDocs?.nationalId) || null,
      nationalIdFront: merchant.nationalIdFront || (driverDocs?.nationalIdFront) || null,
      nationalIdBack: merchant.nationalIdBack || (driverDocs?.nationalIdBack) || null,
    };
    // Remove raw fields from merchant response to keep it clean
    delete merchant.nationalId;
    delete merchant.nationalIdFront;
    delete merchant.nationalIdBack;

    // AI Analysis
    const now = new Date();
    const createdAt = new Date(merchant.createdAt);
    const daysSinceCreated = Math.floor((now - createdAt) / (1000 * 60 * 60 * 24)) || 1;

    const totalOrders = orderStats[0].totalOrders || 0;
    const totalShipments = shipmentStats[0].totalShipments || 0;
    const totalActivities = totalOrders + totalShipments;
    const avgActivitiesPerDay = (totalActivities / daysSinceCreated).toFixed(2);

    const lastActive = merchant.updatedAt ? new Date(merchant.updatedAt) : createdAt;
    const daysSinceLastActive = Math.floor((now - lastActive) / (1000 * 60 * 60 * 24));

    let behavior, behaviorScore, isActiveNow;

    if (merchant.status !== 'active') {
      behavior = 'متوقف';
      behaviorScore = 0;
      isActiveNow = false;
    } else if (daysSinceLastActive > 30) {
      behavior = 'نادر الاستخدام';
      behaviorScore = 20;
      isActiveNow = false;
    } else if (daysSinceLastActive > 7) {
      behavior = 'متوسط الاستخدام';
      behaviorScore = 50;
      isActiveNow = daysSinceLastActive <= 3;
    } else if (avgActivitiesPerDay >= 0.5) {
      behavior = 'دائم الاستخدام';
      behaviorScore = 90;
      isActiveNow = true;
    } else if (avgActivitiesPerDay >= 0.1) {
      behavior = 'نشط أسبوعياً';
      behaviorScore = 65;
      isActiveNow = daysSinceLastActive <= 2;
    } else {
      behavior = 'خفيف الاستخدام';
      behaviorScore = 30;
      isActiveNow = daysSinceLastActive <= 7;
    }

    const activeUsers = req.app.get('activeUsers');
    const isOnline = activeUsers ? activeUsers.has(String(id)) : false;

    const analysis = {
      behavior,
      behaviorScore,
      isActiveNow,
      isOnline,
      avgActivitiesPerDay: parseFloat(avgActivitiesPerDay),
      daysSinceLastActive,
      totalActivities,
      daysSinceCreated,
      lastActive: merchant.updatedAt,
    };

    res.status(200).json({
      status: 1,
      data: {
        merchant: { ...merchant, isOnline },
        stats: {
          orders: orderStats[0],
          shipments: shipmentStats[0],
          wallet: walletStats[0],
        },
        recentActivity,
        analysis,
        documents,
      },
    });
  } catch (error) {
    next(error);
  }
};

const deleteMerchant = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'merchant']);
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'التاجر غير موجود' });
    }

    await pool.query('DELETE FROM users WHERE id = ?', [id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    res.status(200).json({ status: 1, message: 'تم حذف التاجر نهائياً' });
  } catch (error) {
    next(error);
  }
};

const updateMerchantStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { status } = req.body;

    if (!['active', 'banned', 'pending_verification'].includes(status)) {
      return res.status(400).json({ status: 0, message: 'حالة غير صالحة' });
    }

    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'merchant']);
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'التاجر غير موجود' });
    }

    await pool.query('UPDATE users SET status = ? WHERE id = ?', [status, id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    const label = status === 'banned' ? 'محظور' : status === 'active' ? 'نشط' : 'قيد التحقق';
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        `🔄 تغيير حالة تاجر إلى ${label}`,
        `تم تغيير حالة التاجر رقم ${id} إلى ${label}`,
        'merchant_status',
        { type: 'merchant_status', userId: id.toString(), status },
        req.user.id
      );
    } catch (_) {}
    res.status(200).json({ status: 1, message: `تم تغيير حالة التاجر إلى ${label}` });
  } catch (error) {
    next(error);
  }
};

const sendWarning = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { title, body } = req.body;
    if (!title || !body) {
      return res.status(400).json({ status: 0, message: 'العنوان والنص مطلوبان' });
    }

    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'merchant']);
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'التاجر غير موجود' });
    }

    const { sendNotification } = require('../utils/notificationDispatcher');
    const io = req.app.get('io');
    sendNotification(io, id, title, body, 'warning', { type: 'admin_warning' });
    if (io) io.to('admins').emit('dashboard_update');

    res.status(200).json({ status: 1, message: 'تم إرسال التحذير' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getMerchants, getMerchantDetail, deleteMerchant, updateMerchantStatus, sendWarning };
