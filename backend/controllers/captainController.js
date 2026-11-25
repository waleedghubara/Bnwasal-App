const bcrypt = require('bcryptjs');
const { getPool } = require('../config/db');
const { logAudit } = require('../utils/auditLogger');

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
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = u.id) as reviewCount,
              (
                (SELECT COUNT(*) FROM orders o 
                 WHERE o.captainId = u.id 
                   AND LOWER(o.status) NOT IN ('مكتمل', 'ملغي', 'ملغى', 'ملغية', 'completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'cancelled', 'rejected', 'مرفوض', 'منتهي', 'منتهية')
                   AND (o.storeOrderStatus IS NULL OR UPPER(o.storeOrderStatus) NOT IN ('COMPLETED', 'CANCELLED'))
                   AND (o.captainTripStatus IS NULL OR UPPER(o.captainTripStatus) NOT IN ('DELIVERED_SUCCESSFULLY', 'CANCELLED', 'COMPLETED'))
                )
                +
                (SELECT COUNT(*) FROM shipments s 
                 WHERE s.captainId = u.id 
                   AND LOWER(s.status) NOT IN ('completed', 'مكتمل', 'منتهية', 'منتهي', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'delivered', 'ملغي', 'ملغى', 'ملغية', 'cancelled', 'rejected', 'مرفوض')
                )
              ) as activeOrdersCount,
              sc.shiftId,
              sc.clockInTime,
              sc.clockOutTime,
              sc.isOnBreak,
              sc.breakStartTime,
              sc.breakEndTime,
              sc.breakDurationMinutes,
              sh.name AS shiftName,
              sh.status AS shiftStatus
       FROM users u
       LEFT JOIN shift_captains sc ON sc.id = (
         SELECT sc2.id FROM shift_captains sc2
         JOIN shifts s2 ON sc2.shiftId = s2.id
         WHERE sc2.captainId = u.id
           AND sc2.clockOutTime IS NULL
           AND (sc2.clockInTime IS NOT NULL OR s2.status IN ('scheduled', 'active'))
         ORDER BY (sc2.clockInTime IS NOT NULL) DESC, (DATE(s2.date) = CURDATE()) DESC, s2.date ASC
         LIMIT 1
       )
       LEFT JOIN shifts sh ON sh.id = sc.shiftId
       ${where}
       ORDER BY u.createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const activeUsers = req.app.get('activeUsers');
    const captains = rows.map((m) => {
      const isOnline = activeUsers ? activeUsers.has(String(m.id)) : false;
      const activeOrdersCount = parseInt(m.activeOrdersCount || 0, 10);
      const hasActiveShift = !!(m.shiftId && m.shiftName);
      const isClockedIn = !!m.clockInTime;
      const isOnBreak = !!(m.isOnBreak && m.breakEndTime && new Date(m.breakEndTime) > new Date());
      const breakRemainingMinutes = isOnBreak 
        ? Math.max(0, Math.ceil((new Date(m.breakEndTime) - new Date()) / 60000)) 
        : 0;

      const isBusy = activeOrdersCount >= 2;
      const canAssignNormal = activeOrdersCount < 2 && !isOnBreak;

      let statusLabel = 'متفرغ (0 طلبات)';
      if (isOnBreak) {
        statusLabel = `في استراحة ☕ (متبقي ${breakRemainingMinutes} د)`;
      } else if (activeOrdersCount === 1) {
        statusLabel = 'معه طلب واحد (متاح)';
      } else if (activeOrdersCount >= 2) {
        statusLabel = `مشغول (معه ${activeOrdersCount} طلبات - الحد الأقصى)`;
      }

      return {
        ...m,
        isOnline,
        activeOrdersCount,
        hasActiveShift,
        isClockedIn,
        shiftId: m.shiftId || null,
        shiftName: m.shiftName || null,
        isOnBreak,
        breakRemainingMinutes,
        breakDurationMinutes: m.breakDurationMinutes || 0,
        isBusy,
        canAssignNormal,
        statusLabel,
      };
    });

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
                COALESCE(s.latitude, m.latitude) as merchantLatitude, COALESCE(s.longitude, m.longitude) as merchantLongitude, 
                o.latitude as toLatitude, o.longitude as toLongitude,
                o.startLatitude, o.startLongitude, o.deliveryAddress as toAddress,
                COALESCE(NULLIF(s.address, ''), NULLIF(m.storeAddress, ''), NULLIF(m.detailedAddress, ''), NULLIF(s.city, ''), NULLIF(m.city, ''), 'مقر المتجر') as fromAddress,
                s.address as storeAddress,
                o.orderPrice as price,
                COALESCE(s.name, m.storeName) as merchantName, COALESCE(s.phone, m.phone) as merchantPhone
         FROM orders o
         LEFT JOIN users m ON o.merchantId = m.id
         LEFT JOIN stores s ON (o.storeId = s.id OR (o.storeId IS NULL AND s.merchantId = o.merchantId AND s.deletedAt IS NULL))
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
              COALESCE(s.latitude, m.latitude) as merchantLatitude, COALESCE(s.longitude, m.longitude) as merchantLongitude,
              o.latitude as toLatitude, o.longitude as toLongitude,
              o.startLatitude, o.startLongitude, o.deliveryAddress as toAddress,
              COALESCE(NULLIF(s.address, ''), NULLIF(m.storeAddress, ''), NULLIF(m.detailedAddress, ''), NULLIF(s.city, ''), NULLIF(m.city, ''), 'مقر المتجر') as fromAddress,
              s.address as storeAddress,
              o.orderPrice as price, o.createdAt,
              COALESCE(s.name, m.storeName) as merchantName, COALESCE(s.phone, m.phone) as merchantPhone
       FROM orders o
       LEFT JOIN users m ON o.merchantId = m.id
       LEFT JOIN stores s ON (o.storeId = s.id OR (o.storeId IS NULL AND s.merchantId = o.merchantId AND s.deletedAt IS NULL))
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

// CREATE NEW CAPTAIN (Admin)
const createCaptain = async (req, res, next) => {
  const pool = getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const {
      fullName,
      firstName,
      lastName,
      nationalId,
      phone,
      age,
      zone,
      branch,
      email,
      detailedAddress,
      district,
      whatsappNumber,
      vehicleType,
      plateNumber,
      password,
    } = req.body;
    const rawReferralCode = req.body.referredByCode || req.body.referralCode || req.body.referral_code || req.body.inviteCode;

    if (!phone || !phone.trim()) {
      return res.status(400).json({ status: 0, message: 'رقم الهاتف مطلوب' });
    }
    if (!nationalId || !nationalId.trim()) {
      return res.status(400).json({ status: 0, message: 'الرقم القومي مطلوب' });
    }

    // Split name if only fullName passed
    let fName = firstName;
    let lName = lastName;
    if (!fName && fullName) {
      const parts = fullName.trim().split(/\s+/);
      fName = parts[0] || '';
      lName = parts.slice(1).join(' ') || '';
    }
    if (!fName) {
      return res.status(400).json({ status: 0, message: 'اسم الكابتن بالكامل مطلوب' });
    }

    // Check if phone or nationalId already exists
    const [existing] = await conn.query(
      'SELECT id, phone, nationalId FROM users WHERE phone = ? OR nationalId = ? LIMIT 1',
      [phone.trim(), nationalId.trim()]
    );
    if (existing.length > 0) {
      if (existing[0].phone === phone.trim()) {
        return res.status(400).json({ status: 0, message: 'رقم الهاتف مسجل بالفعل مسبقاً' });
      }
      if (existing[0].nationalId === nationalId.trim()) {
        return res.status(400).json({ status: 0, message: 'الرقم القومي مسجل بالفعل مسبقاً' });
      }
    }

    // Hash password (use provided or default secure password)
    const rawPass = password && password.trim().length >= 6 ? password.trim() : `cap@${phone.trim().slice(-6)}`;
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(rawPass, salt);

    // File uploads
    let profileImage = null;
    let nationalIdFront = null;
    let nationalIdBack = null;
    let driverLicense = null;
    let vehicleImage = null;

    if (req.files) {
      if (req.files.profileImage && req.files.profileImage[0]) {
        profileImage = `/uploads/${req.files.profileImage[0].filename}`;
      }
      if (req.files.nationalIdFront && req.files.nationalIdFront[0]) {
        nationalIdFront = `/uploads/${req.files.nationalIdFront[0].filename}`;
      }
      if (req.files.nationalIdBack && req.files.nationalIdBack[0]) {
        nationalIdBack = `/uploads/${req.files.nationalIdBack[0].filename}`;
      }
      if (req.files.driverLicense && req.files.driverLicense[0]) {
        driverLicense = `/uploads/${req.files.driverLicense[0].filename}`;
      }
      if (req.files.vehicleImage && req.files.vehicleImage[0]) {
        vehicleImage = `/uploads/${req.files.vehicleImage[0].filename}`;
      }
    }

    const referralCode = `CAP-${Date.now().toString().slice(-6)}`;

    const [result] = await conn.query(
      `INSERT INTO users (
        firstName, lastName, email, phone, password, role, status,
        nationalId, age, zone, branch, detailedAddress, district,
        whatsappNumber, vehicleType, plateNumber, profileImage,
        nationalIdFront, nationalIdBack, driverLicense, vehicleImage,
        city, referralCode, walletBalance, points, rating, ratingCount,
        isOpen, createdAt, updatedAt
      ) VALUES (
        ?, ?, ?, ?, ?, 'captain', 'active',
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, 0.00, 0, 5.0, 0,
        1, NOW(), NOW()
      )`,
      [
        fName,
        lName || '',
        email && email.trim().length > 0 ? email.trim() : null,
        phone.trim(),
        hashedPassword,
        nationalId.trim(),
        age ? parseInt(age) : null,
        zone ? zone.trim() : null,
        branch ? branch.trim() : null,
        detailedAddress ? detailedAddress.trim() : null,
        district ? district.trim() : null,
        whatsappNumber ? whatsappNumber.trim() : null,
        vehicleType ? vehicleType.trim() : 'motorcycle',
        plateNumber ? plateNumber.trim() : null,
        profileImage,
        nationalIdFront,
        nationalIdBack,
        driverLicense,
        vehicleImage,
        district || zone || 'الإسكندرية',
        referralCode,
      ]
    );

    const newCaptainId = result.insertId;

    if (nationalIdFront || nationalIdBack || driverLicense || vehicleImage) {
      await conn.query(
        `INSERT INTO driver_documents (userId, nationalId, nationalIdFront, nationalIdBack, driverLicense, vehicleImage, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
         ON DUPLICATE KEY UPDATE
           nationalId = VALUES(nationalId),
           nationalIdFront = VALUES(nationalIdFront),
           nationalIdBack = VALUES(nationalIdBack),
           driverLicense = VALUES(driverLicense),
           vehicleImage = VALUES(vehicleImage),
           updatedAt = NOW()`,
        [newCaptainId, nationalId ? nationalId.trim() : null, nationalIdFront || null, nationalIdBack || null, driverLicense || null, vehicleImage || null]
      );
    }

    // Process referral reward if referral code / phone was provided
    let referrerId = null;
    if (rawReferralCode && rawReferralCode.toString().trim().length > 0) {
      const cleanCode = rawReferralCode.toString().trim();
      const [refRows] = await conn.query(
        'SELECT id, firstName, lastName, phone, fcmToken, walletBalance FROM users WHERE (LOWER(TRIM(referralCode)) = LOWER(?) OR phone = ?) AND phone != ?',
        [cleanCode, cleanCode, phone.trim()]
      );
      if (refRows.length > 0) {
        referrerId = refRows[0].id;
        await conn.query('UPDATE users SET referredBy = ? WHERE id = ?', [referrerId, newCaptainId]);
        await conn.query('UPDATE users SET walletBalance = COALESCE(walletBalance, 0) + 15.00, points = COALESCE(points, 0) + 15 WHERE id = ?', [referrerId]);
        const refTxCode = `REF-${Date.now()}-${referrerId}`;
        const refereeFullName = `${fName} ${lName}`.trim();
        try {
          await conn.query(
            `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference, category, paymentMethod) 
             VALUES (?, ?, 15.00, 'deposit', 'success', ?, 'referral', 'referral')`,
            [referrerId, `مكافأة دعوة كابتن جديد (${refereeFullName}) للتسجيل`, refTxCode]
          );
        } catch (txErr) {
          await conn.query(
            `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference, paymentMethod) 
             VALUES (?, ?, 15.00, 'deposit', 'success', ?, 'referral')`,
            [referrerId, `مكافأة دعوة كابتن جديد (${refereeFullName}) للتسجيل`, refTxCode]
          );
        }
        await conn.query(
          `INSERT INTO referrals (referrerId, refereeId, status, rewardAmount) 
           VALUES (?, ?, 'completed', 15.00)`,
          [referrerId, newCaptainId]
        );
      }
    }

    await conn.commit();

    // Trigger notifications for referrer after commit
    if (referrerId) {
      try {
        const { createDbNotification, sendPushNotification } = require('../utils/notificationHelper');
        const refereeFullName = `${fName} ${lName}`.trim();
        await createDbNotification(
          referrerId,
          'مكافأة دعوة صديق! 🎉',
          `لقد سجل الكابتن ${refereeFullName} باستخدام كود الدعوة الخاص بك وتم إضافة 15 ج.م إلى محفظتك بنجاح!`,
          'wallet'
        );
        const io = global.io;
        if (io) {
          const [wRows] = await pool.query('SELECT walletBalance FROM users WHERE id = ?', [referrerId]);
          const currentBal = wRows.length > 0 ? parseFloat(wRows[0].walletBalance) : 0;
          io.to(`user_${referrerId}`).emit('wallet_updated', {
            newBalance: currentBal,
            depositAmount: 15.00,
            message: `تم إضافة 15 ج.م إلى محفظتك بنجاح لدعوة ${refereeFullName} 🎉`,
          });
          io.to(`user_${referrerId}`).emit('notification', {
            title: 'مكافأة دعوة صديق! 🎉',
            message: `تم إضافة 15 ج.م إلى محفظتك بنجاح لتسجيل ${refereeFullName}!`,
            type: 'wallet'
          });
        }
        const [fcmRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [referrerId]);
        if (fcmRows.length > 0 && fcmRows[0].fcmToken) {
          sendPushNotification(
            fcmRows[0].fcmToken,
            'مكافأة دعوة صديق! 🎉',
            `تم إضافة 15 ج.م إلى محفظتك بنجاح لدعوة ${refereeFullName}!`,
            { type: 'wallet_deposit', amount: '15' }
          ).catch(err => console.error('Push error:', err));
        }
      } catch (err) {
        console.error('Error notifying referrer:', err);
      }
    }

    res.status(201).json({
      status: 1,
      message: 'تم إنشاء وتفعيل حساب الكابتن بنجاح',
      data: {
        id: newCaptainId,
        fullName: `${fName} ${lName}`.trim(),
        phone: phone.trim(),
        role: 'captain',
        status: 'active',
      },
    });
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
};

const COMPLETED_ORDER_STATUSES_SQL = "'Completed', 'منتهي', 'تم التنفيذ', 'Delivered', 'completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل'";
const COMPLETED_SHIPMENT_STATUSES_SQL = "'منتهية', 'Completed', 'تم التنفيذ', 'delivered', 'Delivered', 'completed', 'تم التوصيل', 'تم التسليم', 'مكتمل'";

const getCairoDateStr = (dateVal = new Date()) => {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(new Date(dateVal));
  } catch (_) {
    return new Date(dateVal).toISOString().slice(0, 10);
  }
};

const isOnlineMethod = (method) => {
  if (!method) return false;
  const m = String(method).trim().toLowerCase();
  return ['online', 'kashier', 'card', 'wallet', 'محفظة', 'فيزا'].includes(m);
};

// Helper to resolve platform and captain share dynamically (supports percentage or fixed amount like 5/6 EGP)
const resolveShares = (fee, rawPlat, rawCap) => {
  const totalFee = parseFloat(fee || 0);
  const hasPlat = (rawPlat !== null && rawPlat !== undefined && !isNaN(parseFloat(rawPlat)));
  const hasCap = (rawCap !== null && rawCap !== undefined && !isNaN(parseFloat(rawCap)) && parseFloat(rawCap) > 0);

  if (hasPlat && hasCap) {
    return { platShare: parseFloat(rawPlat), capShare: parseFloat(rawCap) };
  }
  if (hasPlat && !hasCap) {
    const plat = parseFloat(rawPlat);
    return { platShare: plat, capShare: Math.max(0, totalFee - plat) };
  }
  if (!hasPlat && hasCap) {
    const cap = parseFloat(rawCap);
    return { platShare: Math.max(0, totalFee - cap), capShare: cap };
  }
  const defaultPlat = Math.round(totalFee * 0.20 * 100) / 100;
  return { platShare: defaultPlat, capShare: Math.max(0, totalFee - defaultPlat) };
};

const getCaptainFinancials = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const targetDate = req.query.date || getCairoDateStr();

    const [users] = await pool.query(
      'SELECT id, firstName, lastName, phone, walletBalance FROM users WHERE id = ? AND role = "captain"',
      [id]
    );
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    }
    const captain = users[0];

    // 1. Unsettled Orders (including store orders)
    const [orders] = await pool.query(
      `SELECT id, orderNumber, deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip, status, storeOrderStatus, captainTripStatus, createdAt, deliveredAt
       FROM orders
       WHERE captainId = ? AND (
         status IN (${COMPLETED_ORDER_STATUSES_SQL}) 
         OR storeOrderStatus = 'COMPLETED' 
         OR captainTripStatus = 'DELIVERED_SUCCESSFULLY'
       ) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)
       ORDER BY createdAt DESC`,
      [id]
    );

    // 2. Unsettled Shipments
    const [shipments] = await pool.query(
      `SELECT id, shipmentNumber, price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip, status, createdAt
       FROM shipments
       WHERE captainId = ? AND status IN (${COMPLETED_SHIPMENT_STATUSES_SQL}) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)
       ORDER BY createdAt DESC`,
      [id]
    );

    // Helper to calculate financial aggregates
    const calculateMetrics = (orderList, shipmentList) => {
      let grossDeliveryFees = 0;
      let platformCommission = 0;
      let captainEarnings = 0;
      let cashCollected = 0;
      let onlineCollected = 0;
      let platformDues = 0;
      let captainDues = 0;
      let cashDeliveriesCount = 0;
      let onlineDeliveriesCount = 0;

      for (const ord of orderList) {
        const fee = parseFloat(ord.deliveryFee || 0);
        const serviceFee = parseFloat(ord.serviceFee || 0);
        const tip = parseFloat(ord.tip || 0);
        const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);

        grossDeliveryFees += fee;
        platformCommission += platShare;
        captainEarnings += capShare;

        if (isOnlineMethod(ord.paymentMethod)) {
          onlineCollected += fee;
          captainDues += capShare;
          onlineDeliveriesCount++;
        } else {
          cashCollected += (fee + serviceFee + tip);
          platformDues += (platShare + serviceFee + tip);
          cashDeliveriesCount++;
        }
      }

      for (const shp of shipmentList) {
        const price = parseFloat(shp.price || 0);
        const serviceFee = parseFloat(shp.serviceFee || 0);
        const tip = parseFloat(shp.tip || 0);
        const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);

        grossDeliveryFees += price;
        platformCommission += platShare;
        captainEarnings += capShare;

        if (isOnlineMethod(shp.paymentMethod)) {
          onlineCollected += price;
          captainDues += capShare;
          onlineDeliveriesCount++;
        } else {
          cashCollected += (price + serviceFee + tip);
          platformDues += (platShare + serviceFee + tip);
          cashDeliveriesCount++;
        }
      }

      grossDeliveryFees = Math.round(grossDeliveryFees * 100) / 100;
      platformCommission = Math.round(platformCommission * 100) / 100;
      captainEarnings = Math.round(captainEarnings * 100) / 100;
      cashCollected = Math.round(cashCollected * 100) / 100;
      onlineCollected = Math.round(onlineCollected * 100) / 100;
      platformDues = Math.round(platformDues * 100) / 100;
      captainDues = Math.round(captainDues * 100) / 100;
      const netBalance = Math.round((platformDues - captainDues) * 100) / 100;

      return {
        ordersCount: orderList.length,
        shipmentsCount: shipmentList.length,
        totalDeliveries: orderList.length + shipmentList.length,
        cashDeliveriesCount,
        onlineDeliveriesCount,
        grossDeliveryFees,
        platformCommission,
        captainEarnings,
        cashCollected,
        onlineCollected,
        platformDues,
        captainDues,
        netBalance,
      };
    };

    // Filter today's / target date items for Daily Settlement
    const isTargetDate = (item) => {
      const dateVal = item.deliveredAt || item.createdAt;
      if (!dateVal) return false;
      const dStr = getCairoDateStr(dateVal);
      return dStr === targetDate;
    };

    const dailyOrders = orders.filter(isTargetDate);
    const dailyShipments = shipments.filter(isTargetDate);

    const unsettledStats = calculateMetrics(orders, shipments);
    const dailyStats = calculateMetrics(dailyOrders, dailyShipments);

    // 3. Past settlements
    const [settlements] = await pool.query(
      `SELECT cs.*, u.firstName as adminFirstName, u.lastName as adminLastName
       FROM captain_settlements cs
       LEFT JOIN users u ON cs.createdBy = u.id
       WHERE cs.captainId = ?
       ORDER BY cs.createdAt DESC
       LIMIT 50`,
      [id]
    );

    const formattedSettlements = settlements.map((s) => ({
      ...s,
      grossDeliveryFees: parseFloat(s.grossDeliveryFees || 0),
      platformCommission: parseFloat(s.platformCommission || 0),
      captainEarnings: parseFloat(s.captainEarnings || 0),
      cashCollected: parseFloat(s.cashCollected || 0),
      onlineCollected: parseFloat(s.onlineCollected || 0),
      platformDues: parseFloat(s.platformDues || 0),
      captainDues: parseFloat(s.captainDues || 0),
      netBalance: parseFloat(s.netBalance || 0),
      settledAmount: parseFloat(s.settledAmount || 0),
      settlementScope: s.settlementScope || 'total',
      settlementDate: s.settlementDate ? new Date(s.settlementDate).toISOString().slice(0, 10) : null,
      createdByName: `${s.adminFirstName || ''} ${s.adminLastName || ''}`.trim() || 'الإدارة',
    }));

    res.status(200).json({
      status: 1,
      data: {
        commissionRate: 20.0,
        targetDate,
        dailyStats,
        unsettledStats,
        walletBalance: parseFloat(captain.walletBalance || 0),
        settlementsHistory: formattedSettlements,
      },
    });
  } catch (error) {
    next(error);
  }
};

const settleCaptainFinancials = async (req, res, next) => {
  const pool = getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const { id } = req.params;
    const {
      settlementMethod = 'cash',
      notes = '',
      scope = 'total', // 'daily' or 'total'
      targetDate = getCairoDateStr(),
    } = req.body;

    const [users] = await conn.query(
      'SELECT id, firstName, lastName, phone FROM users WHERE id = ? AND role = "captain"',
      [id]
    );
    if (users.length === 0) {
      await conn.rollback();
      return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    }

    // Lock eligible completed unsettled orders
    const [allOrders] = await conn.query(
      `SELECT id, deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip, createdAt, deliveredAt
       FROM orders
       WHERE captainId = ? AND (
         status IN (${COMPLETED_ORDER_STATUSES_SQL}) 
         OR storeOrderStatus = 'COMPLETED' 
         OR captainTripStatus = 'DELIVERED_SUCCESSFULLY'
       ) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)
       FOR UPDATE`,
      [id]
    );

    // Lock eligible completed unsettled shipments
    const [allShipments] = await conn.query(
      `SELECT id, price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip, createdAt
       FROM shipments
       WHERE captainId = ? AND status IN (${COMPLETED_SHIPMENT_STATUSES_SQL}) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)
       FOR UPDATE`,
      [id]
    );

    // Filter by scope if daily
    const isTargetDate = (item) => {
      const dateVal = item.deliveredAt || item.createdAt;
      if (!dateVal) return false;
      const dStr = getCairoDateStr(dateVal);
      return dStr === targetDate;
    };

    const orders = scope === 'daily' ? allOrders.filter(isTargetDate) : allOrders;
    const shipments = scope === 'daily' ? allShipments.filter(isTargetDate) : allShipments;

    if (orders.length === 0 && shipments.length === 0) {
      await conn.rollback();
      return res.status(400).json({
        status: 0,
        message: scope === 'daily'
          ? `لا توجد عمليات توصيل مؤهلة للتصفية بتاريخ ${targetDate} أو تم تصفيتها مسبقاً`
          : 'لا توجد عمليات توصيل مؤهلة للتصفية أو تم تصفية جميع العمليات مسبقاً',
      });
    }

    let grossDeliveryFees = 0;
    let platformCommission = 0;
    let captainEarnings = 0;
    let cashCollected = 0;
    let onlineCollected = 0;
    let platformDues = 0;
    let captainDues = 0;
    const orderIds = [];
    const shipmentIds = [];
    let minDate = null;
    let maxDate = null;

    const updateDates = (d) => {
      if (!d) return;
      const date = new Date(d);
      if (!minDate || date < new Date(minDate)) minDate = d;
      if (!maxDate || date > new Date(maxDate)) maxDate = d;
    };

    for (const ord of orders) {
      orderIds.push(ord.id);
      updateDates(ord.deliveredAt || ord.createdAt);
      const fee = parseFloat(ord.deliveryFee || 0);
      const serviceFee = parseFloat(ord.serviceFee || 0);
      const tip = parseFloat(ord.tip || 0);
      const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);

      grossDeliveryFees += fee;
      platformCommission += platShare;
      captainEarnings += capShare;

      if (isOnlineMethod(ord.paymentMethod)) {
        onlineCollected += fee;
        captainDues += capShare;
      } else {
        cashCollected += (fee + serviceFee + tip);
        platformDues += (platShare + serviceFee + tip);
      }
    }

    for (const shp of shipments) {
      shipmentIds.push(shp.id);
      updateDates(shp.createdAt);
      const price = parseFloat(shp.price || 0);
      const serviceFee = parseFloat(shp.serviceFee || 0);
      const tip = parseFloat(shp.tip || 0);
      const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);

      grossDeliveryFees += price;
      platformCommission += platShare;
      captainEarnings += capShare;

      if (isOnlineMethod(shp.paymentMethod)) {
        onlineCollected += price;
        captainDues += capShare;
      } else {
        cashCollected += (price + serviceFee + tip);
        platformDues += (platShare + serviceFee + tip);
      }
    }

    grossDeliveryFees = Math.round(grossDeliveryFees * 100) / 100;
    platformCommission = Math.round(platformCommission * 100) / 100;
    captainEarnings = Math.round(captainEarnings * 100) / 100;
    cashCollected = Math.round(cashCollected * 100) / 100;
    onlineCollected = Math.round(onlineCollected * 100) / 100;
    platformDues = Math.round(platformDues * 100) / 100;
    captainDues = Math.round(captainDues * 100) / 100;

    const netBalance = Math.round((platformDues - captainDues) * 100) / 100;
    const settledAmount = Math.abs(netBalance);

    let settlementType = 'zero_balance';
    if (netBalance > 0) {
      settlementType = 'collection_from_captain';
    } else if (netBalance < 0) {
      settlementType = 'payout_to_captain';
    }

    const scopePrefix = scope === 'daily' ? 'DAY' : 'TOT';
    const settlementNumber = `CPT-${scopePrefix}-${Date.now().toString().slice(-6)}${Math.floor(10 + Math.random() * 90)}`;

    const [settleRes] = await conn.query(
      `INSERT INTO captain_settlements (
        settlementNumber, captainId, periodStart, periodEnd,
        totalOrders, totalShipments, grossDeliveryFees, platformCommission,
        captainEarnings, cashCollected, onlineCollected, platformDues,
        captainDues, netBalance, settledAmount, settlementType, settlementScope, settlementDate, paymentMethod,
        status, notes, createdBy
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?)`,
      [
        settlementNumber,
        id,
        minDate || new Date(),
        maxDate || new Date(),
        orderIds.length,
        shipmentIds.length,
        grossDeliveryFees.toFixed(2),
        platformCommission.toFixed(2),
        captainEarnings.toFixed(2),
        cashCollected.toFixed(2),
        onlineCollected.toFixed(2),
        platformDues.toFixed(2),
        captainDues.toFixed(2),
        netBalance.toFixed(2),
        settledAmount.toFixed(2),
        settlementType,
        scope,
        scope === 'daily' ? targetDate : null,
        settlementMethod,
        notes || null,
        req.user.id,
      ]
    );

    const settlementId = settleRes.insertId;

    if (orderIds.length > 0) {
      await conn.query(
        'UPDATE orders SET isCaptainSettled = 1, captainSettlementId = ? WHERE id IN (?)',
        [settlementId, orderIds]
      );
    }

    if (shipmentIds.length > 0) {
      await conn.query(
        'UPDATE shipments SET isCaptainSettled = 1, captainSettlementId = ? WHERE id IN (?)',
        [settlementId, shipmentIds]
      );
    }

    await conn.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference, paymentMethod, accountDetails)
       VALUES (?, ?, ?, ?, 'success', ?, ?, ?)`,
      [
        id,
        scope === 'daily'
          ? `تسوية يومية رقم ${settlementNumber} (${targetDate})`
          : `تسوية كلية رقم ${settlementNumber}`,
        settledAmount,
        settlementType === 'collection_from_captain' ? 'withdraw' : 'deposit',
        settlementNumber,
        settlementMethod,
        notes || (scope === 'daily' ? `تسوية يومية ${targetDate}` : 'تسوية كلية شاملة'),
      ]
    );

    if (typeof logAudit === 'function') {
      try {
        await logAudit({
          actorId: req.user.id,
          actorRole: req.user.role,
          action: 'captain_settlement',
          entityType: 'captain_settlement',
          entityId: settlementId,
          newValue: {
            settlementNumber,
            captainId: id,
            settlementScope: scope,
            settlementDate: scope === 'daily' ? targetDate : null,
            ordersCount: orderIds.length,
            shipmentsCount: shipmentIds.length,
            grossDeliveryFees,
            platformCommission,
            captainEarnings,
            platformDues,
            captainDues,
            netBalance,
            settlementType,
            settledAmount,
          },
          ipAddress: req.ip,
        });
      } catch (auditErr) {
        console.error('Error logging audit for captain settlement:', auditErr);
      }
    }

    await conn.commit();

    const io = req.app?.get('io') || global.io;
    if (io) {
      io.emit('captain:settlement', {
        captainId: id,
        settlementNumber,
        settlementScope: scope,
        settledAmount,
        settlementType,
      });
    }

    res.status(200).json({
      status: 1,
      message: scope === 'daily'
        ? `تمت التسوية اليومية للكابتن بنجاح بتاريخ ${targetDate}`
        : 'تمت التسوية الكلية الشاملة للكابتن بنجاح',
      data: {
        settlementId,
        settlementNumber,
        settlementScope: scope,
        settlementDate: scope === 'daily' ? targetDate : null,
        settledOrders: orderIds.length,
        settledShipments: shipmentIds.length,
        settledAmount,
        settlementType,
        netBalance,
        periodStart: minDate,
        periodEnd: maxDate,
      },
    });
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
};

// 10. UPDATE STORE ORDER TRIP STATUS (Captain Mapless Flow)
const updateStoreOrderTripStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const captainId = req.user.id;
    const { id } = req.params;
    const { tripStatus, reason } = req.body;

    if (!tripStatus) {
      return res.status(400).json({ status: 0, message: 'حالة رحلة الكابتن مطلوبة' });
    }

    const {
      STORE_ORDER_STATUS,
      CAPTAIN_TRIP_STATUS,
      canTransitionCaptainTrip,
      mapStoreToLegacyStatus,
      getArabicStoreStatus,
    } = require('../constants/orderStatusConstants');

    // Normalize tripStatus
    let targetTripStatus = null;
    const sNorm = tripStatus.toString().trim().toUpperCase();

    if (['HEADING_TO_STORE', 'متجه للمتجر', 'في الطريق للاستلام'].includes(sNorm)) {
      targetTripStatus = CAPTAIN_TRIP_STATUS.HEADING_TO_STORE;
    } else if (['ORDER_PICKED_UP', 'PICKED_UP', 'تم استلام الطلب', 'تم الاستلام'].includes(sNorm)) {
      targetTripStatus = CAPTAIN_TRIP_STATUS.ORDER_PICKED_UP;
    } else if (['HEADING_TO_CLIENT', 'متجه للعميل', 'في الطريق للتسليم'].includes(sNorm)) {
      targetTripStatus = CAPTAIN_TRIP_STATUS.HEADING_TO_CLIENT;
    } else if (['DELIVERED_SUCCESSFULLY', 'DELIVERED', 'COMPLETED', 'توصيل ناجح', 'تم التوصيل', 'تم التسليم'].includes(sNorm)) {
      targetTripStatus = CAPTAIN_TRIP_STATUS.DELIVERED_SUCCESSFULLY;
    } else if (['CANCELLED', 'ملغي', 'ملغى'].includes(sNorm)) {
      targetTripStatus = CAPTAIN_TRIP_STATUS.CANCELLED;
    }

    if (!targetTripStatus) {
      return res.status(400).json({ status: 0, message: `حالة رحلة غير صالحة: ${tripStatus}` });
    }

    const [orderRows] = await pool.query(
      `SELECT o.*, 
              m.storeName as merchantStoreName, m.firstName as merchantFirstName, m.lastName as merchantLastName,
              c.firstName as clientFirstName, c.lastName as clientLastName, c.phone as clientPhone
       FROM orders o
       LEFT JOIN users m ON o.merchantId = m.id
       LEFT JOIN users c ON o.clientId = c.id
       WHERE o.id = ?`,
      [id]
    );

    if (!orderRows.length) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    const order = orderRows[0];
    const isStoreOrder = order.orderType === 'store' || order.storeId !== null;

    // Authorization: User must be the assigned captain or an admin
    if (req.user.role !== 'admin' && order.captainId !== captainId) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتحديث رحلة هذا الطلب' });
    }

    const currentTripStatus = order.captainTripStatus || CAPTAIN_TRIP_STATUS.ASSIGNED;

    // For store orders, we only have 2 simplified captain steps: ORDER_PICKED_UP and DELIVERED_SUCCESSFULLY
    // Transition validation
    if (!canTransitionCaptainTrip(currentTripStatus, targetTripStatus)) {
      return res.status(400).json({
        status: 0,
        message: `انتقال غير مسموح به في رحلة الكابتن من "${currentTripStatus}" إلى "${targetTripStatus}"`
      });
    }

    // Determine updates to storeOrderStatus and timestamps
    let updatedStoreOrderStatus = order.storeOrderStatus || STORE_ORDER_STATUS.PREPARING;
    let timestampClause = '';
    const updateParams = [targetTripStatus];

    if (targetTripStatus === CAPTAIN_TRIP_STATUS.HEADING_TO_STORE) {
      timestampClause += ', captainHeadingToStoreAt = COALESCE(captainHeadingToStoreAt, NOW())';
    } else if (targetTripStatus === CAPTAIN_TRIP_STATUS.ORDER_PICKED_UP) {
      timestampClause += ', pickedUpAt = COALESCE(pickedUpAt, NOW()), handedOverAt = COALESCE(handedOverAt, NOW())';
      updatedStoreOrderStatus = isStoreOrder ? STORE_ORDER_STATUS.PICKED_UP : STORE_ORDER_STATUS.HANDED_OVER;
    } else if (targetTripStatus === CAPTAIN_TRIP_STATUS.HEADING_TO_CLIENT) {
      timestampClause += ', captainHeadingToClientAt = COALESCE(captainHeadingToClientAt, NOW())';
    } else if (targetTripStatus === CAPTAIN_TRIP_STATUS.DELIVERED_SUCCESSFULLY) {
      timestampClause += ', deliveredAt = COALESCE(deliveredAt, NOW()), completedAt = COALESCE(completedAt, NOW())';
      updatedStoreOrderStatus = STORE_ORDER_STATUS.COMPLETED;
    } else if (targetTripStatus === CAPTAIN_TRIP_STATUS.CANCELLED) {
      timestampClause += ', cancellationReason = ?';
      updateParams.push(reason || 'إلغاء الرحلة من قبل الكابتن');
    }

    const legacyStatus = isStoreOrder
      ? getArabicStoreStatus(updatedStoreOrderStatus)
      : mapStoreToLegacyStatus(updatedStoreOrderStatus, targetTripStatus);

    updateParams.push(updatedStoreOrderStatus, legacyStatus, id);

    await pool.query(
      `UPDATE orders SET 
        captainTripStatus = ?,
        storeOrderStatus = ?,
        status = ?
        ${timestampClause}
       WHERE id = ?`,
      updateParams
    );

    const storeName = order.merchantStoreName || `${order.merchantFirstName || ''} ${order.merchantLastName || ''}`.trim() || 'المتجر';
    const orderNumber = order.orderNumber;

    // Real-time socket updates
    const io = req.app.get('io');
    if (io) {
      const payload = {
        orderId: id,
        id: id,
        orderNumber,
        captainTripStatus: targetTripStatus,
        storeOrderStatus: updatedStoreOrderStatus,
        status: legacyStatus,
        statusArabic: legacyStatus,
        captainId: order.captainId,
        isStoreOrder: true
      };

      io.to(`order_${id}`).emit('trip_status_update', payload);
      io.to(`order_${id}`).emit('statusUpdate', payload);
      io.to(`order_${id}`).emit('store_order_status_update', payload);
      io.to('admins').emit('dashboard_update');
      io.to('admins').emit('store_order_status_update', payload);

      if (order.merchantId) {
        io.to(`user_${order.merchantId}`).emit('trip_status_update', payload);
        io.to(`user_${order.merchantId}`).emit('order_status_update', payload);
        io.to(`user_${order.merchantId}`).emit('store_order_status_update', payload);
      }
      if (order.clientId) {
        io.to(`user_${order.clientId}`).emit('order_status_update', payload);
        io.to(`user_${order.clientId}`).emit('store_order_status_update', payload);
      }
    }

    // Push notifications
    try {
      const { sendNotification } = require('../utils/notificationDispatcher');
      const { notifyAdmins } = require('../utils/adminNotifier');

      if (targetTripStatus === CAPTAIN_TRIP_STATUS.ORDER_PICKED_UP) {
        if (order.clientId) {
          await sendNotification(io, order.clientId, '🛵 المندوب استلم طلبك', `المندوب استلم طلبك رقم #${orderNumber} وهو في الطريق إليك.`, 'order', {
            type: 'order_picked_up',
            orderId: id.toString(),
            orderNumber,
            storeOrderStatus: STORE_ORDER_STATUS.PICKED_UP
          });
        }
        if (order.merchantId) {
          await sendNotification(io, order.merchantId, '📦 تم استلام الطلب', `تم استلام الطلب #${orderNumber} من المندوب بنجاح.`, 'order', {
            type: 'order_picked_up',
            orderId: id.toString(),
            orderNumber,
            storeOrderStatus: STORE_ORDER_STATUS.PICKED_UP
          });
        }
        if (io) {
          await notifyAdmins(io, 'المندوب استلم الطلب', `المندوب استلم الطلب #${orderNumber} من متجر ${storeName}`, 'order', {
            type: 'order_picked_up',
            orderId: id.toString(),
            orderNumber
          });
        }
      } else if (targetTripStatus === CAPTAIN_TRIP_STATUS.DELIVERED_SUCCESSFULLY) {
        if (order.clientId) {
          await sendNotification(io, order.clientId, '🎉 تم تسليم طلبك', `تم تسليم طلبك #${orderNumber} بنجاح. شكراً لثقتك بنا!`, 'order', {
            type: 'order_delivered',
            orderId: id.toString(),
            orderNumber,
            storeOrderStatus: STORE_ORDER_STATUS.DELIVERED
          });
        }
        if (order.merchantId) {
          await sendNotification(io, order.merchantId, '✅ تم تسليم الطلب للعميل', `تم تسليم الطلب #${orderNumber} للعميل بنجاح.`, 'order', {
            type: 'order_delivered',
            orderId: id.toString(),
            orderNumber,
            storeOrderStatus: STORE_ORDER_STATUS.DELIVERED
          });
        }
        if (io) {
          await notifyAdmins(io, 'تم تسليم الطلب بنجاح', `تم تسليم الطلب #${orderNumber} بنجاح للعميل`, 'order', {
            type: 'order_delivered',
            orderId: id.toString(),
            orderNumber
          });
        }
      }
    } catch (e) {
      console.error('Error sending notifications in updateStoreOrderTripStatus:', e);
    }

    return res.json({
      status: 1,
      message: 'تم تحديث حالة رحلة الكابتن بنجاح',
      data: {
        orderId: parseInt(id),
        captainTripStatus: targetTripStatus,
        storeOrderStatus: updatedStoreOrderStatus,
        status: legacyStatus
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
  uploadCaptainDocuments,
  createCaptain,
  getCaptainFinancials,
  settleCaptainFinancials,
  updateStoreOrderTripStatus,
};
