const { getPool } = require('../config/db');
const { assertOrderAccess } = require('../utils/accessControl');
const { assertOrderStatusTransition } = require('../utils/statusTransitions');
const { sendNotification } = require('../utils/notificationDispatcher');
const { checkAndRewardReferral } = require('../utils/referralHelper');
const { logStatusChange, getStatusLogs } = require('../utils/statusLogger');

const formatDate = (date) => {
  if (!date) return null;
  return new Date(date).toISOString();
};

async function fetchOrderEventData(id) {
  const pool = getPool();
  const [rows] = await pool.query(`
    SELECT o.*,
      m.storeName as merchantName,
      m.firstName as merchantFirstName,
      m.lastName as merchantLastName,
      a.firstName as assignedAdminFirstName,
      a.lastName as assignedAdminLastName
    FROM orders o
    LEFT JOIN users m ON o.merchantId = m.id
    LEFT JOIN users a ON o.assignedAdminId = a.id
    WHERE o.id = ?
  `, [id]);
  if (rows.length === 0) return null;
  const o = rows[0];
  return {
    id: o.id.toString(),
    orderNumber: o.orderNumber,
    merchantId: o.merchantId ? o.merchantId.toString() : null,
    captainId: o.captainId ? o.captainId.toString() : null,
    tripId: o.trip_id ? o.trip_id.toString() : null,
    details: o.details,
    storeDescription: o.storeDescription,
    notes: o.notes || '',
    deliveryAddress: o.deliveryAddress,
    clientName: o.clientName,
    phone: o.phone,
    orderPrice: parseFloat(o.orderPrice || 0),
    deliveryFee: parseFloat(o.deliveryFee || 0),
    merchantName: o.merchantName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : ''),
    status: o.status,
    assignedAdminId: o.assignedAdminId ? o.assignedAdminId.toString() : null,
    assignedAdminName: o.assignedAdminFirstName ? `${o.assignedAdminFirstName} ${o.assignedAdminLastName}`.trim() : null,
    isPaid: o.isPaid === 1 || o.isPaid === true,
    createdAt: formatDate(o.createdAt),
    updatedAt: formatDate(o.updatedAt),
  };
}

// 1. CREATE ORDER (Merchant only)
const createOrder = async (req, res, next) => {
  try {
    const pool = getPool();
    const merchantId = req.user.id;

    const {
      details,
      storeDescription,
      notes,
      deliveryAddress,
      clientName,
      phone,
      orderPrice,
      deliveryFee,
      latitude,
      longitude,
      tripId,
      couponCode
    } = req.body;

    if (!details || !storeDescription || !deliveryAddress || !clientName || !phone || orderPrice === undefined || deliveryFee === undefined) {
      return res.status(400).json({
        status: 0,
        message: 'الحقول الأساسية مطلوبة: التفاصيل، وصف المتجر، عنوان التسليم، اسم العميل، الهاتف، سعر الطلب، ورسوم التوصيل'
      });
    }

    const orderNumber = 'ORD' + Date.now().toString().substring(5) + Math.floor(100 + Math.random() * 900);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Check if auto-assignment is enabled
      const [autoSettings] = await conn.query(
        "SELECT `value` FROM app_settings WHERE `key` = 'enable_auto_assignment'"
      );
      const isAutoEnabled = autoSettings.length > 0 && autoSettings[0].value === '1';

      // 1. Calculate price and coupon (deducted from deliveryFee)
      let finalDeliveryFee = parseFloat(deliveryFee);
      let discountApplied = 0.00;
      let appliedCouponCode = null;

      if (couponCode && couponCode.trim().length > 0) {
        const { processCoupon } = require('../utils/couponHelper');
        try {
          const couponResult = await processCoupon(conn, {
            code: couponCode,
            price: finalDeliveryFee,
            userId: merchantId,
            isShipment: false,
            entityId: null
          });
          discountApplied = couponResult.discountApplied;
          appliedCouponCode = couponResult.couponCode;
          finalDeliveryFee = Math.max(finalDeliveryFee - discountApplied, 0.00);
        } catch (couponErr) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: couponErr.message });
        }
      }

      const statusVal = isAutoEnabled ? 'Ready For Assignment' : 'Pending Review';
      const platformShare = isAutoEnabled ? finalDeliveryFee * 0.20 : null;
      const captainShare = isAutoEnabled ? finalDeliveryFee * 0.80 : null;

      const [result] = await conn.query(
        `INSERT INTO orders (
          orderNumber, merchantId, details, storeDescription, notes, 
          deliveryAddress, clientName, phone, orderPrice, deliveryFee, 
          latitude, longitude, trip_id, status,
          platformShare, captainShare, autoAssignmentFailed, couponCode, discountApplied
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
        [
          orderNumber,
          merchantId,
          details,
          storeDescription,
          notes || null,
          deliveryAddress,
          clientName,
          phone,
          parseFloat(orderPrice),
          finalDeliveryFee,
          latitude ? parseFloat(latitude) : null,
          longitude ? parseFloat(longitude) : null,
          tripId ? parseInt(tripId) : null,
          statusVal,
          platformShare,
          captainShare,
          appliedCouponCode,
          discountApplied
        ]
      );

      const orderId = result.insertId;

      await logStatusChange(conn, {
        orderId,
        userId: merchantId,
        userName: 'التاجر',
        userRole: 'merchant',
        previousStatus: null,
        newStatus: statusVal,
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null
      });

      // Update coupon_usages table with actual orderId
      if (appliedCouponCode) {
        await conn.query(
          "UPDATE coupon_usages SET orderId = ? WHERE userId = ? AND shipmentId IS NULL AND orderId IS NULL ORDER BY usedAt DESC LIMIT 1",
          [orderId, merchantId]
        );
      }

      await conn.commit();

      // Notify admins about new order
      try {
        const { notifyAdmins } = require('../utils/adminNotifier');
        const io = req.app.get('io');
        const [merchant] = await pool.query('SELECT storeName, firstName, lastName FROM users WHERE id = ?', [merchantId]);
        const m = merchant[0] || {};
        const senderName = m.storeName || `${m.firstName || ''} ${m.lastName || ''}`.trim() || 'تاجر';
        notifyAdmins(io, '📦 طلب جديد', `طلب جديد #${orderNumber} من ${senderName}`, 'order_new', {
          type: 'order_new', orderId: orderId.toString(), orderNumber
        });
      } catch (_) { }

      // Emit real-time event with full order data
      try {
        const io = req.app.get('io');
        const eventData = await fetchOrderEventData(orderId);
        if (eventData && io) {
          io.to('admins').emit('order_created', eventData);
        }
      } catch (_) {}

      // Trigger auto assignment immediately if enabled
      if (isAutoEnabled) {
        try {
          const { triggerAutoAssignment } = require('../utils/autoAssignment');
          triggerAutoAssignment(null, orderId).catch(err => 
            console.error('Error triggering auto assignment on order creation:', err)
          );
        } catch (err) {
          console.error('Error importing or calling triggerAutoAssignment:', err);
        }
      }

      res.status(201).json({
        status: 1,
        message: 'تم إضافة الطلب بنجاح',
        data: {
          id: orderId.toString(),
          orderNumber,
          merchantId: merchantId.toString(),
          captainId: null,
          tripId: tripId ? tripId.toString() : null,
          details,
          storeDescription,
          notes: notes || '',
          deliveryAddress,
          clientName,
          phone,
          orderPrice: parseFloat(orderPrice),
          deliveryFee: finalDeliveryFee,
          discountApplied,
          couponCode: appliedCouponCode,
          latitude: latitude ? parseFloat(latitude) : null,
          longitude: longitude ? parseFloat(longitude) : null,
          status: statusVal,
          isPaid: false,
          createdAt: new Date().toISOString()
        }
      });
    } catch (error) {
      await conn.rollback();
      throw error;
    } finally {
      conn.release();
    }
  } catch (error) {
    next(error);
  }
};

// 2. GET ALL ORDERS
const getOrders = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const role = req.user.role;
    const { status, filter, query } = req.query;

    let sql = `
      SELECT o.*, 
             m.firstName as merchantFirstName, m.lastName as merchantLastName, m.storeName as merchantStoreName,
             m.profileImage as merchantProfileImage, m.phone as merchantPhone, m.address as merchantAddress,
             m.latitude as merchantLatitude, m.longitude as merchantLongitude,
             c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone,
             c.latitude as captainLatitude, c.longitude as captainLongitude,
             a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
             COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = o.captainId), 1), 0.0) as captainAvgRating,
             (SELECT COUNT(*) FROM reviews WHERE revieweeId = o.captainId) as captainReviewCount,
             EXISTS(SELECT 1 FROM reviews WHERE reviews.orderId = o.id AND reviews.reviewerId = ?) as hasReviewed
      FROM orders o
      LEFT JOIN users m ON o.merchantId = m.id
      LEFT JOIN users c ON o.captainId = c.id
      LEFT JOIN users a ON o.assignedAdminId = a.id
      WHERE 1=1
    `;
    const params = [userId];

    if (role === 'merchant') {
      sql += ' AND o.merchantId = ?';
      params.push(userId);
    } else if (role === 'captain') {
      // Captains only see orders explicitly assigned to them and approved/ready/awaiting payment
      sql += " AND o.captainId = ? AND o.status NOT IN ('Pending Review', 'Ready For Assignment')";
      params.push(userId);
    }

    if (status && status !== 'الكل') {
      sql += ' AND o.status = ?';
      params.push(status);
    }

    if (query) {
      sql += ' AND (o.orderNumber LIKE ? OR o.details LIKE ? OR o.clientName LIKE ?)';
      params.push(`%${query}%`, `%${query}%`, `%${query}%`);
    }

    const { captainId, tripId } = req.query;
    if (captainId) {
      sql += ' AND o.captainId = ?';
      params.push(captainId);
    }
    if (tripId) {
      sql += ' AND o.trip_id = ?';
      params.push(tripId);
    }

    sql += ' ORDER BY o.createdAt DESC';

    const [orders] = await pool.query(sql, params);

    const formattedOrders = orders.map((o) => ({
      id: o.id.toString(),
      orderNumber: o.orderNumber,
      merchantId: o.merchantId ? o.merchantId.toString() : null,
      captainId: o.captainId ? o.captainId.toString() : null,
      hasReviewed: o.hasReviewed === 1 || o.hasReviewed === true,
      tripId: o.trip_id ? o.trip_id.toString() : null,
      details: o.details,
      storeDescription: o.storeDescription,
      merchantAddress: o.merchantAddress || o.merchantStoreName || o.storeDescription || '',
      fromAddress: o.merchantAddress || o.merchantStoreName || o.storeDescription || '',
      notes: o.notes || '',
      deliveryAddress: o.deliveryAddress,
      clientName: o.clientName,
      phone: o.phone,
      orderPrice: parseFloat(o.orderPrice),
      deliveryFee: role === 'captain' ? (parseFloat(o.captainShare) > 0 ? parseFloat(o.captainShare) : parseFloat(o.deliveryFee || 0) * 0.8) : parseFloat(o.deliveryFee),
      latitude: o.latitude ? parseFloat(o.latitude) : null,
      longitude: o.longitude ? parseFloat(o.longitude) : null,
      merchantLatitude: o.merchantLatitude ? parseFloat(o.merchantLatitude) : null,
      merchantLongitude: o.merchantLongitude ? parseFloat(o.merchantLongitude) : null,
      driverLatitude: o.captainLatitude ? parseFloat(o.captainLatitude) : null,
      driverLongitude: o.captainLongitude ? parseFloat(o.captainLongitude) : null,
      startLatitude: o.startLatitude ? parseFloat(o.startLatitude) : null,
      startLongitude: o.startLongitude ? parseFloat(o.startLongitude) : null,
      status: o.status,
      createdAt: formatDate(o.createdAt),
      updatedAt: formatDate(o.updatedAt),
      merchantName: o.merchantStoreName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : null),
      merchantAvatar: o.merchantProfileImage || null,
      merchantPhone: o.merchantPhone || null,
      captainName: o.captainFirstName ? `${o.captainFirstName} ${o.captainLastName}` : null,
      captainAvatar: o.captainProfileImage || null,
      captainPhone: o.captainPhone || null,
      captainAvgRating: parseFloat(o.captainAvgRating || 0.0),
      captainReviewCount: parseInt(o.captainReviewCount || 0),
      captainApprovalStatus: o.captainApprovalStatus || null,
      assignedAdminId: o.assignedAdminId ? o.assignedAdminId.toString() : null,
      assignedAdminName: o.assignedAdminFirstName ? `${o.assignedAdminFirstName} ${o.assignedAdminLastName}`.trim() : null,
      isPaid: o.isPaid === 1 || o.isPaid === true,
    }));

    res.status(200).json({
      status: 1,
      data: formattedOrders
    });
  } catch (error) {
    next(error);
  }
};

// 3. GET ORDER BY ID
const getOrderById = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [orders] = await pool.query(
      `SELECT o.*, 
              m.firstName as merchantFirstName, m.lastName as merchantLastName, m.storeName as merchantStoreName,
              m.profileImage as merchantProfileImage, m.phone as merchantPhone, m.address as merchantAddress,
              m.latitude as merchantLatitude, m.longitude as merchantLongitude,
              c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone,
              c.latitude as captainLatitude, c.longitude as captainLongitude,
              a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
              COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = o.captainId), 1), 0.0) as captainAvgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = o.captainId) as captainReviewCount,
              EXISTS(SELECT 1 FROM reviews WHERE reviews.orderId = o.id AND reviews.reviewerId = ?) as hasReviewed
       FROM orders o
       LEFT JOIN users m ON o.merchantId = m.id
       LEFT JOIN users c ON o.captainId = c.id
       LEFT JOIN users a ON o.assignedAdminId = a.id
       WHERE o.id = ?`,
      [req.user.id, id]
    );

    if (orders.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الطلب غير موجود'
      });
    }

    const o = orders[0];
    try {
      assertOrderAccess(o, req.user);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }

    const [directPayments] = await pool.query(
      'SELECT id, paymentRef, amount, paymentMethod, fromPhone, fromName, receiptImage, status, adminNote, createdAt FROM direct_payments WHERE orderId = ? ORDER BY createdAt DESC LIMIT 1',
      [o.id]
    );

    res.status(200).json({
      status: 1,
      data: {
        directPayment: directPayments.length > 0 ? directPayments[0] : null,
        id: o.id.toString(),
        orderNumber: o.orderNumber,
        merchantId: o.merchantId ? o.merchantId.toString() : null,
        captainId: o.captainId ? o.captainId.toString() : null,
        hasReviewed: o.hasReviewed === 1 || o.hasReviewed === true,
        tripId: o.trip_id ? o.trip_id.toString() : null,
        details: o.details,
        storeDescription: o.storeDescription,
        merchantAddress: o.merchantAddress || o.merchantStoreName || o.storeDescription || '',
        fromAddress: o.merchantAddress || o.merchantStoreName || o.storeDescription || '',
        notes: o.notes || '',
        deliveryAddress: o.deliveryAddress,
        clientName: o.clientName,
        phone: o.phone,
        orderPrice: parseFloat(o.orderPrice),
        deliveryFee: req.user.role === 'captain' ? (parseFloat(o.captainShare) > 0 ? parseFloat(o.captainShare) : parseFloat(o.deliveryFee || 0) * 0.8) : parseFloat(o.deliveryFee),
        platformShare: parseFloat(o.platformShare) > 0 ? parseFloat(o.platformShare) : parseFloat(o.deliveryFee || 0) * 0.2,
        captainShare: parseFloat(o.captainShare) > 0 ? parseFloat(o.captainShare) : parseFloat(o.deliveryFee || 0) * 0.8,
        latitude: o.latitude ? parseFloat(o.latitude) : null,
        longitude: o.longitude ? parseFloat(o.longitude) : null,
        merchantLatitude: o.merchantLatitude ? parseFloat(o.merchantLatitude) : null,
        merchantLongitude: o.merchantLongitude ? parseFloat(o.merchantLongitude) : null,
        driverLatitude: o.captainLatitude ? parseFloat(o.captainLatitude) : null,
        driverLongitude: o.captainLongitude ? parseFloat(o.captainLongitude) : null,
        startLatitude: o.startLatitude ? parseFloat(o.startLatitude) : null,
        startLongitude: o.startLongitude ? parseFloat(o.startLongitude) : null,
        status: o.status,
        createdAt: formatDate(o.createdAt),
        updatedAt: formatDate(o.updatedAt),
        merchantName: o.merchantStoreName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : null),
        merchantAvatar: o.merchantProfileImage || null,
        merchantPhone: o.merchantPhone || null,
        captainName: o.captainFirstName ? `${o.captainFirstName} ${o.captainLastName}` : null,
        captainAvatar: o.captainProfileImage || null,
        captainPhone: o.captainPhone || null,
        captainAvgRating: parseFloat(o.captainAvgRating || 0.0),
        captainReviewCount: parseInt(o.captainReviewCount || 0),
        captainApprovalStatus: o.captainApprovalStatus || null,
        assignedAdminId: o.assignedAdminId ? o.assignedAdminId.toString() : null,
        assignedAdminName: o.assignedAdminFirstName ? `${o.assignedAdminFirstName} ${o.assignedAdminLastName}`.trim() : null,
        isPaid: o.isPaid === 1 || o.isPaid === true,
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. UPDATE ORDER STATUS
const updateOrderStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { status, isPaid, latitude, longitude } = req.body;
    const userId = req.user.id;
    const role = req.user.role;

    if (!status) {
      return res.status(400).json({
        status: 0,
        message: 'الحالة مطلوبة'
      });
    }

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الطلب غير موجود'
      });
    }

    const order = orders[0];
    try {
      assertOrderAccess(order, req.user);
      assertOrderStatusTransition(role, order, status, userId);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }

    if (['delivered', 'completed', 'منتهية'].includes(status.toString().trim().toLowerCase()) || status === 'منتهية') {
      const captainId = order.captainId || (role === 'captain' ? userId : null);
      if (!captainId) {
        return res.status(400).json({ status: 0, message: 'لا يوجد كابتن معين لهذا الطلب' });
      }

      const deliveryFee = parseFloat(order.deliveryFee || 0);
      const captainShare = parseFloat(order.captainShare || (deliveryFee * 0.8));
      const finalStatus = 'Completed';

      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();

        await conn.query(
          `UPDATE orders 
           SET status = ?, 
               deliveryConfirmedAt = NOW(), 
               deliveryLatitude = ?, 
               deliveryLongitude = ? 
           WHERE id = ?`,
          [finalStatus, latitude ? parseFloat(latitude) : null, longitude ? parseFloat(longitude) : null, id]
        );

        await conn.query(
          'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
          [captainShare, captainId]
        );

        const txTitle = `رسوم توصيل الطلب #${order.orderNumber}`;
        await conn.query(
          "INSERT INTO wallet_transactions (userId, title, amount, type, status) VALUES (?, ?, ?, 'deposit', 'success')",
          [captainId, txTitle, captainShare]
        );

        await conn.commit();

        checkAndRewardReferral(order.merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
        checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));

        const io = req.app.get('io');
        if (io) {
          io.to(`order_${id}`).emit('statusUpdate', { status: finalStatus });
          io.to(`order_${id}`).emit('chat_deleted', { orderId: id });
          io.to('admins').emit('dashboard_update');
        }

        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) {}

        await pool.query('DELETE FROM messages WHERE orderId = ?', [id]);

        // Send notifications
        const [senderRows] = await pool.query('SELECT firstName, lastName, profileImage FROM users WHERE id = ?', [userId]);
        const senderName = senderRows.length > 0 ? (senderRows[0].storeName || `${senderRows[0].firstName} ${senderRows[0].lastName}`.trim()) : 'مستخدم';
        const [merchantRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [order.merchantId]);
        const merchantFcm = merchantRows.length > 0 ? merchantRows[0].fcmToken : null;
        const [captainRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [captainId]);
        const captainFcm = captainRows.length > 0 ? captainRows[0].fcmToken : null;

        const msg = 'تم تسليم الطلب بنجاح واكتماله 🎉';
        sendNotification(io, order.merchantId, `تم تسليم الطلب #${order.orderNumber}`, msg, 'order', { type: 'order_completed', orderId: id.toString() });
        sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `تم إكمال الطلب #${order.orderNumber}. تم إيداع ${captainShare} ج.م في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: captainShare.toString() });

        const { notifyAdmins } = require('../utils/adminNotifier');
        await notifyAdmins(io, '✅ طلب مكتمل',
          `الطلب #${order.orderNumber} تم تسليمه وإكماله بنجاح`,
          'order_completed', { type: 'order_completed', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );

        return res.status(200).json({
          status: 1,
          message: 'تم توصيل الطلب واكتماله بنجاح وتنزيل الرصيد في حساب الكابتن',
          data: {
            id: id.toString(),
            status: finalStatus
          }
        });
      } catch (err) {
        await conn.rollback();
        throw err;
      } finally {
        conn.release();
      }
    }

    const oldStatus = order.status;
    const oldCaptainId = order.captainId;

    let sql = 'UPDATE orders SET status = ?';
    const queryParams = [status];

    if (['admin', 'employee'].includes(role)) {
      sql += ', assignedAdminId = ?';
      queryParams.push(userId);
    }

    if (['admin', 'employee'].includes(role) && isPaid !== undefined) {
      sql += ', isPaid = ?';
      queryParams.push(isPaid === true || isPaid === 1 || isPaid === 'true' ? 1 : 0);
    }

    if (role === 'captain' && (status === 'rejected' || status === 'مرفوض' || status === 'timeout')) {
      const { resolveAttempt, triggerAutoAssignment } = require('../utils/autoAssignment');
      const isTimeout = status === 'timeout';
      await resolveAttempt(pool, { orderId: id, captainId: userId, status: isTimeout ? 'timeout' : 'rejected', reason: isTimeout ? 'انتهت مهلة قبول الطلب للكابتن' : 'الكابتن قام برفض الطلب' });
      status = 'Ready For Assignment';
      sql = "UPDATE orders SET status = 'Ready For Assignment', captainId = NULL, captainApprovalStatus = NULL WHERE id = ?";
      queryParams.length = 0;
      queryParams.push(id);
      setImmediate(() => {
        triggerAutoAssignment(null, id).catch(err => console.error('Error triggering auto assignment after timeout/reject:', err));
      });
    } else if (role === 'captain' && (status === 'جاري التنفيذ' || status === 'تم القبول' || status === 'In Transit' || status === 'Picked Up' || status === 'Captain Arrived' || status === 'captain arrived')) {
      sql += ', captainId = ?, captainApprovalStatus = ?';
      queryParams.push(userId);
      queryParams.push('accepted');
    } else if ((role === 'merchant') && (status === 'بانتظار القبول' || status === 'Pending Review')) {
      sql += ', captainId = NULL, captainApprovalStatus = NULL';
    }

    if (['Picked Up', 'picked up'].includes(status)) {
      sql += ', pickupConfirmedAt = NOW(), pickupLatitude = ?, pickupLongitude = ?';
      queryParams.push(latitude ? parseFloat(latitude) : null);
      queryParams.push(longitude ? parseFloat(longitude) : null);
    }

    if (['Ready For Assignment'].includes(status)) {
      const feeVal = parseFloat(order.deliveryFee || 0);
      sql += ', platformShare = ?, captainShare = ?, autoAssignmentFailed = 0';
      queryParams.push(feeVal * 0.20);
      queryParams.push(feeVal * 0.80);
    }

    queryParams.push(id);

    await pool.query(
      `${sql} WHERE id = ?`,
      queryParams
    );

    // Fetch information of the user performing the action (sender)
    const [senderRows] = await pool.query('SELECT firstName, lastName, profileImage FROM users WHERE id = ?', [userId]);
    const senderName = senderRows.length > 0 ? (senderRows[0].storeName || `${senderRows[0].firstName} ${senderRows[0].lastName}`.trim()) : 'مستخدم';
    const senderAvatar = senderRows.length > 0 ? (senderRows[0].profileImage || null) : null;

    const captainId = order.captainId || oldCaptainId;
    const merchantId = order.merchantId;

    await logStatusChange(pool, {
      orderId: id,
      userId,
      userName: senderName,
      userRole: role,
      previousStatus: oldStatus,
      newStatus: status,
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null
    });

    const fetchFcm = async (uid) => {
      if (!uid) return null;
      const [rows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [uid]);
      return rows.length > 0 ? (rows[0].fcmToken || null) : null;
    };

    const captainFcm = await fetchFcm(captainId);
    const merchantFcm = await fetchFcm(merchantId);

    const baseData = {
      type: 'order_status_update',
      orderId: id.toString(),
      orderNumber: order.orderNumber,
      senderName: senderName,
      senderAvatar: senderAvatar || '',
      status: status
    };

    const io = req.app.get('io');

    const notify = async (fcmToken, targetUserId, title, body, extraData = {}) => {
      if (!targetUserId) return;
      await sendNotification(io, targetUserId, title, body, 'order', { ...baseData, ...extraData });
    };
    if (io) {
      io.to(`order_${id}`).emit('statusUpdate', { status, isCancelled: ['cancelled', 'ملغي', 'ملغية'].includes(status.toString().trim().toLowerCase()) });
      io.to('admins').emit('dashboard_update');
      if (['cancelled', 'ملغي', 'ملغية'].includes(status.toString().trim().toLowerCase()) && captainId) {
        io.to(`user_${captainId}`).emit('order_cancelled', { orderId: id.toString(), orderNumber: order.orderNumber });
        io.to(`captain_${captainId}`).emit('order_cancelled', { orderId: id.toString(), orderNumber: order.orderNumber });
      }
    }

    // Emit granular order_updated event with full data
    try {
      const eventData = await fetchOrderEventData(id);
      if (eventData && io) {
        io.to('admins').emit('order_updated', eventData);
      }
    } catch (_) {}

    // Handle notifications based on new status — all statuses covered
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');

      if (status === 'Captain Arrived' || status === 'captain arrived') {
        await notify(merchantFcm, merchantId,
          `وصل الكابتن إلى موقع الاستلام 📍`,
          `وصل المندوب ${senderName} إلى موقع استلام الطلب #${order.orderNumber}.`,
          { type: 'captain_arrived' }
        );
        await notifyAdmins(io, '📍 وصول الكابتن للاستلام',
          `الكابتن ${senderName} وصل إلى موقع استلام الطلب #${order.orderNumber}`,
          'captain_arrived', { type: 'captain_arrived', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'Picked Up' || status === 'picked up') {
        // الكابتن شرى الطلب - أخبر التاجر
        await notify(merchantFcm, merchantId,
          `تم شراء طلبك 🛒`,
          `قام المندوب بشراء طلبك #${order.orderNumber} ويتجه إليك قريباً.`,
          { type: 'order_picked_up' }
        );
        await notifyAdmins(io, '🛒 تم شراء الطلب',
          `الكابتن ${senderName} شرى الطلب #${order.orderNumber}`,
          'order_picked_up', { type: 'order_picked_up', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'In Transit') {
        // الكابتن في الطريق - أخبر التاجر
        await notify(merchantFcm, merchantId,
          `جارٍ توصيل طلبك 🚚`,
          `المندوب في طريقه لتوصيل طلبك #${order.orderNumber}.`,
          { type: 'order_in_transit' }
        );
        await notifyAdmins(io, '🚚 طلب جارٍ توصيله',
          `الطلب #${order.orderNumber} جارٍ توصيله بواسطة ${senderName}`,
          'order_in_transit', { type: 'order_in_transit', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'Delivered') {
        // الكابتن وصل - أخبر التاجر بتأكيد الاستلام
        await notify(merchantFcm, merchantId,
          `تم توصيل طلبك 🎉`,
          `وصل المندوب بطلبك #${order.orderNumber}. يرجى تأكيد الاستلام.`,
          { type: 'order_delivered' }
        );
        await notifyAdmins(io, '✅ طلب تم توصيله',
          `الكابتن ${senderName} وصل الطلب #${order.orderNumber}`,
          'order_delivered', { type: 'order_delivered', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'Completed') {
        // تم تأكيد التاجر
        await notify(merchantFcm, merchantId,
          `اكتمل طلبك 🎉`,
          `تم إكمال طلبك #${order.orderNumber} بنجاح.`,
          { type: 'order_completed' }
        );
        if (captainId) {
          await notify(captainFcm, captainId,
            `تم تأكيد التوصيل ✅`,
            `أكد التاجر استلام الطلب #${order.orderNumber}. جزاك الله خيراً.`,
            { type: 'order_completed' }
          );
        }
        await notifyAdmins(io, '✅ طلب مكتمل',
          `الطلب #${order.orderNumber} تم إكماله بنجاح`,
          'order_completed', { type: 'order_completed', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'Pending Review' || status === 'بانتظار القبول') {
        await notify(captainFcm, captainId,
          `تم إلغاء التعيين 🔄`,
          `الطلب #${order.orderNumber} متاح لكابتن آخر`,
          { type: 'order_cancelled' }
        );
        await notifyAdmins(io, '🔄 طلب بانتظار القبول',
          `الطلب #${order.orderNumber} بانتظار كابتن جديد`,
          'order_pending', { type: 'order_pending', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (status === 'Ready For Assignment' || status === 'Assigned To Captain') {
        if (captainId) {
          await notify(captainFcm, captainId,
            `تم تعيينك لتوصيل طلب 📋`,
            `تم تعيينك لتوصيل الطلب #${order.orderNumber}`,
            { type: 'order_assigned' }
          );
        }
        await notifyAdmins(io, '📋 طلب تم تعيينه',
          `الطلب #${order.orderNumber} تم تعيينه لكابتن`,
          'order_assigned', { type: 'order_assigned', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      }
      // Admin approves order directly without negotiation
      if (
        ['admin', 'employee'].includes(role) &&
        ['Ready For Assignment', 'Assigned To Captain'].includes(status) &&
        ['جديدة', 'بانتظار القبول', 'Pending Review'].includes(oldStatus)
      ) {
        await notify(merchantFcm, merchantId,
          `✅ تم قبول طلبك`,
          `وافقت الإدارة على طلبك رقم #${order.orderNumber} بنجاح وجارٍ العمل عليه.`,
          { type: 'order_approved_directly' }
        );
      }
    } catch (_) { }

    // Trigger referral completion checks on delivered/completed orders
    if (status === 'Delivered' || status === 'Completed') {
      checkAndRewardReferral(merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
      if (captainId) {
        checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));
      }
    }

    if (status === 'Ready For Assignment') {
      const { triggerAutoAssignment } = require('../utils/autoAssignment');
      triggerAutoAssignment(null, id).catch(err => console.error('Error triggering auto assignment:', err.message));
    }

    res.status(200).json({
      status: 1,
      message: 'تم تحديث حالة الطلب بنجاح',
      data: {
        id: id.toString(),
        status
      }
    });
  } catch (error) {
    next(error);
  }
};

// 5. CONFIRM PICKUP (Merchant only)
const confirmPickup = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const merchantId = req.user.id;

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    const order = orders[0];
    if (order.merchantId !== merchantId) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتأكيد استلام هذا الطلب' });
    }

    const allowedStatuses = ['Assigned To Captain', 'Captain Arrived'];
    if (!allowedStatuses.includes(order.status)) {
      return res.status(400).json({ status: 0, message: 'لا يمكن تأكيد استلام الطلب في الحالة الحالية' });
    }

    const newStatus = 'Picked Up';
    await pool.query(
      `UPDATE orders 
       SET status = ?, 
           pickupConfirmedAt = NOW(), 
           pickupLatitude = ?, 
           pickupLongitude = ? 
       WHERE id = ?`,
      [newStatus, latitude ? parseFloat(latitude) : null, longitude ? parseFloat(longitude) : null, id]
    );

    await logStatusChange(pool, {
      orderId: id,
      userId: merchantId,
      userName: 'التاجر',
      userRole: 'merchant',
      previousStatus: order.status,
      newStatus: newStatus,
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`order_${id}`).emit('statusUpdate', { status: newStatus });
      io.to('admins').emit('dashboard_update');
    }

    // Emit granular order_updated event
    try {
      const eventData = await fetchOrderEventData(id);
      if (eventData && io) {
        io.to('admins').emit('order_updated', eventData);
      }
    } catch (_) {}

    if (order.captainId) {
      sendNotification(io, order.captainId, 'تم تأكيد الاستلام 📦', `أكد التاجر استلام الطلب #${order.orderNumber}. يمكنك الآن بدء التوصيل.`, 'order', { type: 'order_picked_up', orderId: id.toString() });
    }

    res.status(200).json({
      status: 1,
      message: 'تم تأكيد استلام الطلب بنجاح وبدء مسار التوصيل'
    });
  } catch (error) {
    next(error);
  }
};

// 6. CONFIRM DELIVERY (Merchant/Admin)
const confirmDelivery = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const merchantId = req.user.id;

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    const order = orders[0];
    if (order.merchantId !== merchantId && req.user.role !== 'admin') {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتأكيد تسليم هذا الطلب' });
    }

    // التاجر يؤكد فقط بعد أن يمارك الكابتن الحالة "Delivered"
    const allowedStatuses = ['Delivered'];
    if (!allowedStatuses.includes(order.status)) {
      return res.status(400).json({ status: 0, message: 'لا يمكن تأكيد التسليم - يجب أن يكون المندوب قد سلّم الطلب أولاً' });
    }

    const newStatus = 'Completed';
    const captainId = order.captainId;

    if (!captainId) {
      return res.status(400).json({ status: 0, message: 'لا يوجد كابتن معين لهذا الطلب' });
    }

    const deliveryFee = parseFloat(order.deliveryFee || 0);
    const captainShare = parseFloat(order.captainShare || (deliveryFee * 0.8));

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      await conn.query(
        `UPDATE orders 
         SET status = ?, 
             deliveryConfirmedAt = NOW(), 
             deliveryLatitude = ?, 
             deliveryLongitude = ? 
         WHERE id = ?`,
        [newStatus, latitude ? parseFloat(latitude) : null, longitude ? parseFloat(longitude) : null, id]
      );

      await conn.query(
        'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
        [captainShare, captainId]
      );

      const txTitle = `رسوم توصيل الطلب #${order.orderNumber}`;
      await conn.query(
        "INSERT INTO wallet_transactions (userId, title, amount, type, status) VALUES (?, ?, ?, 'deposit', 'success')",
        [captainId, txTitle, captainShare]
      );

      await conn.commit();

      await logStatusChange(pool, {
        orderId: id,
        userId: merchantId,
        userName: req.user.role === 'admin' ? 'المدير' : 'التاجر',
        userRole: req.user.role,
        previousStatus: order.status,
        newStatus: newStatus,
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null
      });

      checkAndRewardReferral(order.merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
      checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));

      const io = req.app.get('io');
      if (io) {
        io.to(`order_${id}`).emit('statusUpdate', { status: newStatus });
        io.to(`order_${id}`).emit('chat_deleted', { orderId: id });
        io.to('admins').emit('dashboard_update');
      }

      // Emit granular order_updated event
      try {
        const eventData = await fetchOrderEventData(id);
        if (eventData && io) {
          io.to('admins').emit('order_updated', eventData);
        }
      } catch (_) {}

      await pool.query('DELETE FROM messages WHERE orderId = ?', [id]);

      sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `أكد التاجر تسليم الطلب #${order.orderNumber}. تم إيداع ${captainShare} ج.م في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: captainShare.toString() });

      res.status(200).json({
        status: 1,
        message: 'تم تأكيد تسليم الطلب بنجاح وإيداع مستحقات المندوب في محفظته'
      });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (error) {
    next(error);
  }
};

const handleCaptainResponse = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { response } = req.body; // 'accept' or 'reject'
    const captainId = req.user.id;

    if (!response || !['accept', 'reject'].includes(response)) {
      return res.status(400).json({ status: 0, message: 'الرد غير صالح. يجب أن يكون accept أو reject' });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [orders] = await conn.query('SELECT * FROM orders WHERE id = ? FOR UPDATE', [id]);
      if (orders.length === 0) {
        await conn.rollback();
        return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
      }

      const order = orders[0];
      if (order.captainId !== captainId) {
        await conn.rollback();
        return res.status(403).json({ status: 0, message: 'غير مصرح لك بالرد على تكليف هذا الطلب' });
      }

      if (order.captainApprovalStatus !== 'pending') {
        await conn.rollback();
        return res.status(400).json({ status: 0, message: 'تم الرد على هذا التكليف مسبقاً أو غير معلق' });
      }

      const targetRoom = `order_${id}`;
      const io = req.app.get('io');

      // Fetch captain's real name from DB (not in JWT)
      const [captainRows] = await conn.query('SELECT firstName, lastName FROM users WHERE id = ?', [captainId]);
      const captainName = captainRows.length > 0 ? `${captainRows[0].firstName || ''} ${captainRows[0].lastName || ''}`.trim() : 'كابتن';

      if (response === 'accept') {
        const [updateResult] = await conn.query(
          "UPDATE orders SET captainApprovalStatus = 'accepted' WHERE id = ? AND captainId = ? AND captainApprovalStatus = 'pending'",
          [id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف متاحاً لك حالياً' });
        }

        await conn.commit();

        const { resolveAttempt } = require('../utils/autoAssignment');
        await resolveAttempt(pool, { orderId: id, captainId, status: 'accepted', reason: 'Captain accepted assignment' });

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: order.status });
          io.to(targetRoom).emit('captain_response', { response: 'accept', captainId });
          io.to('admins').emit('dashboard_update');
        }

        // Notify admins about captain acceptance
        const { notifyAdmins } = require('../utils/adminNotifier');
        const orderPrice = parseFloat(order.orderPrice || 0).toFixed(2);
        notifyAdmins(io,
          `✅ قبول تكليف طلب #${order.orderNumber}`,
          `الكابتن ${captainName} قبل تكليف الطلب رقم ${order.orderNumber} بقيمة ${orderPrice} ج.م`,
          'system',
          { type: 'captain_accepted', orderId: id.toString(), orderNumber: order.orderNumber, captainName, price: orderPrice }
        );

        // Emit granular order_updated event
        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) {}

        res.status(200).json({
          status: 1,
          message: 'تم قبول تكليف الطلب بنجاح'
        });
      } else {
        // Reject: reset captainId, captainApprovalStatus, and return status to Ready For Assignment
        const [updateResult] = await conn.query(
          "UPDATE orders SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment' WHERE id = ? AND captainId = ? AND captainApprovalStatus = 'pending'",
          [id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف معلقاً لديك' });
        }

        await conn.commit();

        const { resolveAttempt, triggerAutoAssignment } = require('../utils/autoAssignment');
        await resolveAttempt(pool, { orderId: id, captainId, status: 'rejected', reason: 'Captain rejected assignment' });

        // Notify all admins and employees
        const { notifyAdmins } = require('../utils/adminNotifier');
        const orderPrice = parseFloat(order.orderPrice || 0).toFixed(2);
        notifyAdmins(io,
          `❌ رفض تكليف طلب #${order.orderNumber}`,
          `الكابتن ${captainName} رفض تكليف الطلب رقم ${order.orderNumber} بقيمة ${orderPrice} ج.م`,
          'system',
          { type: 'captain_rejected', orderId: id.toString(), orderNumber: order.orderNumber, captainName, price: orderPrice }
        );

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: 'Ready For Assignment' });
          io.to(targetRoom).emit('captain_response', { response: 'reject', captainId });
          io.to('admins').emit('dashboard_update');
        }

        // Instantly trigger auto-assignment to search for the next captain in the background
        triggerAutoAssignment(null, id).catch(err => console.error('Error triggering auto assignment after reject:', err.message));

        // Emit granular order_updated event
        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) {}

        res.status(200).json({
          status: 1,
          message: 'تم رفض تكليف الطلب وإعادة إتاحتها للتعيين'
        });
      }
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (error) {
    next(error);
  }
};

// 8. COMPUTE PRICING (calculate platform & captain shares, notify admins)
const computePricing = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const io = req.app.get('io');

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    const order = orders[0];
    const feeVal = parseFloat(order.deliveryFee || 0);
    const platformShare = feeVal * 0.20;
    const captainShare = feeVal * 0.80;

    await pool.query(
      'UPDATE orders SET platformShare = ?, captainShare = ? WHERE id = ?',
      [platformShare, captainShare, id]
    );

    // Notify admins
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        'تم حساب تسعير الطلب 💰',
        `تم تطبيق خصم 20% على الطلب #${order.orderNumber}. سعر الكابتن: ${captainShare.toFixed(2)} ج.م`,
        'order',
        { type: 'pricing_computed', orderId: id.toString(), orderNumber: order.orderNumber },
        req.user?.id
      );
    } catch (_) { }

    res.status(200).json({
      status: 1,
      message: 'تم حساب التسعير بنجاح',
      data: {
        id: order.id.toString(),
        orderPrice: parseFloat(order.orderPrice),
        deliveryFee: feeVal,
        platformShare,
        captainShare
      }
    });
  } catch (error) {
    next(error);
  }
};

const claimOrder = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const adminId = req.user.id;

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    await pool.query('UPDATE orders SET assignedAdminId = ? WHERE id = ?', [adminId, id]);

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
    }

    try {
      const eventData = await fetchOrderEventData(id);
      if (eventData && io) {
        io.to('admins').emit('order_updated', eventData);
      }
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم استلام الطلب بنجاح للبدء بمتابعته',
      data: { assignedAdminId: adminId }
    });
  } catch (error) {
    next(error);
  }
};

const deleteOrder = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const merchantId = req.user.id;

    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE id = ? AND merchantId = ?',
      [id, merchantId]
    );

    if (orders.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الطلب غير موجود أو لا تملك صلاحية حذفه'
      });
    }

    const order = orders[0];
    if (order.status !== 'Pending Review') {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن حذف الطلب بعد قبوله أو البدء في تنفيذه'
      });
    }

    await pool.query('DELETE FROM orders WHERE id = ?', [id]);

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
      io.emit('order_deleted', { id: id.toString() });
    }

    res.status(200).json({
      status: 1,
      message: 'تم حذف الطلب بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

const updateOrder = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const merchantId = req.user.id;

    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE id = ? AND merchantId = ?',
      [id, merchantId]
    );

    if (orders.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الطلب غير موجود أو لا تملك صلاحية تعديله'
      });
    }

    const order = orders[0];
    if (order.status !== 'Pending Review') {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن تعديل الطلب بعد قبوله أو البدء في تنفيذه'
      });
    }

    const {
      details,
      storeDescription,
      notes,
      deliveryAddress,
      clientName,
      phone,
      orderPrice,
      deliveryFee,
      latitude,
      longitude
    } = req.body;

    if (!details || !storeDescription || !deliveryAddress || !clientName || !phone || orderPrice === undefined || deliveryFee === undefined) {
      return res.status(400).json({
        status: 0,
        message: 'الحقول الأساسية مطلوبة'
      });
    }

    await pool.query(
      `UPDATE orders SET 
        details = ?, storeDescription = ?, notes = ?, 
        deliveryAddress = ?, clientName = ?, phone = ?, 
        orderPrice = ?, deliveryFee = ?, 
        latitude = ?, longitude = ?
      WHERE id = ?`,
      [
        details,
        storeDescription,
        notes || null,
        deliveryAddress,
        clientName,
        phone,
        parseFloat(orderPrice),
        parseFloat(deliveryFee),
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null,
        id
      ]
    );

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
    }

    try {
      const eventData = await fetchOrderEventData(id);
      if (eventData && io) {
        io.to('admins').emit('order_updated', eventData);
      }
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم تحديث الطلب بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

const getOrderLogs = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const logs = await getStatusLogs(pool, { orderId: id });
    res.status(200).json({
      status: 1,
      data: logs
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createOrder,
  getOrders,
  getOrderById,
  getOrderLogs,
  updateOrderStatus,
  confirmPickup,
  confirmDelivery,
  handleCaptainResponse,
  computePricing,
  claimOrder,
  deleteOrder,
  updateOrder
};

