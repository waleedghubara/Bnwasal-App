const { getPool } = require('../config/db');

const getCaptains = async (req, res, next) => {
  try {
    const pool = getPool();
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';
    const status = req.query.status || '';

    let where = "WHERE u.role = 'captain'";
    const params = [];
    if (search) {
      where += ' AND (u.firstName LIKE ? OR u.lastName LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)';
      const s = `%${search}%`;
      params.push(s, s, s, s);
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
      `SELECT u.id, u.firstName, u.lastName, u.email, u.phone,
              u.city, u.status, u.profileImage, u.walletBalance,
              u.createdAt, u.updatedAt, u.vehicleType,
              (SELECT COUNT(*) FROM shipments WHERE captainId = u.id) as totalShipments,
              (SELECT COUNT(*) FROM orders WHERE captainId = u.id) as totalOrders,
              ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = u.id), 1) as avgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = u.id) as reviewCount
       FROM users u ${where}
       ORDER BY u.createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const activeUsers = req.app.get('activeUsers');
    const captains = rows.map((m) => ({
      ...m,
      isOnline: activeUsers ? activeUsers.has(String(m.id)) : false,
    }));

    res.status(200).json({
      status: 1,
      data: { captains, total, page, limit },
    });
  } catch (error) {
    next(error);
  }
};

const getCaptainDetail = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query(
      `SELECT id, firstName, lastName, email, phone,
              city, status, profileImage, walletBalance,
              nationalId, nationalIdFront, nationalIdBack,
              latitude, longitude, vehicleType,
              createdAt, updatedAt
       FROM users WHERE id = ? AND role = 'captain'`,
      [id]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    }

    const captain = users[0];

    // Shipments stats
    const [shipmentStats] = await pool.query(
      `SELECT
         COUNT(*) as totalShipments,
         SUM(CASE WHEN status = 'منتهية' THEN 1 ELSE 0 END) as completedShipments,
         SUM(CASE WHEN status = 'ملغية' THEN 1 ELSE 0 END) as cancelledShipments,
         SUM(CASE WHEN status IN ('تم قبول العرض', 'جاري التنفيذ', 'تم التنفيذ', 'في الطريق') THEN 1 ELSE 0 END) as inProgressShipments
       FROM shipments WHERE captainId = ?`,
      [id]
    );

    // Orders stats
    const [orderStats] = await pool.query(
      `SELECT
         COUNT(*) as totalOrders,
         SUM(CASE WHEN status IN ('Completed', 'منتهي', 'تم التنفيذ') THEN 1 ELSE 0 END) as completedOrders,
         SUM(CASE WHEN status IN ('Cancelled', 'ملغي', 'ملغاة') THEN 1 ELSE 0 END) as cancelledOrders,
         SUM(CASE WHEN status IN ('Assigned To Captain', 'Captain Arrived', 'Picked Up', 'In Transit', 'Delivered', 'تم القبول', 'جاري التنفيذ', 'في الطريق') THEN 1 ELSE 0 END) as inProgressOrders
       FROM orders WHERE captainId = ?`,
      [id]
    );

    // Trips stats
    const [tripStats] = await pool.query(
      `SELECT
         COUNT(*) as totalTrips,
         SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedTrips,
         SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelledTrips
       FROM trips WHERE driverId = ?`,
      [id]
    );

    // Reviews
    const [reviewStats] = await pool.query(
      `SELECT
         ROUND(AVG(rating), 1) as avgRating,
         COUNT(*) as totalReviews
       FROM reviews WHERE revieweeId = ?`,
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

    // Recent activity
    const [recentShipments] = await pool.query(
      `SELECT 'shipment' as type, id, CONCAT('شحنة #', shipmentNumber) as ref, status, createdAt
       FROM shipments WHERE captainId = ? ORDER BY createdAt DESC LIMIT 5`,
      [id]
    );
    const [recentOrders] = await pool.query(
      `SELECT 'order' as type, id, CONCAT('طلب #', orderNumber) as ref, status, createdAt
       FROM orders WHERE captainId = ? ORDER BY createdAt DESC LIMIT 5`,
      [id]
    );
    const [recentTrips] = await pool.query(
      `SELECT 'trip' as type, id, CONCAT('رحلة #', id) as ref, status, createdAt
       FROM trips WHERE driverId = ? ORDER BY createdAt DESC LIMIT 5`,
      [id]
    );
    const recentActivity = [...recentShipments, ...recentOrders, ...recentTrips]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 10);

    // Documents - fetch from driver_documents (where app uploads are saved)
    const [docs] = await pool.query(
      'SELECT nationalId, nationalIdFront, nationalIdBack FROM driver_documents WHERE userId = ?',
      [id]
    );
    const driverDocs = docs.length > 0 ? docs[0] : null;

    const documents = {
      nationalId: captain.nationalId || (driverDocs?.nationalId) || null,
      nationalIdFront: captain.nationalIdFront || (driverDocs?.nationalIdFront) || null,
      nationalIdBack: captain.nationalIdBack || (driverDocs?.nationalIdBack) || null,
    };
    delete captain.nationalId;
    delete captain.nationalIdFront;
    delete captain.nationalIdBack;

    // AI Analysis
    const now = new Date();
    const createdAt = new Date(captain.createdAt);
    const daysSinceCreated = Math.floor((now - createdAt) / (1000 * 60 * 60 * 24)) || 1;

    const totalShipments = shipmentStats[0].totalShipments || 0;
    const totalOrders = orderStats[0].totalOrders || 0;
    const totalTrips = tripStats[0].totalTrips || 0;
    const totalActivities = totalShipments + totalOrders + totalTrips;
    const avgActivitiesPerDay = (totalActivities / daysSinceCreated).toFixed(2);
    const completionRate = totalActivities > 0
      ? Math.round(((shipmentStats[0].completedShipments || 0) + (orderStats[0].completedOrders || 0) + (tripStats[0].completedTrips || 0)) / totalActivities * 100)
      : 0;

    const lastActive = captain.updatedAt ? new Date(captain.updatedAt) : createdAt;
    const daysSinceLastActive = Math.floor((now - lastActive) / (1000 * 60 * 60 * 24));

    let behavior, behaviorScore;
    if (captain.status !== 'active') {
      behavior = 'متوقف';
      behaviorScore = 0;
    } else if (daysSinceLastActive > 30) {
      behavior = 'نادر الاستخدام';
      behaviorScore = 20;
    } else if (daysSinceLastActive > 7) {
      behavior = 'متوسط الاستخدام';
      behaviorScore = 50;
    } else if (avgActivitiesPerDay >= 1) {
      behavior = 'دائم الاستخدام';
      behaviorScore = 95;
    } else if (avgActivitiesPerDay >= 0.3) {
      behavior = 'نشط أسبوعياً';
      behaviorScore = 70;
    } else {
      behavior = 'خفيف الاستخدام';
      behaviorScore = 35;
    }

    const activeUsers = req.app.get('activeUsers');
    const isOnline = activeUsers ? activeUsers.has(String(id)) : false;

    const analysis = {
      behavior,
      behaviorScore,
      isOnline,
      avgActivitiesPerDay: parseFloat(avgActivitiesPerDay),
      daysSinceLastActive,
      totalActivities,
      daysSinceCreated,
      completionRate,
      lastActive: captain.updatedAt,
    };

    // Active delivery check
    let activeDelivery = null;

    // Check shipments in progress
    const [activeShipments] = await pool.query(
      `SELECT s.id, s.shipmentNumber as number, 'shipment' as type, s.status,
              s.merchantLatitude, s.merchantLongitude, s.toLatitude, s.toLongitude, 
              s.startLatitude, s.startLongitude, s.fromAddress, s.toAddress, s.price,
              m.storeName as merchantName, m.phone as merchantPhone
       FROM shipments s
       LEFT JOIN users m ON s.merchantId = m.id
       WHERE s.captainId = ? AND s.status IN ('تم قبول العرض', 'جاري التنفيذ', 'تم التنفيذ', 'في الطريق')
       LIMIT 1`,
      [id]
    );

    if (activeShipments.length > 0) {
      activeDelivery = activeShipments[0];
    } else {
      // Check orders in progress
      const [activeOrders] = await pool.query(
        `SELECT o.id, o.orderNumber as number, 'order' as type, o.status,
                m.latitude as merchantLatitude, m.longitude as merchantLongitude, 
                o.latitude as toLatitude, o.longitude as toLongitude,
                o.startLatitude, o.startLongitude, o.deliveryAddress as toAddress,
                'مقر المتجر' as fromAddress, o.orderPrice as price,
                m.storeName as merchantName, m.phone as merchantPhone
         FROM orders o
         LEFT JOIN users m ON o.merchantId = m.id
         WHERE o.captainId = ? AND o.status IN (
           'Assigned To Captain', 'Captain Arrived', 'Picked Up', 'In Transit', 'Delivered',
           'تم القبول', 'جاري التنفيذ', 'في الطريق'
         )
         LIMIT 1`,
        [id]
      );
      if (activeOrders.length > 0) {
        activeDelivery = activeOrders[0];
      }
    }

    // Fetch last 10 past deliveries (completed/delivered/cancelled)
    const [pastShipments] = await pool.query(
      `SELECT s.id, s.shipmentNumber as number, 'shipment' as type, s.status,
              s.merchantLatitude, s.merchantLongitude, s.toLatitude, s.toLongitude,
              s.startLatitude, s.startLongitude, s.fromAddress, s.toAddress, s.price, s.createdAt,
              m.storeName as merchantName, m.phone as merchantPhone
       FROM shipments s
       LEFT JOIN users m ON s.merchantId = m.id
       WHERE s.captainId = ? AND s.status NOT IN ('جديدة', 'بانتظار القبول', 'تم قبول العرض', 'جاري التنفيذ', 'تم التنفيذ', 'في الطريق')
       AND (s.toLatitude IS NOT NULL OR s.startLatitude IS NOT NULL)
       ORDER BY s.createdAt DESC LIMIT 10`,
      [id]
    );

    const [pastOrders] = await pool.query(
      `SELECT o.id, o.orderNumber as number, 'order' as type, o.status,
              m.latitude as merchantLatitude, m.longitude as merchantLongitude,
              o.latitude as toLatitude, o.longitude as toLongitude,
              o.startLatitude, o.startLongitude, o.deliveryAddress as toAddress,
              'مقر المتجر' as fromAddress, o.orderPrice as price, o.createdAt,
              m.storeName as merchantName, m.phone as merchantPhone
       FROM orders o
       LEFT JOIN users m ON o.merchantId = m.id
       WHERE o.captainId = ? AND o.status NOT IN (
         'Pending Review', 'Ready For Assignment',
         'Assigned To Captain', 'Captain Arrived', 'Picked Up', 'In Transit', 'Delivered',
         'بانتظار القبول', 'تم القبول', 'جاري التنفيذ', 'في الطريق'
       )
       AND (o.latitude IS NOT NULL OR o.startLatitude IS NOT NULL)
       ORDER BY o.createdAt DESC LIMIT 10`,
      [id]
    );

    const pastDeliveries = [...pastShipments, ...pastOrders]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 10);

    res.status(200).json({
      status: 1,
      data: {
        captain: { ...captain, isOnline },
        activeDelivery,
        pastDeliveries,
        stats: {
          shipments: shipmentStats[0],
          orders: orderStats[0],
          trips: tripStats[0],
          reviews: reviewStats[0],
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

const deleteCaptain = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'captain']);
    if (users.length === 0) return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    await pool.query('DELETE FROM users WHERE id = ?', [id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    res.status(200).json({ status: 1, message: 'تم حذف الكابتن نهائياً' });
  } catch (error) {
    next(error);
  }
};

const updateCaptainStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { status } = req.body;
    if (!['active', 'banned', 'pending_verification'].includes(status)) {
      return res.status(400).json({ status: 0, message: 'حالة غير صالحة' });
    }
    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'captain']);
    if (users.length === 0) return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    await pool.query('UPDATE users SET status = ? WHERE id = ?', [status, id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    const label = status === 'banned' ? 'محظور' : status === 'active' ? 'نشط' : 'قيد التحقق';
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        `🔄 تغيير حالة كابتن إلى ${label}`,
        `تم تغيير حالة الكابتن رقم ${id} إلى ${label}`,
        'captain_status',
        { type: 'captain_status', userId: id.toString(), status },
        req.user.id
      );
    } catch (_) { }
    res.status(200).json({ status: 1, message: `تم تغيير حالة الكابتن إلى ${label}` });
  } catch (error) {
    next(error);
  }
};

const sendWarning = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { title, body } = req.body;
    if (!title || !body) return res.status(400).json({ status: 0, message: 'العنوان والنص مطلوبان' });
    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [id, 'captain']);
    if (users.length === 0) return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    const { sendNotification } = require('../utils/notificationDispatcher');
    const io = req.app.get('io');
    sendNotification(io, id, title, body, 'warning', { type: 'admin_warning' });
    if (io) io.to('admins').emit('dashboard_update');
    res.status(200).json({ status: 1, message: 'تم إرسال التحذير' });
  } catch (error) {
    next(error);
  }
};

const uploadCaptainDocuments = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { nationalId } = req.body;

    // Check if captain exists
    const [captains] = await pool.query(
      'SELECT id FROM users WHERE id = ? AND role = ?',
      [id, 'captain']
    );
    if (captains.length === 0) {
      return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    }

    let profileImagePath = null;
    let frontImage = null;
    let backImage = null;

    if (req.files) {
      if (req.files.profileImage) {
        profileImagePath = `/uploads/${req.files.profileImage[0].filename}`;
      }
      if (req.files.nationalIdFront) {
        frontImage = `/uploads/${req.files.nationalIdFront[0].filename}`;
      }
      if (req.files.nationalIdBack) {
        backImage = `/uploads/${req.files.nationalIdBack[0].filename}`;
      }
    }

    // Update users table for profile image
    if (profileImagePath) {
      await pool.query('UPDATE users SET profileImage = ? WHERE id = ?', [profileImagePath, id]);
    }

    // Save/update driver_documents
    if (nationalId || frontImage || backImage) {
      const [existing] = await pool.query(
        'SELECT id FROM driver_documents WHERE userId = ?',
        [id]
      );

      if (existing.length > 0) {
        const updateFields = [];
        const params = [];
        if (nationalId) {
          updateFields.push('nationalId = ?');
          params.push(nationalId);
        }
        if (frontImage) {
          updateFields.push('nationalIdFront = ?');
          params.push(frontImage);
        }
        if (backImage) {
          updateFields.push('nationalIdBack = ?');
          params.push(backImage);
        }
        if (updateFields.length > 0) {
          params.push(id);
          await pool.query(
            `UPDATE driver_documents SET ${updateFields.join(', ')} WHERE userId = ?`,
            params
          );
        }
      } else {
        await pool.query(
          'INSERT INTO driver_documents (userId, nationalId, nationalIdFront, nationalIdBack) VALUES (?, ?, ?, ?)',
          [id, nationalId || '', frontImage || '', backImage || '']
        );
      }

      // Also update nationalId* fields in users table (for redundancy/migration compatibility)
      const usersUpdateFields = [];
      const usersParams = [];
      if (nationalId) {
        usersUpdateFields.push('nationalId = ?');
        usersParams.push(nationalId);
      }
      if (frontImage) {
        usersUpdateFields.push('nationalIdFront = ?');
        usersParams.push(frontImage);
      }
      if (backImage) {
        usersUpdateFields.push('nationalIdBack = ?');
        usersParams.push(backImage);
      }
      if (usersUpdateFields.length > 0) {
        usersParams.push(id);
        await pool.query(
          `UPDATE users SET ${usersUpdateFields.join(', ')} WHERE id = ?`,
          usersParams
        );
      }
    }

    res.status(200).json({
      status: 1,
      message: 'تم رفع وتحديث مستندات الكابتن بنجاح',
      data: {
        profileImage: profileImagePath,
        nationalId,
        nationalIdFront: frontImage,
        nationalIdBack: backImage
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getCaptains,
  getCaptainDetail,
  deleteCaptain,
  updateCaptainStatus,
  sendWarning,
  uploadCaptainDocuments
};
