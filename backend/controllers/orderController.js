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
      m.storeName as merchantAddress,
      m.latitude as merchantLatitude,
      m.longitude as merchantLongitude,
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
    merchantAddress: o.merchantAddress || o.merchantName || o.storeDescription || '',
    fromAddress: o.merchantAddress || o.merchantName || o.storeDescription || '',
    notes: o.notes || '',
    deliveryAddress: o.deliveryAddress,
    clientName: o.clientName,
    phone: o.phone,
    orderPrice: parseFloat(o.orderPrice || 0),
    deliveryFee: parseFloat(o.deliveryFee || 0),
    latitude: o.latitude ? parseFloat(o.latitude) : null,
    longitude: o.longitude ? parseFloat(o.longitude) : null,
    merchantLatitude: o.merchantLatitude ? parseFloat(o.merchantLatitude) : null,
    merchantLongitude: o.merchantLongitude ? parseFloat(o.merchantLongitude) : null,
    merchantName: o.merchantName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : ''),
    status: o.status,
    assignedAdminId: o.assignedAdminId ? o.assignedAdminId.toString() : null,
    assignedAdminName: o.assignedAdminFirstName ? `${o.assignedAdminFirstName} ${o.assignedAdminLastName}`.trim() : null,
    createdAt: formatDate(o.createdAt),
    updatedAt: formatDate(o.updatedAt),
  };
}

// 1. CREATE ORDER (Merchant, Admin, Employee)
const createOrder = async (req, res, next) => {
  try {
    const pool = getPool();
    const isAdminOrEmp = req.user.role === 'admin' || req.user.role === 'employee';
    const merchantId = isAdminOrEmp && req.body.merchantId ? parseInt(req.body.merchantId, 10) : req.user.id;

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

    // Check operating hours & service availability (admin/employee can bypass)
    if (!isAdminOrEmp) {
      const { checkServiceAvailability } = require('../utils/serviceHoursHelper');
      const serviceCheck = await checkServiceAvailability('orders');
      if (!serviceCheck.isOpen) {
        return res.status(400).json({
          status: 0,
          code: 'SERVICE_CLOSED',
          message: serviceCheck.reason || 'خدمة اطلب مندوب غير متاحة حالياً نظراً لانتهاء مواعيد العمل اليومية.'
        });
      }
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

      // All orders start in 'Pending Review' for admin confirmation
      const statusVal = 'Pending Review';
      const platformShare = finalDeliveryFee * 0.20;
      const captainShare = finalDeliveryFee * 0.80;

      const { findActiveShiftForOrder } = require('../utils/shiftMatcher');
      const shiftId = await findActiveShiftForOrder({
        merchantId,
        conn,
      });

      // Fetch store and commission settings
      let storeId = req.body.storeId ? parseInt(req.body.storeId, 10) : null;
      let commRate = 5.0;
      let commType = 'percentage';

      if (storeId) {
        const [storeRows] = await conn.query(
          'SELECT id, merchantId, commissionRate, commissionType FROM stores WHERE id = ? AND deletedAt IS NULL LIMIT 1',
          [storeId]
        );
        if (storeRows.length > 0) {
          if (!merchantId || isNaN(merchantId)) {
            merchantId = storeRows[0].merchantId;
          }
          commRate = storeRows[0].commissionRate || 5.0;
          commType = storeRows[0].commissionType || 'percentage';
        }
      } else if (merchantId) {
        const [storeRows] = await conn.query(
          'SELECT id, commissionRate, commissionType FROM stores WHERE merchantId = ? AND deletedAt IS NULL LIMIT 1',
          [merchantId]
        );
        if (storeRows.length > 0) {
          storeId = storeRows[0].id;
          commRate = storeRows[0].commissionRate || 5.0;
          commType = storeRows[0].commissionType || 'percentage';
        }
      }

      // Link client if provided or by phone
      let clientId = req.body.clientId ? parseInt(req.body.clientId, 10) : null;
      const clientEmail = (req.body.clientEmail || '').trim();

      if (!clientId && phone) {
        const [clRows] = await conn.query(
          "SELECT id, email FROM users WHERE phone = ? AND role = 'client' LIMIT 1",
          [phone.trim()]
        );
        if (clRows.length > 0) {
          clientId = clRows[0].id;
          if (clientEmail && (!clRows[0].email || clRows[0].email.trim() === '')) {
            await conn.query("UPDATE users SET email = ? WHERE id = ?", [clientEmail, clientId]).catch(() => {});
          }
        }
      } else if (clientId && clientEmail) {
        await conn.query(
          "UPDATE users SET email = ? WHERE id = ? AND (email IS NULL OR email = '')",
          [clientEmail, clientId]
        ).catch(() => {});
      }

      const { calculateOrderCommission } = require('../utils/commissionCalculator');
      const commResult = calculateOrderCommission({
        orderPrice: parseFloat(orderPrice),
        commissionRate: commRate,
        commissionType: commType,
      });

      const paymentMethodVal = req.body.paymentMethod || 'cash';
      const paymentStatusVal = req.body.paymentStatus || 'pending';

      const rawServiceFee = req.body.serviceFee !== undefined ? parseFloat(req.body.serviceFee) : null;
      let serviceFee = 5.00;
      if (rawServiceFee !== null && !isNaN(rawServiceFee)) {
        serviceFee = rawServiceFee;
      } else {
        const [feeRows] = await conn.query("SELECT `value` FROM app_settings WHERE `key` = 'store_service_fee' LIMIT 1");
        if (feeRows.length > 0 && !isNaN(parseFloat(feeRows[0].value))) {
          serviceFee = parseFloat(feeRows[0].value);
        }
      }
      const rawTip = req.body.tip !== undefined ? parseFloat(req.body.tip) : 0.00;
      const tip = isNaN(rawTip) ? 0.00 : rawTip;

      const [result] = await conn.query(
        `INSERT INTO orders (
          orderNumber, merchantId, clientId, storeId, details, storeDescription, notes, 
          deliveryAddress, clientName, phone, orderPrice, deliveryFee, serviceFee, tip,
          latitude, longitude, trip_id, status,
          platformShare, captainShare, autoAssignmentFailed, couponCode, discountApplied, shift_id,
          paymentMethod, paymentStatus, platformCommission, merchantNet,
          commissionRateSnapshot, commissionTypeSnapshot
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderNumber,
          merchantId,
          clientId,
          storeId,
          details,
          storeDescription,
          notes || null,
          deliveryAddress,
          clientName,
          phone,
          parseFloat(orderPrice),
          finalDeliveryFee,
          serviceFee,
          tip,
          latitude ? parseFloat(latitude) : null,
          longitude ? parseFloat(longitude) : null,
          tripId ? parseInt(tripId) : null,
          statusVal,
          platformShare,
          captainShare,
          appliedCouponCode,
          discountApplied,
          shiftId || null,
          paymentMethodVal,
          paymentStatusVal,
          commResult.platformCommission,
          commResult.merchantNet,
          commResult.rateSnapshot,
          commResult.typeSnapshot,
        ]
      );

      const orderId = result.insertId;

      const creatorName = (req.user && (req.user.firstName || req.user.lastName))
        ? `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim()
        : 'العميل';

      await logStatusChange(conn, {
        orderId,
        userId: merchantId,
        userName: creatorName,
        userRole: 'merchant',
        previousStatus: null,
        newStatus: 'created',
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null
      });

      if (isAutoEnabled) {
        await logStatusChange(conn, {
          orderId,
          userId: null,
          userName: 'التحويل الآلي (النظام)',
          userRole: 'system',
          previousStatus: 'created',
          newStatus: 'Ready For Assignment',
          latitude: latitude ? parseFloat(latitude) : null,
          longitude: longitude ? parseFloat(longitude) : null
        });
      }

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
        notifyAdmins(io, '🛒 طلب جديد قيد المراجعة', `طلب جديد #${orderNumber} من ${senderName} بانتظار مراجعة وتأكيد الإدارة`, 'order_new', {
          type: 'order_new', orderId: orderId.toString(), orderNumber
        });
      } catch (_) { }

      // Emit real-time event with full order data to admins
      try {
        const io = req.app.get('io');
        const eventData = await fetchOrderEventData(orderId);
        const orderEventPayload = {
          orderId: orderId.toString(),
          id: orderId.toString(),
          orderNumber,
          shipmentId: null,
          shiftId: shiftId ? shiftId.toString() : null,
          captainId: null,
          orderType: 'regular',
          status: statusVal,
          merchantId: merchantId ? merchantId.toString() : null,
          clientName,
          phone,
          deliveryAddress,
          orderPrice: parseFloat(orderPrice),
          deliveryFee: finalDeliveryFee,
          totalAmount: parseFloat(orderPrice) + finalDeliveryFee,
          createdAt: new Date().toISOString(),
          ...(eventData || {})
        };
        if (io) {
          io.to('admins').emit('order_created', orderEventPayload);
          io.to('admins').emit('ORDER_CREATED', orderEventPayload);
          io.to('admins').emit('dashboard_update');
          // Note: Shift captains are NOT notified while in 'Pending Review'
        }
      } catch (_) { }

      res.status(201).json({
        status: 1,
        message: 'تم إرسال الطلب للإدارة بنجاح (قيد المراجعة)',
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
             m.profileImage as merchantProfileImage, m.phone as merchantPhone, m.storeName as merchantAddress,
             m.latitude as merchantLatitude, m.longitude as merchantLongitude,
             s.name as realStoreName, s.logo as realStoreLogo, s.address as realStoreAddress,
             c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone,
             c.latitude as captainLatitude, c.longitude as captainLongitude,
             a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
             COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = o.captainId), 1), 0.0) as captainAvgRating,
             (SELECT COUNT(*) FROM reviews WHERE revieweeId = o.captainId) as captainReviewCount,
             EXISTS(SELECT 1 FROM reviews WHERE reviews.orderId = o.id AND reviews.reviewerId = ?) as hasReviewed
      FROM orders o
      LEFT JOIN users m ON o.merchantId = m.id
      LEFT JOIN stores s ON (o.storeId = s.id OR (o.storeId IS NULL AND s.merchantId = o.merchantId AND s.deletedAt IS NULL))
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
    } else if (role === 'client') {
      sql += ' AND (o.clientId = ? OR o.phone = (SELECT phone FROM users WHERE id = ?))';
      params.push(userId, userId);
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
      deliveryFee: parseFloat(o.deliveryFee || 0),
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
      merchantName: o.realStoreName || o.merchantStoreName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : null),
      merchantAvatar: o.realStoreLogo || o.merchantProfileImage || null,
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
      orderType: o.orderType || (o.storeId ? 'store' : 'normal'),
      isStoreOrder: (o.orderType === 'store' || o.storeId !== null || !!o.storeOrderStatus),
      storeId: o.storeId ? o.storeId.toString() : null,
      storeOrderStatus: o.storeOrderStatus || (o.storeId ? 'NEW' : null),
      captainTripStatus: o.captainTripStatus || (o.storeId ? (o.captainId ? 'ASSIGNED' : 'PENDING_ASSIGNMENT') : null),
      acceptedAt: o.acceptedAt ? formatDate(o.acceptedAt) : null,
      readyAt: o.readyAt ? formatDate(o.readyAt) : null,
      handedOverAt: o.handedOverAt ? formatDate(o.handedOverAt) : null,
      captainAssignedAt: o.captainAssignedAt ? formatDate(o.captainAssignedAt) : null,
      captainHeadingToStoreAt: o.captainHeadingToStoreAt ? formatDate(o.captainHeadingToStoreAt) : null,
      pickedUpAt: o.pickedUpAt ? formatDate(o.pickedUpAt) : null,
      captainHeadingToClientAt: o.captainHeadingToClientAt ? formatDate(o.captainHeadingToClientAt) : null,
      deliveredAt: o.deliveredAt ? formatDate(o.deliveredAt) : null,
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
              m.profileImage as merchantProfileImage, m.phone as merchantPhone, m.storeName as merchantAddress,
              m.latitude as merchantLatitude, m.longitude as merchantLongitude,
              s.name as realStoreName, s.logo as realStoreLogo, s.address as realStoreAddress,
              c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone,
              c.latitude as captainLatitude, c.longitude as captainLongitude,
              a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
              COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = o.captainId), 1), 0.0) as captainAvgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = o.captainId) as captainReviewCount,
              EXISTS(SELECT 1 FROM reviews WHERE reviews.orderId = o.id AND reviews.reviewerId = ?) as hasReviewed
       FROM orders o
       LEFT JOIN users m ON o.merchantId = m.id
       LEFT JOIN stores s ON (o.storeId = s.id OR (o.storeId IS NULL AND s.merchantId = o.merchantId AND s.deletedAt IS NULL))
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

    const [orderItems] = await pool.query(
      'SELECT id, productId, productName, productImage, size, addons, quantity, unitPrice, totalPrice, notes FROM order_items WHERE orderId = ?',
      [o.id]
    );

    res.status(200).json({
      status: 1,
      data: {
        directPayment: directPayments.length > 0 ? directPayments[0] : null,
        items: orderItems || [],
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
        orderPrice: parseFloat(o.orderPrice || 0),
        deliveryFee: parseFloat(o.deliveryFee || 0),
        serviceFee: parseFloat(o.serviceFee || 0),
        tip: parseFloat(o.tip || 0),
        discountApplied: parseFloat(o.discountApplied || 0),
        couponCode: o.couponCode || null,
        platformCommission: parseFloat(o.platformCommission || 0),
        merchantNet: parseFloat(o.merchantNet || 0),
        totalAmount: parseFloat((
          parseFloat(o.orderPrice || 0) +
          parseFloat(o.deliveryFee || 0) +
          parseFloat(o.serviceFee || 0) +
          parseFloat(o.tip || 0) -
          parseFloat(o.discountApplied || 0)
        ).toFixed(2)),
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
        merchantName: o.realStoreName || o.merchantStoreName || (o.merchantFirstName ? `${o.merchantFirstName} ${o.merchantLastName}` : null),
        merchantAvatar: o.realStoreLogo || o.merchantProfileImage || null,
        merchantPhone: o.merchantPhone || null,
        captainName: o.captainFirstName ? `${o.captainFirstName} ${o.captainLastName}` : null,
        captainAvatar: o.captainProfileImage || null,
        captainPhone: o.captainPhone || null,
        captainAvgRating: parseFloat(o.captainAvgRating || 0.0),
        captainReviewCount: parseInt(o.captainReviewCount || 0),
        captainApprovalStatus: o.captainApprovalStatus || null,
        assignedAdminId: o.assignedAdminId ? o.assignedAdminId.toString() : null,
        isPaid: o.isPaid === 1 || o.isPaid === true,
        orderType: o.orderType || (o.storeId ? 'store' : 'normal'),
        isStoreOrder: (o.orderType === 'store' || o.storeId !== null),
        storeId: o.storeId || null,
        storeOrderStatus: o.storeOrderStatus || (o.storeId ? 'NEW' : null),
        captainTripStatus: o.captainTripStatus || (o.storeId ? (o.captainId ? 'ASSIGNED' : 'PENDING_ASSIGNMENT') : null),
        acceptedAt: o.acceptedAt ? formatDate(o.acceptedAt) : null,
        readyAt: o.readyAt ? formatDate(o.readyAt) : null,
        handedOverAt: o.handedOverAt ? formatDate(o.handedOverAt) : null,
        captainAssignedAt: o.captainAssignedAt ? formatDate(o.captainAssignedAt) : null,
        captainHeadingToStoreAt: o.captainHeadingToStoreAt ? formatDate(o.captainHeadingToStoreAt) : null,
        pickedUpAt: o.pickedUpAt ? formatDate(o.pickedUpAt) : null,
        captainHeadingToClientAt: o.captainHeadingToClientAt ? formatDate(o.captainHeadingToClientAt) : null,
        deliveredAt: o.deliveredAt ? formatDate(o.deliveredAt) : null,
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
      const platformShare = parseFloat(order.platformShare || (deliveryFee * 0.2));
      const orderPrice = parseFloat(order.orderPrice || 0);
      const isOnlinePaid = (order.isPaid === 1 || order.paymentStatus === 'paid' || ['kashier', 'online', 'card', 'wallet'].includes((order.paymentMethod || '').toLowerCase()));
      const finalStatus = 'Completed';

      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();

        await conn.query(
          `UPDATE orders 
           SET status = ?, 
               storeOrderStatus = 'completed',
               captainTripStatus = 'DELIVERED_SUCCESSFULLY',
               deliveredAt = COALESCE(deliveredAt, NOW()),
               completedAt = COALESCE(completedAt, NOW()),
               deliveryConfirmedAt = COALESCE(deliveryConfirmedAt, NOW()), 
               deliveryLatitude = ?, 
               deliveryLongitude = ? 
           WHERE id = ?`,
          [finalStatus, latitude ? parseFloat(latitude) : null, longitude ? parseFloat(longitude) : null, id]
        );

        if (isOnlinePaid) {
          // 1. الدفع الإلكتروني: الكابتن لم يستلم كاش - المنصة تودع نصيب الكابتن 80% في محفظته
          await conn.query(
            'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
            [captainShare, captainId]
          );

          const txTitleCaptain = `أرباح توصيل طلب إلكتروني #${order.orderNumber}`;
          await conn.query(
            "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
            [captainId, txTitleCaptain, captainShare, `#ORD${order.id}`]
          );

          // 2. إذا كان طلب متجر والتاجر موجود و orderPrice > 0: تودع المنصة قيمة المنتجات في محفظة المتجر
          if (order.merchantId && orderPrice > 0) {
            await conn.query(
              'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
              [orderPrice, order.merchantId]
            );

            const txTitleMerchant = `مستحقات بيع طلب إلكتروني #${order.orderNumber}`;
            await conn.query(
              "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
              [order.merchantId, txTitleMerchant, orderPrice, `#ORD${order.id}`]
            );
          }
        } else {
          // 1. الدفع عند الاستلام (كاش): الكابتن استلم 100% من رسوم التوصيل نقداً بيده + رسوم الخدمة + الإكرامية
          // المنصة تستحق: عمولة 20% + رسوم الخدمة + الإكرامية
          const serviceFee = parseFloat(order.serviceFee || 0);
          const tip = parseFloat(order.tip || 0);
          const totalPlatformDue = Math.round((platformShare + serviceFee + tip) * 100) / 100;

          if (totalPlatformDue > 0) {
            await conn.query(
              'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
              [totalPlatformDue, captainId]
            );

            const txTitleFee = `عمولة ورسوم المنصة (20% + خدمة + إكرامية) - طلب كاش #${order.orderNumber}`;
            await conn.query(
              "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'withdraw', 'success', 'cash_commission', ?)",
              [captainId, txTitleFee, totalPlatformDue, `#ORD${order.id}`]
            );
          }
        }

        await conn.commit();

        checkAndRewardReferral(order.merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
        checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));

        const io = req.app.get('io');
        if (io) {
          io.to(`order_${id}`).emit('statusUpdate', { status: finalStatus, storeOrderStatus: 'completed', captainTripStatus: 'DELIVERED_SUCCESSFULLY' });
          io.to(`order_${id}`).emit('store_order_status_update', {
            orderId: id,
            id: id,
            orderNumber: order.orderNumber,
            storeOrderStatus: 'completed',
            captainTripStatus: 'DELIVERED_SUCCESSFULLY',
            status: finalStatus,
            statusArabic: 'مكتمل'
          });
          io.to(`order_${id}`).emit('chat_deleted', { orderId: id });
          io.to('admins').emit('dashboard_update');
        }

        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) { }

        await pool.query('DELETE FROM messages WHERE orderId = ?', [id]);

        // Send notifications
        const [senderRows] = await pool.query('SELECT firstName, lastName, profileImage FROM users WHERE id = ?', [userId]);
        const senderName = senderRows.length > 0 ? (senderRows[0].storeName || `${senderRows[0].firstName} ${senderRows[0].lastName}`.trim()) : 'مستخدم';
        const [merchantRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [order.merchantId]);
        const merchantFcm = merchantRows.length > 0 ? merchantRows[0].fcmToken : null;
        const [captainRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [captainId]);
        const captainFcm = captainRows.length > 0 ? captainRows[0].fcmToken : null;

        if (isOnlinePaid) {
          sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `تم إكمال الطلب الإلكتروني #${order.orderNumber}. تم إيداع أرباح التوصيل (${captainShare} ج.م) في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: captainShare.toString() });
          if (order.merchantId && orderPrice > 0) {
            sendNotification(io, order.merchantId, 'تم تسليم الطلب وإيداع مستحقاتك 🎉', `تم إكمال الطلب #${order.orderNumber}. تم إيداع قيمة المنتجات (${orderPrice} ج.م) في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: orderPrice.toString() });
          } else if (order.merchantId) {
            sendNotification(io, order.merchantId, `تم تسليم الطلب #${order.orderNumber}`, 'تم تسليم الطلب للعميل بنجاح واكتمال العملية 🎉', 'order', { type: 'order_completed', orderId: id.toString() });
          }
        } else {
          sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `تم إكمال طلب الدفع عند الاستلام #${order.orderNumber}. تم تسجيل عمولة المنصة 20% (${platformShare} ج.م) على محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: platformShare.toString() });
          if (order.merchantId) {
            sendNotification(io, order.merchantId, `تم تسليم الطلب #${order.orderNumber}`, 'تم تسليم الطلب للعميل بنجاح واستلام قيمته نقداً 🎉', 'order', { type: 'order_completed', orderId: id.toString() });
          }
        }

        // Notify client (صاحب الطلب)
        if (order.clientId) {
          sendNotification(
            io,
            order.clientId,
            '🎉 تم تسليم طلبك بنجاح',
            `تم إكمال تسليم طلبك #${order.orderNumber} بنجاح. شكراً لاستخدامك تطبيقنا ونتمنى لك تجربة ممتعة!`,
            'order',
            { type: 'order_completed', orderId: id.toString(), orderNumber: order.orderNumber }
          );
          if (io) {
            io.to(`user_${order.clientId}`).emit('order_status_update', {
              orderId: id.toString(),
              orderNumber: order.orderNumber,
              status: finalStatus
            });
          }
        }

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
      sql = "UPDATE orders SET status = 'Ready For Assignment', captainId = NULL, captainApprovalStatus = NULL";
      queryParams.length = 0;
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
      sql += ', storeOrderStatus = "picked_up", captainTripStatus = "ORDER_PICKED_UP", pickupConfirmedAt = NOW(), pickupLatitude = ?, pickupLongitude = ?';
      queryParams.push(latitude ? parseFloat(latitude) : null);
      queryParams.push(longitude ? parseFloat(longitude) : null);
    } else if (['Cancelled', 'cancelled', 'ملغي', 'ملغى'].includes(status)) {
      sql += ', storeOrderStatus = "cancelled", captainTripStatus = "CANCELLED"';
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
    const clientId = order.clientId;

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
    const clientFcm = await fetchFcm(clientId);

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
      const isCancelled = ['cancelled', 'ملغي', 'ملغية'].includes(status.toString().trim().toLowerCase());
      io.to(`order_${id}`).emit('statusUpdate', { status, isCancelled });
      io.to('admins').emit('dashboard_update');

      if (clientId) {
        io.to(`user_${clientId}`).emit('order_status_update', { orderId: id.toString(), orderNumber: order.orderNumber, status });
      }
      if (merchantId) {
        io.to(`user_${merchantId}`).emit('order_status_update', { orderId: id.toString(), orderNumber: order.orderNumber, status });
        io.to(`merchant_${merchantId}`).emit('order_status_update', { orderId: id.toString(), orderNumber: order.orderNumber, status });
      }
      if (captainId) {
        io.to(`user_${captainId}`).emit('order_status_update', { orderId: id.toString(), orderNumber: order.orderNumber, status });
        io.to(`captain_${captainId}`).emit('order_status_update', { orderId: id.toString(), orderNumber: order.orderNumber, status });
      }

      if (isCancelled) {
        if (captainId) {
          io.to(`user_${captainId}`).emit('order_cancelled', { orderId: id.toString(), orderNumber: order.orderNumber });
          io.to(`captain_${captainId}`).emit('order_cancelled', { orderId: id.toString(), orderNumber: order.orderNumber });
        }
        if (clientId) {
          io.to(`user_${clientId}`).emit('order_cancelled', { orderId: id.toString(), orderNumber: order.orderNumber });
        }
      }
    }

    // Emit granular order_updated event with full data
    try {
      const eventData = await fetchOrderEventData(id);
      if (eventData && io) {
        io.to('admins').emit('order_updated', eventData);
      }
    } catch (_) { }

    // Handle notifications based on new status — all statuses covered for all 3 parties
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');

      if (['captain arrived', 'في الطريق للاستلام', 'فى الطريق للاستلام'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `الكابتن في الطريق للاستلام 📍`,
          `المندوب ${senderName} في الطريق لموقع استلام وشراء الطلب #${order.orderNumber}.`,
          { type: 'captain_arrived' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `الكابتن متجه للمتجر 📍`,
            `الكابتن ${senderName} في طريقه الآن إلى المتجر لاستلام وتجهيز طلبك #${order.orderNumber}.`,
            { type: 'captain_arrived' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `أنت في الطريق للاستلام 📍`,
            `توجه إلى موقع المتجر لاستلام وتجهيز الطلب #${order.orderNumber}.`,
            { type: 'captain_arrived' }
          );
        }
        await notifyAdmins(io, '📍 الكابتن في الطريق للاستلام',
          `الكابتن ${senderName} في الطريق لموقع استلام الطلب #${order.orderNumber}`,
          'captain_arrived', { type: 'captain_arrived', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['picked up', 'تم شراء الطلبات', 'تم استلام الطلب', 'تم الشراء', 'جاهز للتوصيل', 'جاهز'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `تم شراء واستلام الطلب 🛒`,
          `قام المندوب ${senderName} باستلام طلبك #${order.orderNumber} وتجهيزه للتوصيل.`,
          { type: 'order_picked_up' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `🛍️ طلبك جاهز واستلمه الكابتن`,
            `قام الكابتن ${senderName} باستلام وتجهيز طلبك #${order.orderNumber} وهو جاهز الآن للانطلاق!`,
            { type: 'order_picked_up' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `📦 تم تجهيز واستلام الطلب`,
            `تم تسجيل استلام وتجهيز الطلب #${order.orderNumber}. ابدأ التحرك لتوصيله للعميل.`,
            { type: 'order_picked_up' }
          );
        }
        await notifyAdmins(io, '🛒 تم شراء الطلب',
          `الكابتن ${senderName} شرى الطلب #${order.orderNumber}`,
          'order_picked_up', { type: 'order_picked_up', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['in transit', 'ongoing', 'فى الطريق للتسليم', 'في الطريق للتسليم', 'خرج للتوصيل'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `الطلب خرج للتوصيل 🛵`,
          `المندوب ${senderName} في طريقه لتوصيل طلبك #${order.orderNumber} إلى العميل.`,
          { type: 'order_in_transit' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `🛵💨 طلبك خرج للتوصيل!`,
            `الكابتن ${senderName} خرج بالطلب #${order.orderNumber} وهو في طريقه إليك الآن. استعد للاستلام!`,
            { type: 'order_in_transit' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `🛵 أنت في الطريق للتسليم`,
            `رحلة توصيل الطلب #${order.orderNumber} جارية الآن إلى موقع العميل.`,
            { type: 'order_in_transit' }
          );
        }
        await notifyAdmins(io, '🛵 طلب في الطريق للتسليم',
          `الطلب #${order.orderNumber} جارٍ توصيله بواسطة ${senderName}`,
          'order_in_transit', { type: 'order_in_transit', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['delivered', 'تم التوصيل بنجاح', 'تم التسليم بنجاح', 'تم التسليم'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `وصل الطلب للعميل 🎉`,
          `وصل المندوب بطلبك #${order.orderNumber} إلى موقع العميل. يرجى تأكيد استلام الطلب.`,
          { type: 'order_delivered' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `🎉 وصل الكابتن إلى موقعك!`,
            `وصل الكابتن ${senderName} ومعه طلبك #${order.orderNumber}. يرجى استلام طلبك وتأكيد الاستلام.`,
            { type: 'order_delivered' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `✅ تم تسجيل الوصول والتسليم`,
            `تم تسجيل وصولك وتسليم الطلب #${order.orderNumber} بنجاح. بانتظار التأكيد النهائي.`,
            { type: 'order_delivered' }
          );
        }
        await notifyAdmins(io, '✅ طلب تم توصيله',
          `الكابتن ${senderName} وصل الطلب #${order.orderNumber}`,
          'order_delivered', { type: 'order_delivered', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['completed', 'مكتمل', 'مكتملة', 'منتهية'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `اكتمل طلبك بنجاح 🎉`,
          `تم إكمال طلبك #${order.orderNumber} بنجاح واكتمال العملية.`,
          { type: 'order_completed' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `🎉 تم تسليم طلبك بنجاح`,
            `تم إكمال تسليم طلبك #${order.orderNumber} بنجاح. شكراً لاستخدامك تطبيقنا ونتمنى لك يوماً رائعاً!`,
            { type: 'order_completed' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `تم تأكيد التوصيل واكتمال الطلب ✅`,
            `أكد العميل/التاجر استلام الطلب #${order.orderNumber}. تم إيداع أرباحك في المحفظة.`,
            { type: 'order_completed' }
          );
        }
        await notifyAdmins(io, '✅ طلب مكتمل',
          `الطلب #${order.orderNumber} تم إكماله بنجاح`,
          'order_completed', { type: 'order_completed', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['cancelled', 'ملغي', 'ملغية'].includes(norm(status))) {
        // 1. Merchant
        await notify(merchantFcm, merchantId,
          `❌ تم إلغاء الطلب`,
          `تم إلغاء الطلب #${order.orderNumber}.`,
          { type: 'order_cancelled' }
        );
        // 2. Client
        if (clientId) {
          await notify(clientFcm, clientId,
            `❌ تم إلغاء الطلب`,
            `تم إلغاء طلبك #${order.orderNumber}.`,
            { type: 'order_cancelled' }
          );
        }
        // 3. Captain
        if (captainId) {
          await notify(captainFcm, captainId,
            `❌ تم إلغاء الطلب`,
            `تم إلغاء مهمة توصيل الطلب #${order.orderNumber}.`,
            { type: 'order_cancelled' }
          );
        }
        await notifyAdmins(io, '❌ طلب ملغي',
          `الطلب #${order.orderNumber} تم إلغاؤه`,
          'order_cancelled', { type: 'order_cancelled', orderId: id.toString(), orderNumber: order.orderNumber },
          userId
        );
      } else if (['pending review', 'بانتظار القبول'].includes(norm(status))) {
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
      // Notify shift captains if linked
      try {
        const [oRows] = await pool.query('SELECT shift_id, orderNumber, orderPrice, deliveryFee FROM orders WHERE id = ?', [id]);
        if (oRows.length > 0 && oRows[0].shift_id && io) {
          const shiftId = oRows[0].shift_id;
          const payload = { id: id.toString(), type: 'order', orderNumber: oRows[0].orderNumber, status: 'Ready For Assignment' };
          io.to(`shift_${shiftId}`).emit('ORDER_CREATED', payload);
          io.to(`shift:${shiftId}`).emit('ORDER_CREATED', payload);
        }
      } catch (_) {}
      if (io) io.to('admins').emit('dashboard_update');
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
    } catch (_) { }

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
    const userId = req.user.id;
    const role = req.user.role;

    const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (orders.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
    }

    const order = orders[0];
    if (Number(order.merchantId) !== Number(userId) && Number(order.captainId) !== Number(userId) && !['admin', 'employee'].includes(role)) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتأكيد تسليم هذا الطلب' });
    }

    const allowedStatuses = ['picked up', 'in transit', 'delivered', 'completed', 'تم شراء الطلبات', 'تم استلام الطلب', 'في الطريق للتسليم', 'فى الطريق للتسليم', 'تم التوصيل بنجاح', 'تم التسليم بنجاح', 'مكتمل'];
    if (!allowedStatuses.includes(norm(order.status))) {
      return res.status(400).json({ status: 0, message: 'لا يمكن تأكيد تسليم الطلب في الحالة الحالية' });
    }

    const newStatus = 'Completed';
    const captainId = order.captainId || (role === 'captain' ? userId : null);

    if (!captainId) {
      return res.status(400).json({ status: 0, message: 'لا يوجد كابتن معين لهذا الطلب' });
    }

    const deliveryFee = parseFloat(order.deliveryFee || 0);
    const captainShare = parseFloat(order.captainShare || (deliveryFee * 0.8));
    const platformShare = parseFloat(order.platformShare || (deliveryFee * 0.2));
    const orderPrice = parseFloat(order.orderPrice || 0);
    const isOnlinePaid = (order.isPaid === 1 || order.paymentStatus === 'paid' || ['kashier', 'online', 'card', 'wallet'].includes((order.paymentMethod || '').toLowerCase()));

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

      if (isOnlinePaid) {
        // 1. الدفع الإلكتروني: الكابتن لم يستلم كاش - المنصة تودع نصيب الكابتن 80% في محفظته
        await conn.query(
          'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
          [captainShare, captainId]
        );

        const txTitleCaptain = `أرباح توصيل طلب إلكتروني #${order.orderNumber}`;
        await conn.query(
          "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
          [captainId, txTitleCaptain, captainShare, `#ORD${order.id}`]
        );

        // 2. إذا كان طلب متجر والتاجر موجود و orderPrice > 0: تودع المنصة قيمة المنتجات في محفظة المتجر
        if (order.merchantId && orderPrice > 0) {
          await conn.query(
            'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
            [orderPrice, order.merchantId]
          );

          const txTitleMerchant = `مستحقات بيع طلب إلكتروني #${order.orderNumber}`;
          await conn.query(
            "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
            [order.merchantId, txTitleMerchant, orderPrice, `#ORD${order.id}`]
          );
        }
      } else {
        // 1. الدفع عند الاستلام (كاش): الكابتن استلم 100% من رسوم التوصيل نقداً بيده + رسوم الخدمة + الإكرامية
        // المنصة تستحق: عمولة 20% + رسوم الخدمة + الإكرامية
        const serviceFee = parseFloat(order.serviceFee || 0);
        const tip = parseFloat(order.tip || 0);
        const totalPlatformDue = Math.round((platformShare + serviceFee + tip) * 100) / 100;

        if (totalPlatformDue > 0) {
          await conn.query(
            'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
            [totalPlatformDue, captainId]
          );

          const txTitleFee = `عمولة ورسوم المنصة (20% + خدمة + إكرامية) - طلب كاش #${order.orderNumber}`;
          await conn.query(
            "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'withdraw', 'success', 'cash_commission', ?)",
            [captainId, txTitleFee, totalPlatformDue, `#ORD${order.id}`]
          );
        }
      }

      await conn.commit();

      await logStatusChange(pool, {
        orderId: id,
        userId: userId,
        userName: role === 'admin' ? 'المدير' : (role === 'captain' ? 'الكابتن' : 'التاجر'),
        userRole: role,
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
      } catch (_) { }

      await pool.query('DELETE FROM messages WHERE orderId = ?', [id]);

      if (isOnlinePaid) {
        sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `تم تأكيد تسليم الطلب الإلكتروني #${order.orderNumber}. تم إيداع ${captainShare} ج.م في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: captainShare.toString() });
        if (order.merchantId && orderPrice > 0) {
          sendNotification(io, order.merchantId, 'تم تسليم الطلب وإيداع مستحقاتك 🎉', `تم إكمال الطلب #${order.orderNumber}. تم إيداع قيمة المنتجات (${orderPrice} ج.م) في محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: orderPrice.toString() });
        } else if (order.merchantId) {
          sendNotification(io, order.merchantId, `تم تسليم الطلب #${order.orderNumber}`, 'تم تسليم الطلب للعميل بنجاح واكتمال العملية 🎉', 'order', { type: 'order_completed', orderId: id.toString() });
        }
      } else {
        sendNotification(io, captainId, 'تم تأكيد تسليم الطلب 🎉', `تم تأكيد تسليم الطلب الكاش #${order.orderNumber}. تم تسجيل عمولة المنصة 20% (${platformShare} ج.م) على محفظتك.`, 'order', { type: 'order_completed', orderId: id.toString(), amount: platformShare.toString() });
        if (order.merchantId) {
          sendNotification(io, order.merchantId, `تم تسليم الطلب #${order.orderNumber}`, 'تم تسليم الطلب للعميل بنجاح واستلام قيمته نقداً 🎉', 'order', { type: 'order_completed', orderId: id.toString() });
        }
      }

      // Notify Client (صاحب الطلب)
      if (order.clientId) {
        sendNotification(
          io,
          order.clientId,
          '🎉 تم تسليم طلبك بنجاح',
          `تم إكمال تسليم طلبك #${order.orderNumber} بنجاح. شكراً لثقتك بنا ونتمنى لك تجربة رائعة!`,
          'order',
          { type: 'order_completed', orderId: id.toString(), orderNumber: order.orderNumber }
        );
        if (io) {
          io.to(`user_${order.clientId}`).emit('order_status_update', {
            orderId: id.toString(),
            orderNumber: order.orderNumber,
            status: newStatus
          });
        }
      }

      res.status(200).json({
        status: 1,
        message: 'تم تأكيد تسليم الطلب بنجاح وتسوية المعاملة المالية في المحفظة'
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

      const isPending = order.captainApprovalStatus === 'pending' || 
                        order.status === 'في انتظار المندوب' || 
                        order.status === 'بانتظار القبول' || 
                        order.status === 'في انتظار القبول' ||
                        order.status === 'assigned to captain';

      if (!isPending) {
        await conn.rollback();
        return res.status(400).json({ status: 0, message: 'تم الرد على هذا التكليف مسبقاً أو غير معلق' });
      }

      const targetRoom = `order_${id}`;
      const io = req.app.get('io');

      // Fetch captain's real name from DB (not in JWT)
      const [captainRows] = await conn.query('SELECT firstName, lastName FROM users WHERE id = ?', [captainId]);
      const captainName = captainRows.length > 0 ? `${captainRows[0].firstName || ''} ${captainRows[0].lastName || ''}`.trim() : 'كابتن';

      if (response === 'accept') {
        const newAcceptedStatus = 'جاري التنفيذ';
        const [updateResult] = await conn.query(
          `UPDATE orders 
           SET captainApprovalStatus = 'accepted', 
               status = ?,
               shift_id = COALESCE(shift_id, (SELECT sc.shiftId FROM shift_captains sc JOIN shifts s ON sc.shiftId = s.id WHERE sc.captainId = ? AND s.status = 'active' AND sc.clockInTime IS NOT NULL AND sc.clockOutTime IS NULL LIMIT 1))
           WHERE id = ? AND captainId = ?`,
          [newAcceptedStatus, captainId, id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف متاحاً لك حالياً' });
        }

        await conn.commit();

        try {
          const { resolveAttempt } = require('../utils/autoAssignment');
          await resolveAttempt(pool, { orderId: id, captainId, status: 'accepted', reason: 'Captain accepted assignment' });
        } catch (_) {}

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: newAcceptedStatus, captainId });
          io.to(targetRoom).emit('captain_response', { response: 'accept', captainId });
          if (order.merchantId) {
            io.to(`user_${order.merchantId}`).emit('order_status_update', {
              orderId: id.toString(),
              orderNumber: order.orderNumber,
              status: newAcceptedStatus,
              captainId,
              captainName
            });
          }
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

        // Notify Merchant immediately about captain acceptance
        if (order.merchantId) {
          try {
            await sendNotification(
              io,
              order.merchantId,
              `الكابتن قبل طلبك #${order.orderNumber} 🛵`,
              `قام الكابتن ${captainName} بقبول مهمة توصيل الطلب #${order.orderNumber} وهو في الطريق للاستلام والتوصيل.`,
              'order',
              {
                type: 'captain_accepted',
                orderId: id.toString(),
                orderNumber: order.orderNumber,
                captainId: captainId.toString(),
                captainName
              }
            );
          } catch (mErr) {
            console.error('Error notifying merchant of captain acceptance:', mErr);
          }
        }

        // Notify Client immediately about captain acceptance
        if (order.clientId) {
          try {
            await sendNotification(
              io,
              order.clientId,
              `🛵 تم قبول طلبك من الكابتن`,
              `قام الكابتن ${captainName} بقبول توصيل طلبك #${order.orderNumber} وبدأ في التحرك لتنفيذه.`,
              'order',
              {
                type: 'captain_accepted',
                orderId: id.toString(),
                orderNumber: order.orderNumber,
                captainId: captainId.toString(),
                captainName
              }
            );
            if (io) {
              io.to(`user_${order.clientId}`).emit('order_status_update', {
                orderId: id.toString(),
                orderNumber: order.orderNumber,
                status: newAcceptedStatus,
                captainId,
                captainName
              });
            }
          } catch (cErr) {
            console.error('Error notifying client of captain acceptance:', cErr);
          }
        }

        // Emit granular order_updated event
        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) { }

        res.status(200).json({
          status: 1,
          message: 'تم قبول تكليف الطلب بنجاح',
          data: { status: newAcceptedStatus }
        });
      } else {
        // Reject: reset captainId, captainApprovalStatus, and return status to 'جديد'
        const resetStatus = 'جديد';
        const [updateResult] = await conn.query(
          "UPDATE orders SET captainId = NULL, captainApprovalStatus = NULL, status = ? WHERE id = ? AND captainId = ?",
          [resetStatus, id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف معلقاً لديك' });
        }

        await conn.commit();

        try {
          const { resolveAttempt, triggerAutoAssignment } = require('../utils/autoAssignment');
          await resolveAttempt(pool, { orderId: id, captainId, status: 'rejected', reason: 'Captain rejected assignment' });
          triggerAutoAssignment(null, id).catch(err => console.error('Error triggering auto assignment after reject:', err.message));
        } catch (_) {}

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: resetStatus, captainId: null });
          io.to(targetRoom).emit('captain_response', { response: 'reject', captainId });
          if (order.merchantId) {
            io.to(`user_${order.merchantId}`).emit('order_status_update', {
              orderId: id.toString(),
              orderNumber: order.orderNumber,
              status: resetStatus,
              captainId: null,
              message: `اعتذر الكابتن ${captainName} عن التوصيل`
            });
          }
          io.to('admins').emit('dashboard_update');
        }

        // Notify merchant about rejection so they can re-assign
        if (order.merchantId) {
          try {
            await sendNotification(
              io,
              order.merchantId,
              `اعتذار الكابتن عن الطلب #${order.orderNumber} ⚠️`,
              `اعتذر الكابتن ${captainName} عن استلام الطلب #${order.orderNumber}. يمكنك الآن تعيين كابتن آخر للتوصيل.`,
              'order',
              {
                type: 'captain_rejected',
                orderId: id.toString(),
                orderNumber: order.orderNumber,
                captainId: captainId.toString(),
                captainName
              }
            );
          } catch (_) {}
        }

        // Notify all admins
        try {
          const { notifyAdmins } = require('../utils/adminNotifier');
          const orderPrice = parseFloat(order.orderPrice || 0).toFixed(2);
          notifyAdmins(io,
            `❌ رفض تكليف طلب #${order.orderNumber}`,
            `الكابتن ${captainName} رفض تكليف الطلب رقم ${order.orderNumber} بقيمة ${orderPrice} ج.م`,
            'system',
            { type: 'captain_rejected', orderId: id.toString(), orderNumber: order.orderNumber, captainName, price: orderPrice }
          );
        } catch (_) {}

        // Emit granular order_updated event
        try {
          const eventData = await fetchOrderEventData(id);
          if (eventData && io) {
            io.to('admins').emit('order_updated', eventData);
          }
        } catch (_) { }

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
    } catch (_) { }

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
    const isAdminOrEmp = req.user.role === 'admin' || req.user.role === 'employee';
    const userId = req.user.id;

    let orders;
    if (isAdminOrEmp) {
      const [rows] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
      orders = rows;
    } else {
      const [rows] = await pool.query(
        'SELECT * FROM orders WHERE id = ? AND merchantId = ?',
        [id, userId]
      );
      orders = rows;
    }

    if (orders.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الطلب غير موجود أو لا تملك صلاحية تعديله'
      });
    }

    const order = orders[0];
    if (!isAdminOrEmp && order.status !== 'Pending Review') {
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
      longitude,
      merchantId
    } = req.body;

    if (!details || !storeDescription || !deliveryAddress || !clientName || !phone || orderPrice === undefined || deliveryFee === undefined) {
      return res.status(400).json({
        status: 0,
        message: 'الحقول الأساسية مطلوبة'
      });
    }

    const updatedMerchantId = (isAdminOrEmp && merchantId) ? parseInt(merchantId, 10) : order.merchantId;
    const updatedStoreId = req.body.storeId !== undefined ? (req.body.storeId ? parseInt(req.body.storeId, 10) : null) : order.storeId;
    const updatedClientId = req.body.clientId !== undefined ? (req.body.clientId ? parseInt(req.body.clientId, 10) : null) : order.clientId;

    await pool.query(
      `UPDATE orders SET 
        details = ?, storeDescription = ?, notes = ?, 
        deliveryAddress = ?, clientName = ?, phone = ?, 
        orderPrice = ?, deliveryFee = ?, 
        latitude = ?, longitude = ?,
        merchantId = ?, storeId = ?, clientId = ?
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
        updatedMerchantId,
        updatedStoreId,
        updatedClientId,
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
    } catch (_) { }

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

