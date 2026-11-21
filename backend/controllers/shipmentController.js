const { getPool } = require('../config/db');
const { assertShipmentAccess } = require('../utils/accessControl');
const { assertShipmentStatusTransition } = require('../utils/statusTransitions');
const { sendNotification } = require('../utils/notificationDispatcher');
const { checkAndRewardReferral } = require('../utils/referralHelper');
const { logStatusChange, getStatusLogs } = require('../utils/statusLogger');


// Helper to format date for response or queries
const formatDate = (date) => {
  if (!date) return null;
  return new Date(date).toISOString();
};

async function fetchShipmentEventData(id) {
  const pool = getPool();
  const [rows] = await pool.query(`
    SELECT s.*,
      COALESCE(s.merchantPhone, m.phone) as resolvedMerchantPhone,
      m.storeName as merchantName,
      m.firstName as merchantFirstName,
      m.lastName as merchantLastName,
      COALESCE(s.merchantLatitude, m.latitude) as resolvedMerchantLatitude,
      COALESCE(s.merchantLongitude, m.longitude) as resolvedMerchantLongitude,
      a.firstName as assignedAdminFirstName,
      a.lastName as assignedAdminLastName
    FROM shipments s
    LEFT JOIN users m ON s.merchantId = m.id
    LEFT JOIN users a ON s.assignedAdminId = a.id
    WHERE s.id = ?
  `, [id]);
  if (rows.length === 0) return null;
  const s = rows[0];

  const [images] = await pool.query(
    'SELECT imageUrl FROM shipment_images WHERE shipmentId = ?',
    [s.id]
  );

  return {
    id: s.id.toString(),
    shipmentNumber: s.shipmentNumber,
    merchantId: s.merchantId ? s.merchantId.toString() : null,
    merchantPhone: s.resolvedMerchantPhone || null,
    clientPhone: s.resolvedMerchantPhone || null,
    captainId: s.captainId ? s.captainId.toString() : null,
    tripId: s.trip_id ? s.trip_id.toString() : null,
    title: s.title || '',
    fromAddress: s.fromAddress,
    toAddress: s.toAddress,
    fromGovernorate: s.fromGovernorate || '',
    fromArea: s.fromArea || '',
    toGovernorate: s.toGovernorate || '',
    toArea: s.toArea || '',
    merchantLatitude: s.resolvedMerchantLatitude ? parseFloat(s.resolvedMerchantLatitude) : null,
    merchantLongitude: s.resolvedMerchantLongitude ? parseFloat(s.resolvedMerchantLongitude) : null,
    toLatitude: s.toLatitude ? parseFloat(s.toLatitude) : null,
    toLongitude: s.toLongitude ? parseFloat(s.toLongitude) : null,
    goodsPrice: parseFloat(s.goodsPrice || 0),
    price: parseFloat(s.price || 0),
    weight: s.weight ? parseFloat(s.weight) : null,
    notes: s.notes || '',
    isWithoutAdvance: s.isWithoutAdvance === 1 || s.isWithoutAdvance === true,
    images: images.map(img => img.imageUrl),
    merchantName: s.merchantName || (s.merchantFirstName ? `${s.merchantFirstName} ${s.merchantLastName}` : ''),
    status: s.status,
    assignedAdminId: s.assignedAdminId ? s.assignedAdminId.toString() : null,
    assignedAdminName: s.assignedAdminFirstName ? `${s.assignedAdminFirstName} ${s.assignedAdminLastName}`.trim() : null,
    createdAt: formatDate(s.createdAt),
    updatedAt: formatDate(s.updatedAt),
  };
}

// 1. CREATE SHIPMENT (Merchant, Admin, Employee)
const createShipment = async (req, res, next) => {
  try {
    const pool = getPool();
    const isAdminOrEmp = req.user.role === 'admin' || req.user.role === 'employee';
    const merchantId = (isAdminOrEmp && req.body.merchantId) ? parseInt(req.body.merchantId, 10) : req.user.id;

    // Check operating hours & service availability (admin/employee can bypass)
    if (!isAdminOrEmp) {
      const { checkServiceAvailability } = require('../utils/serviceHoursHelper');
      const serviceCheck = await checkServiceAvailability('shipments');
      if (!serviceCheck.isOpen) {
        if (req.files && req.files.length > 0) {
          const fs = require('fs');
          const path = require('path');
          for (const file of req.files) {
            try {
              fs.unlinkSync(path.join(__dirname, '..', 'uploads', file.filename));
            } catch (_) {}
          }
        }
        return res.status(400).json({
          status: 0,
          code: 'SERVICE_CLOSED',
          message: serviceCheck.reason || 'خدمة الشحن غير متاحة حالياً نظراً لانتهاء مواعيد العمل اليومية.'
        });
      }
    }

    const {
      title,
      merchantPhone,
      fromAddress,
      toAddress,
      fromGovernorate,
      fromArea,
      toGovernorate,
      toArea,
      goodsPrice,
      itemPrice,
      price,
      weight,
      notes,
      isFragile,
      isWithoutAdvance,
      toLatitude,
      toLongitude,
      merchantLatitude,
      merchantLongitude,
      tripId,
      couponCode
    } = req.body;

    const hasImages = req.files && req.files.length > 0;
    if (!title || title.trim().length === 0 || (!isAdminOrEmp && !hasImages) || !fromAddress || !toAddress || !price) {
      if (hasImages) {
        const fs = require('fs');
        const path = require('path');
        for (const file of req.files) {
          try {
            fs.unlinkSync(path.join(__dirname, '..', 'uploads', file.filename));
          } catch (_) {}
        }
      }

      let msg = 'عنوان الاستلام، عنوان التسليم، وسعر التوصيل مطلوبة';
      if (!title || title.trim().length === 0) {
        msg = 'محتوى الشحنة مطلوب';
      } else if (!hasImages && !isAdminOrEmp) {
        msg = 'صورة الشحنة مطلوبة';
      }

      return res.status(400).json({
        status: 0,
        message: msg
      });
    }

    // Generate unique shipment number
    const shipmentNumber = 'H' + Date.now().toString().substring(5) + Math.floor(100 + Math.random() * 900);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Resolve merchant phone if not explicitly provided
      let finalMerchantPhone = merchantPhone ? merchantPhone.toString().trim() : null;
      if (!finalMerchantPhone) {
        const [mRows] = await conn.query('SELECT phone FROM users WHERE id = ?', [merchantId]);
        if (mRows.length > 0 && mRows[0].phone) {
          finalMerchantPhone = mRows[0].phone;
        }
      }

      // Check if auto-assignment is enabled
      const [autoSettings] = await conn.query(
        "SELECT `value` FROM app_settings WHERE `key` = 'enable_auto_assignment'"
      );
      const isAutoEnabled = autoSettings.length > 0 && autoSettings[0].value === '1';

      // 1. Calculate price and coupon
      let finalPrice = parseFloat(price);
      let discountApplied = 0.00;
      let appliedCouponCode = null;

      if (couponCode && couponCode.trim().length > 0) {
        const { processCoupon } = require('../utils/couponHelper');
        try {
          const couponResult = await processCoupon(conn, {
            code: couponCode,
            price: finalPrice,
            userId: merchantId,
            isShipment: true,
            entityId: null
          });
          discountApplied = couponResult.discountApplied;
          appliedCouponCode = couponResult.couponCode;
          finalPrice = Math.max(finalPrice - discountApplied, 0.00);
        } catch (couponErr) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: couponErr.message });
        }
      }

      // All shipments start in 'Pending Review' for admin confirmation
      const statusVal = 'Pending Review';
      const platformShare = finalPrice * 0.20;
      const captainShare = finalPrice * 0.80;

      const isNoAdvance = isWithoutAdvance === 'true' || isWithoutAdvance === true || isWithoutAdvance === 1;
      const finalGoodsPrice = isNoAdvance ? 0.00 : (parseFloat(goodsPrice || itemPrice || 0) || 0.00);

      const serviceFee = req.body.serviceFee !== undefined ? (parseFloat(req.body.serviceFee) || 0.00) : 0.00;
      const tip = req.body.tip !== undefined ? (parseFloat(req.body.tip) || 0.00) : 0.00;

      const { findActiveShiftForOrder } = require('../utils/shiftMatcher');
      const shiftId = await findActiveShiftForOrder({
        merchantId,
        serviceArea: fromArea || fromGovernorate,
        conn,
      });

      const [result] = await conn.query(
        `INSERT INTO shipments (
          shipmentNumber, merchantId, merchantPhone, title, fromAddress, toAddress, 
          fromGovernorate, fromArea, toGovernorate, toArea, 
          price, goodsPrice, serviceFee, tip, weight, notes, isFragile, isWithoutAdvance, 
          toLatitude, toLongitude, merchantLatitude, merchantLongitude, trip_id, status,
          platformShare, captainShare, autoAssignmentFailed, couponCode, discountApplied, shift_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)`,
        [
          shipmentNumber,
          merchantId,
          finalMerchantPhone,
          title || null,
          fromAddress,
          toAddress,
          fromGovernorate || null,
          fromArea || null,
          toGovernorate || null,
          toArea || null,
          finalPrice,
          finalGoodsPrice,
          serviceFee,
          tip,
          weight ? parseFloat(weight) : null,
          notes || null,
          isFragile === 'true' || isFragile === true || isFragile === 1 ? 1 : 0,
          isNoAdvance ? 1 : 0,
          toLatitude ? parseFloat(toLatitude) : null,
          toLongitude ? parseFloat(toLongitude) : null,
          merchantLatitude ? parseFloat(merchantLatitude) : null,
          merchantLongitude ? parseFloat(merchantLongitude) : null,
          tripId ? parseInt(tripId) : null,
          statusVal,
          platformShare,
          captainShare,
          appliedCouponCode,
          discountApplied,
          shiftId || null,
        ]
      );

      const shipmentId = result.insertId;

      const creatorName = (req.user && (req.user.firstName || req.user.lastName))
        ? `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim()
        : 'العميل';

      await logStatusChange(conn, {
        shipmentId,
        userId: merchantId,
        userName: creatorName,
        userRole: 'merchant',
        previousStatus: null,
        newStatus: 'created',
        latitude: merchantLatitude ? parseFloat(merchantLatitude) : null,
        longitude: merchantLongitude ? parseFloat(merchantLongitude) : null
      });

      if (isAutoEnabled) {
        await logStatusChange(conn, {
          shipmentId,
          userId: null,
          userName: 'التحويل الآلي (النظام)',
          userRole: 'system',
          previousStatus: 'created',
          newStatus: 'Ready For Assignment',
          latitude: merchantLatitude ? parseFloat(merchantLatitude) : null,
          longitude: merchantLongitude ? parseFloat(merchantLongitude) : null
        });
      }

      // Update coupon_usages table with actual shipmentId
      if (appliedCouponCode) {
        await conn.query(
          "UPDATE coupon_usages SET shipmentId = ? WHERE userId = ? AND shipmentId IS NULL AND orderId IS NULL ORDER BY usedAt DESC LIMIT 1",
          [shipmentId, merchantId]
        );
      }

      // Handle multiple uploaded files
      const imageUrls = [];
      if (req.files && req.files.length > 0) {
        for (const file of req.files) {
          const imageUrl = `/uploads/${file.filename}`;
          imageUrls.push(imageUrl);
          await conn.query(
            'INSERT INTO shipment_images (shipmentId, imageUrl) VALUES (?, ?)',
            [shipmentId, imageUrl]
          );
        }
      }

      await conn.commit();

      // Notify admins about new shipment
      try {
        const { notifyAdmins } = require('../utils/adminNotifier');
        const io = req.app.get('io');
        const [merchant] = await pool.query('SELECT storeName, firstName, lastName FROM users WHERE id = ?', [merchantId]);
        const m = merchant[0] || {};
        const senderName = m.storeName || `${m.firstName || ''} ${m.lastName || ''}`.trim() || 'تاجر';
        notifyAdmins(io, '📦 شحنة جديدة قيد المراجعة', `شحنة جديدة #${shipmentNumber} من ${senderName} بانتظار مراجعة وتأكيد الإدارة`, 'shipment_new', {
          type: 'shipment_new', shipmentId: shipmentId.toString(), shipmentNumber
        });
      } catch (_) {}

      // Emit real-time event with full shipment data to admins
      try {
        const io = req.app.get('io');
        const eventData = await fetchShipmentEventData(shipmentId);
        const shipmentEventPayload = {
          orderId: null,
          shipmentId: shipmentId.toString(),
          id: shipmentId.toString(),
          orderNumber: shipmentNumber,
          shipmentNumber,
          shiftId: shiftId ? shiftId.toString() : null,
          captainId: null,
          orderType: 'shipment',
          status: statusVal,
          merchantId: merchantId ? merchantId.toString() : null,
          fromAddress,
          toAddress,
          price: finalPrice,
          totalAmount: finalPrice,
          createdAt: new Date().toISOString(),
          ...(eventData || {})
        };
        if (io) {
          io.to('admins').emit('shipment_created', shipmentEventPayload);
          io.to('admins').emit('ORDER_CREATED', shipmentEventPayload);
          io.to('admins').emit('dashboard_update');
          // Note: Shift captains are NOT notified while in 'Pending Review'
        }
      } catch (_) {}

      res.status(201).json({
        status: 1,
        message: 'تم إرسال الشحنة للإدارة بنجاح (قيد المراجعة)',
        data: {
          id: shipmentId.toString(),
          shipmentNumber,
          title: title || '',
          fromAddress,
          toAddress,
          fromGovernorate: fromGovernorate || '',
          fromArea: fromArea || '',
          toGovernorate: toGovernorate || '',
          toArea: toArea || '',
          tripId: tripId ? tripId.toString() : null,
          status: statusVal,
          price: finalPrice,
          discountApplied,
          couponCode: appliedCouponCode,
          weight: weight ? parseFloat(weight) : null,
          notes: notes || '',
          isFragile: isFragile === 'true' || isFragile === true || isFragile === 1,
          isWithoutAdvance: isWithoutAdvance === 'true' || isWithoutAdvance === true || isWithoutAdvance === 1,
          toLatitude: toLatitude ? parseFloat(toLatitude) : null,
          toLongitude: toLongitude ? parseFloat(toLongitude) : null,
          merchantLatitude: merchantLatitude ? parseFloat(merchantLatitude) : null,
          merchantLongitude: merchantLongitude ? parseFloat(merchantLongitude) : null,
          images: imageUrls,
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

// 2. GET ALL SHIPMENTS
const getShipments = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const role = req.user.role;
    const { status, filter, query } = req.query;

    let sql = `
      SELECT s.*, 
             m.firstName as merchantFirstName, m.lastName as merchantLastName, m.storeName as merchantStoreName,
             m.profileImage as merchantProfileImage, m.phone as merchantOriginalPhone, COALESCE(s.merchantPhone, m.phone) as merchantPhone, COALESCE(s.merchantLatitude, m.latitude) as merchantLatitude, COALESCE(s.merchantLongitude, m.longitude) as merchantLongitude,
             c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone, c.latitude as captainLatitude, c.longitude as captainLongitude,
             a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
             COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = s.captainId), 1), 0.0) as captainAvgRating,
             (SELECT COUNT(*) FROM reviews WHERE revieweeId = s.captainId) as captainReviewCount,
             EXISTS(SELECT 1 FROM reviews WHERE reviews.shipmentId = s.id AND reviews.reviewerId = ?) as hasReviewed
      FROM shipments s
      LEFT JOIN users m ON s.merchantId = m.id
      LEFT JOIN users c ON s.captainId = c.id
      LEFT JOIN users a ON s.assignedAdminId = a.id
      WHERE 1=1
    `;
    const params = [userId];

    // Filter by user role
    if (role === 'merchant') {
      sql += ' AND s.merchantId = ?';
      params.push(userId);
    } else if (role === 'captain') {
      // Captains only see shipments explicitly assigned to them and approved/ready/awaiting payment
      sql += " AND s.captainId = ? AND s.status NOT IN ('Pending Review', 'Ready For Assignment')";
      params.push(userId);
    }

    // Filter by status query param
    if (status && status !== 'الكل') {
      sql += ' AND s.status = ?';
      params.push(status);
    }

    // Filter by search query (shipment number)
    if (query) {
      sql += ' AND s.shipmentNumber LIKE ?';
      params.push(`%${query}%`);
    }

    const { captainId, tripId } = req.query;
    if (captainId) {
      sql += ' AND s.captainId = ?';
      params.push(captainId);
    }
    if (tripId) {
      sql += ' AND s.trip_id = ?';
      params.push(tripId);
    }

    sql += ' ORDER BY s.createdAt DESC';

    const [shipments] = await pool.query(sql, params);

    // Fetch images for all these shipments
    const formattedShipments = [];
    for (const s of shipments) {
      const [images] = await pool.query(
        'SELECT imageUrl FROM shipment_images WHERE shipmentId = ?',
        [s.id]
      );
      formattedShipments.push({
        id: s.id.toString(),
        shipmentNumber: s.shipmentNumber,
        merchantId: s.merchantId ? s.merchantId.toString() : null,
        captainId: s.captainId ? s.captainId.toString() : null,
        hasReviewed: s.hasReviewed === 1 || s.hasReviewed === true,
        title: s.title || '',
        fromAddress: s.fromAddress,
        toAddress: s.toAddress,
        fromGovernorate: s.fromGovernorate || '',
        fromArea: s.fromArea || '',
        toGovernorate: s.toGovernorate || '',
        toArea: s.toArea || '',
        status: s.status,
        clientName: s.merchantStoreName || (s.merchantFirstName ? `${s.merchantFirstName} ${s.merchantLastName}` : null),
        clientAvatar: s.merchantProfileImage || null,
        clientPhone: s.merchantPhone || null,
        merchantPhone: s.merchantPhone || null,
        merchantLatitude: s.merchantLatitude ? parseFloat(s.merchantLatitude) : null,
        merchantLongitude: s.merchantLongitude ? parseFloat(s.merchantLongitude) : null,
        driverName: s.captainFirstName ? `${s.captainFirstName} ${s.captainLastName}` : null,
        driverAvatar: s.captainProfileImage || null,
        driverPhone: s.captainPhone || null,
        driverLatitude: s.captainLatitude ? parseFloat(s.captainLatitude) : null,
        driverLongitude: s.captainLongitude ? parseFloat(s.captainLongitude) : null,
        driverAvgRating: parseFloat(s.captainAvgRating || 0.0),
        driverReviewCount: parseInt(s.captainReviewCount || 0),
        captainApprovalStatus: s.captainApprovalStatus || null,
        estimatedTime: s.estimatedTime || '',
        goodsPrice: parseFloat(s.goodsPrice || 0),
        price: parseFloat(s.price || 0),
        negotiatedPrice: s.negotiatedPrice ? parseFloat(s.negotiatedPrice) : null,
        weight: s.weight ? parseFloat(s.weight) : null,
        notes: s.notes || '',
        isFragile: s.isFragile === 1,
        isWithoutAdvance: s.isWithoutAdvance === 1,
        toLatitude: s.toLatitude ? parseFloat(s.toLatitude) : null,
        toLongitude: s.toLongitude ? parseFloat(s.toLongitude) : null,
        startLatitude: s.startLatitude ? parseFloat(s.startLatitude) : null,
        startLongitude: s.startLongitude ? parseFloat(s.startLongitude) : null,
        images: images.map(img => img.imageUrl),
        isPaid: s.isPaid === 1 || s.isPaid === true,
        assignedAdminId: s.assignedAdminId ? s.assignedAdminId.toString() : null,
        assignedAdminName: s.assignedAdminFirstName ? `${s.assignedAdminFirstName} ${s.assignedAdminLastName}`.trim() : null,
        createdAt: formatDate(s.createdAt)
      });
    }

    res.status(200).json({
      status: 1,
      data: formattedShipments
    });
  } catch (error) {
    next(error);
  }
};

// 3. GET SHIPMENT BY ID
const getShipmentById = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [shipments] = await pool.query(
      `SELECT s.*, 
              m.firstName as merchantFirstName, m.lastName as merchantLastName, m.storeName as merchantStoreName,
              m.profileImage as merchantProfileImage, m.phone as merchantOriginalPhone, COALESCE(s.merchantPhone, m.phone) as merchantPhone, COALESCE(s.merchantLatitude, m.latitude) as merchantLatitude, COALESCE(s.merchantLongitude, m.longitude) as merchantLongitude,
              m.email as merchantEmail, m.city as merchantCity, m.status as merchantStatus, m.createdAt as merchantCreatedAt,
              c.firstName as captainFirstName, c.lastName as captainLastName, c.profileImage as captainProfileImage, c.phone as captainPhone, c.latitude as captainLatitude, c.longitude as captainLongitude,
              a.firstName as assignedAdminFirstName, a.lastName as assignedAdminLastName,
              COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = s.captainId), 1), 0.0) as captainAvgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = s.captainId) as captainReviewCount,
              EXISTS(SELECT 1 FROM reviews WHERE reviews.shipmentId = s.id AND reviews.reviewerId = ?) as hasReviewed
       FROM shipments s
       LEFT JOIN users m ON s.merchantId = m.id
       LEFT JOIN users c ON s.captainId = c.id
       LEFT JOIN users a ON s.assignedAdminId = a.id
       WHERE s.id = ?`,
      [req.user.id, id]
    );

    if (shipments.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الشحنة غير موجودة'
      });
    }

    const s = shipments[0];
    try {
      assertShipmentAccess(s, req.user);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }

    const [images] = await pool.query(
      'SELECT imageUrl FROM shipment_images WHERE shipmentId = ?',
      [s.id]
    );

    const [directPayments] = await pool.query(
      'SELECT id, paymentRef, amount, paymentMethod, fromPhone, fromName, receiptImage, status, adminNote, createdAt FROM direct_payments WHERE shipmentId = ? ORDER BY createdAt DESC LIMIT 1',
      [s.id]
    );

    res.status(200).json({
      status: 1,
      data: {
        directPayment: directPayments.length > 0 ? directPayments[0] : null,
        id: s.id.toString(),
        shipmentNumber: s.shipmentNumber,
        merchantId: s.merchantId ? s.merchantId.toString() : null,
        captainId: s.captainId ? s.captainId.toString() : null,
        hasReviewed: s.hasReviewed === 1 || s.hasReviewed === true,
        tripId: s.trip_id ? s.trip_id.toString() : null,
        title: s.title || '',
        fromAddress: s.fromAddress,
        toAddress: s.toAddress,
        fromGovernorate: s.fromGovernorate || '',
        fromArea: s.fromArea || '',
        toGovernorate: s.toGovernorate || '',
        toArea: s.toArea || '',
        status: s.status,
        clientName: s.merchantStoreName || (s.merchantFirstName ? `${s.merchantFirstName} ${s.merchantLastName}` : null),
        clientAvatar: s.merchantProfileImage || null,
        clientPhone: s.merchantPhone || null,
        merchantPhone: s.merchantPhone || null,
        merchantEmail: s.merchantEmail || null,
        merchantCity: s.merchantCity || null,
        merchantStatus: s.merchantStatus || null,
        merchantCreatedAt: s.merchantCreatedAt || null,
        merchantFirstName: s.merchantFirstName || null,
        merchantLastName: s.merchantLastName || null,
        merchantLatitude: s.merchantLatitude ? parseFloat(s.merchantLatitude) : null,
        merchantLongitude: s.merchantLongitude ? parseFloat(s.merchantLongitude) : null,
        driverName: s.captainFirstName ? `${s.captainFirstName} ${s.captainLastName}` : null,
        driverAvatar: s.captainProfileImage || null,
        driverPhone: s.captainPhone || null,
        driverLatitude: s.captainLatitude ? parseFloat(s.captainLatitude) : null,
        driverLongitude: s.captainLongitude ? parseFloat(s.captainLongitude) : null,
        driverAvgRating: parseFloat(s.captainAvgRating || 0.0),
        driverReviewCount: parseInt(s.captainReviewCount || 0),
        captainApprovalStatus: s.captainApprovalStatus || null,
        estimatedTime: s.estimatedTime || '',
        goodsPrice: parseFloat(s.goodsPrice || 0),
        price: parseFloat(s.price || 0),
        serviceFee: parseFloat(s.serviceFee || 0),
        tip: parseFloat(s.tip || 0),
        discountApplied: parseFloat(s.discountApplied || 0),
        couponCode: s.couponCode || null,
        totalAmount: parseFloat((
          (s.isWithoutAdvance === 1 ? 0.00 : parseFloat(s.goodsPrice || 0)) +
          parseFloat(s.price || 0) +
          parseFloat(s.serviceFee || 0) +
          parseFloat(s.tip || 0) -
          parseFloat(s.discountApplied || 0)
        ).toFixed(2)),
        negotiatedPrice: s.negotiatedPrice ? parseFloat(s.negotiatedPrice) : null,
        platformShare: parseFloat(s.platformShare) > 0 ? parseFloat(s.platformShare) : parseFloat(s.price || 0) * 0.2,
        captainShare: parseFloat(s.captainShare) > 0 ? parseFloat(s.captainShare) : parseFloat(s.price || 0) * 0.8,
        weight: s.weight ? parseFloat(s.weight) : null,
        notes: s.notes || '',
        isFragile: s.isFragile === 1,
        isWithoutAdvance: s.isWithoutAdvance === 1,
        toLatitude: s.toLatitude ? parseFloat(s.toLatitude) : null,
        toLongitude: s.toLongitude ? parseFloat(s.toLongitude) : null,
        startLatitude: s.startLatitude ? parseFloat(s.startLatitude) : null,
        startLongitude: s.startLongitude ? parseFloat(s.startLongitude) : null,
        images: images.map(img => img.imageUrl),
        isPaid: s.isPaid === 1 || s.isPaid === true,
        assignedAdminId: s.assignedAdminId ? s.assignedAdminId.toString() : null,
        assignedAdminName: s.assignedAdminFirstName ? `${s.assignedAdminFirstName} ${s.assignedAdminLastName}`.trim() : null,
        createdAt: formatDate(s.createdAt)
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. UPDATE SHIPMENT STATUS
const updateShipmentStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    let { status, negotiatedPrice, startLatitude, startLongitude, isPaid } = req.body;
    const userId = req.user.id;
    const role = req.user.role;

    if (!status) {
      return res.status(400).json({
        status: 0,
        message: 'الحالة مطلوبة'
      });
    }

    // Check if shipment exists
    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
    if (shipments.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الشحنة غير موجودة'
      });
    }

    const shipment = shipments[0];
    try {
      assertShipmentAccess(shipment, req.user);
      assertShipmentStatusTransition(role, shipment, status, userId);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }

    if (['delivered', 'completed', 'منتهية'].includes(status.toString().trim().toLowerCase()) || status === 'منتهية') {
      const captainId = shipment.captainId || (role === 'captain' ? userId : null);
      if (!captainId) {
        return res.status(400).json({ status: 0, message: 'لا يوجد كابتن معين لهذه الشحنة' });
      }

      const price = parseFloat(shipment.price || 0);
      const captainShare = parseFloat(shipment.captainShare || (price * 0.8));
      const platformShare = parseFloat(shipment.platformShare || (price * 0.2));
      const isOnlinePaid = (shipment.isPaid === 1 || shipment.paymentStatus === 'paid' || ['kashier', 'online', 'card', 'wallet'].includes((shipment.paymentMethod || '').toLowerCase()));
      const finalStatus = 'Completed';

      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();

        await conn.query(
          `UPDATE shipments 
           SET status = ?, 
               deliveryConfirmedAt = NOW(), 
               deliveryLatitude = ?, 
               deliveryLongitude = ? 
           WHERE id = ?`,
          [finalStatus, startLatitude ? parseFloat(startLatitude) : null, startLongitude ? parseFloat(startLongitude) : null, id]
        );

        if (isOnlinePaid) {
          // 1. الدفع الإلكتروني: الكابتن لم يستلم كاش - المنصة تودع نصيب الكابتن 80% في محفظته
          await conn.query(
            'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
            [captainShare, captainId]
          );

          const txTitleCaptain = `أرباح توصيل شحنة إلكترونية #${shipment.shipmentNumber}`;
          await conn.query(
            "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
            [captainId, txTitleCaptain, captainShare, `#SHP${shipment.id}`]
          );
        } else {
          // 1. الدفع عند الاستلام (كاش): الكابتن استلم 100% من سعر الشحنة والتوصيل نقداً + رسوم الخدمة + الإكرامية
          // المنصة تستحق: عمولة 20% + رسوم الخدمة + الإكرامية
          const serviceFee = parseFloat(shipment.serviceFee || 0);
          const tip = parseFloat(shipment.tip || 0);
          const totalPlatformDue = Math.round((platformShare + serviceFee + tip) * 100) / 100;

          if (totalPlatformDue > 0) {
            await conn.query(
              'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
              [totalPlatformDue, captainId]
            );

            const txTitleFee = `عمولة ورسوم المنصة (20% + خدمة + إكرامية) - شحنة كاش #${shipment.shipmentNumber}`;
            await conn.query(
              "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'withdraw', 'success', 'cash_commission', ?)",
              [captainId, txTitleFee, totalPlatformDue, `#SHP${shipment.id}`]
            );
          }
        }

        await conn.commit();

        checkAndRewardReferral(shipment.merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
        checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));

        const io = req.app.get('io');
        if (io) {
          io.to(`shipment_${id}`).emit('statusUpdate', { status: finalStatus });
          io.to(`shipment_${id}`).emit('chat_deleted', { shipmentId: id });
          io.to('admins').emit('dashboard_update');
        }

        try {
          const eventData = await fetchShipmentEventData(id);
          if (eventData && io) {
            io.to('admins').emit('shipment_updated', eventData);
          }
        } catch (_) {}

        await pool.query('DELETE FROM messages WHERE shipmentId = ?', [id]);

        // Send notifications
        const [senderRows] = await pool.query('SELECT firstName, lastName, profileImage FROM users WHERE id = ?', [userId]);
        const senderName = senderRows.length > 0 ? (senderRows[0].storeName || `${senderRows[0].firstName} ${senderRows[0].lastName}`.trim()) : 'مستخدم';
        const [merchantRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [shipment.merchantId]);
        const merchantFcm = merchantRows.length > 0 ? merchantRows[0].fcmToken : null;
        const [captainRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [captainId]);
        const captainFcm = captainRows.length > 0 ? captainRows[0].fcmToken : null;

        if (isOnlinePaid) {
          sendNotification(io, captainId, 'تم تأكيد تسليم الشحنة 🎉', `تم إكمال الشحنة الإلكترونية #${shipment.shipmentNumber}. تم إيداع أرباح التوصيل (${captainShare} ج.م) في محفظتك.`, 'order', { type: 'shipment_completed', shipmentId: id.toString(), amount: captainShare.toString() });
          sendNotification(io, shipment.merchantId, `تم تسليم الشحنة #${shipment.shipmentNumber}`, 'تم تسليم الشحنة للمستلم بنجاح واكتمال العملية 🎉', 'order', { type: 'shipment_completed', shipmentId: id.toString() });
        } else {
          sendNotification(io, captainId, 'تم تأكيد تسليم الشحنة 🎉', `تم إكمال شحنة الدفع عند الاستلام #${shipment.shipmentNumber}. تم تسجيل عمولة المنصة 20% (${platformShare} ج.م) على محفظتك.`, 'order', { type: 'shipment_completed', shipmentId: id.toString(), amount: platformShare.toString() });
          sendNotification(io, shipment.merchantId, `تم تسليم الشحنة #${shipment.shipmentNumber}`, 'تم تسليم الشحنة للمستلم بنجاح واستلام قيمتها نقداً 🎉', 'order', { type: 'shipment_completed', shipmentId: id.toString() });
        }

        const { notifyAdmins } = require('../utils/adminNotifier');
        await notifyAdmins(io, '✅ شحنة مكتملة',
          `الشحنة #${shipment.shipmentNumber} تم تسليمها وإكمالها بنجاح`,
          'shipment_delivered', { type: 'shipment_delivered', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );

        return res.status(200).json({
          status: 1,
          message: 'تم توصيل الشحنة واكتمالها بنجاح وتنزيل الرصيد في حساب الكابتن',
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

    const oldStatus = shipment.status;
    const oldCaptainId = shipment.captainId;



    // If Captain accepts shipment or proposes price, set captainId
    let sql = 'UPDATE shipments SET status = ?';
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
      await resolveAttempt(pool, { shipmentId: id, captainId: userId, status: isTimeout ? 'timeout' : 'rejected', reason: isTimeout ? 'انتهت مهلة قبول الشحنة للكابتن' : 'الكابتن قام برفض الشحنة' });
      status = 'Ready For Assignment';
      sql = "UPDATE shipments SET status = 'Ready For Assignment', captainId = NULL, captainApprovalStatus = NULL";
      queryParams.length = 0;
      setImmediate(() => {
        triggerAutoAssignment(id, null).catch(err => console.error('Error triggering auto assignment after timeout/reject:', err));
      });
    } else if (role === 'captain' && (status === 'جاري التنفيذ' || status === 'تم القبول' || status === 'In Transit' || status === 'Picked Up' || status === 'Captain Arrived' || status === 'captain arrived')) {
      sql += ', captainId = ?, captainApprovalStatus = ?';
      queryParams.push(userId);
      queryParams.push('accepted');
    } else if (role === 'captain' && (status === 'في انتظار القبول' || status === 'Pending Review')) {
      sql += ', captainId = ?, negotiatedPrice = ?';
      queryParams.push(userId);
      queryParams.push(negotiatedPrice ? parseFloat(negotiatedPrice) : null);
    } else if (role === 'merchant' && (status === 'تم قبول العرض' || status === 'Assigned To Captain')) {
      sql += ', price = COALESCE(negotiatedPrice, price), negotiatedPrice = NULL';
    } else if (role === 'merchant' && (status === 'جديدة' || status === 'Pending Review')) {
      // Merchant rejected the offer: reset captainId and negotiatedPrice
      sql += ', captainId = NULL, negotiatedPrice = NULL, captainApprovalStatus = NULL';
    }

    if (['Picked Up', 'picked up'].includes(status)) {
      sql += ', pickupConfirmedAt = NOW(), pickupLatitude = ?, pickupLongitude = ?';
      queryParams.push(startLatitude ? parseFloat(startLatitude) : null);
      queryParams.push(startLongitude ? parseFloat(startLongitude) : null);
    }

    if (['Ready For Assignment'].includes(status)) {
      const priceVal = parseFloat(shipment.price || 0);
      sql += ', platformShare = ?, captainShare = ?, autoAssignmentFailed = 0';
      queryParams.push(priceVal * 0.20);
      queryParams.push(priceVal * 0.80);
    }

    if (['Picked Up', 'In Transit'].includes(status) && startLatitude !== undefined && startLongitude !== undefined) {
      sql += ', startLatitude = COALESCE(startLatitude, ?), startLongitude = COALESCE(startLongitude, ?)';
      queryParams.push(startLatitude ? parseFloat(startLatitude) : null);
      queryParams.push(startLongitude ? parseFloat(startLongitude) : null);
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

    // Fetch FCM tokens for all parties
    const captainId = shipment.captainId || (role === 'captain' ? userId : null) || oldCaptainId;
    const merchantId = shipment.merchantId;

    await logStatusChange(pool, {
      shipmentId: id,
      userId,
      userName: senderName,
      userRole: role,
      previousStatus: oldStatus,
      newStatus: status,
      latitude: startLatitude ? parseFloat(startLatitude) : null,
      longitude: startLongitude ? parseFloat(startLongitude) : null
    });

    const fetchFcm = async (uid) => {
      if (!uid) return null;
      const [rows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [uid]);
      return rows.length > 0 ? (rows[0].fcmToken || null) : null;
    };

    const captainFcm = await fetchFcm(captainId);
    const merchantFcm = await fetchFcm(merchantId);

    // Base notification data
    const baseData = {
      type: 'shipment_status_update',
      shipmentId: id.toString(),
      shipmentNumber: shipment.shipmentNumber,
      senderName: senderName,
      senderAvatar: senderAvatar || '',
      status: status
    };

    const io = req.app.get('io');

    const notify = async (fcmToken, targetUserId, title, body, extraData = {}) => {
      if (!targetUserId) return;
      await sendNotification(io, targetUserId, title, body, 'shipment', { ...baseData, ...extraData });
    };
    if (io) {
      io.to(`shipment_${id}`).emit('statusUpdate', { status, isCancelled: ['cancelled', 'ملغي', 'ملغية'].includes(status.toString().trim().toLowerCase()) });
      io.to('admins').emit('dashboard_update');
      if (['cancelled', 'ملغي', 'ملغية'].includes(status.toString().trim().toLowerCase()) && captainId) {
        io.to(`user_${captainId}`).emit('shipment_cancelled', { shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber });
        io.to(`captain_${captainId}`).emit('shipment_cancelled', { shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber });
      }
    }

    // Emit granular shipment_updated event with full data
    try {
      const eventData = await fetchShipmentEventData(id);
      if (eventData && io) {
        io.to('admins').emit('shipment_updated', eventData);
      }
    } catch (_) {}

    // ── Comprehensive notifications for ALL status transitions ──────────────
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');

      // 0. Captain in route to pickup / arrived
      if (['captain arrived', 'في الطريق للاستلام', 'فى الطريق للاستلام'].includes(norm(status))) {
        const msg = `الكابتن ${senderName} في الطريق لموقع استلام الشحنة #${shipment.shipmentNumber}.`;
        await notify(merchantFcm, merchantId, `الكابتن في الطريق للاستلام 📍`, msg, { type: 'captain_arrived' });
        await notifyAdmins(io, '📍 الكابتن في الطريق للاستلام',
          `الكابتن ${senderName} في الطريق لموقع استلام الشحنة #${shipment.shipmentNumber}`,
          'captain_arrived', { type: 'captain_arrived', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 1. Captain proposes / makes offer
      if (role === 'captain' && ['في انتظار القبول', 'pending review'].includes(norm(status))) {
        const proposedPrice = negotiatedPrice ? parseFloat(negotiatedPrice) : shipment.price;
        await notify(merchantFcm, merchantId,
          'عرض توصيل جديد 🚚',
          `قدم الكابتن ${senderName} عرضاً لتوصيل شحنتك #${shipment.shipmentNumber} بقيمة ${proposedPrice} ج.م`,
          { type: 'negotiation_offer', proposedPrice: proposedPrice.toString() }
        );
        await notifyAdmins(io, '📦 عرض توصيل جديد',
          `الكابتن ${senderName} قدم عرضاً للشحنة #${shipment.shipmentNumber}`,
          'negotiation_offer', { type: 'negotiation_offer', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 2. Merchant accepts offer
      if (role === 'merchant' && ['تم قبول العرض', 'assigned to captain'].includes(norm(status))) {
        await notify(captainFcm, captainId,
          'تم قبول عرض التوصيل 🎉',
          `وافق التاجر ${senderName} على عرضك لتوصيل الشحنة #${shipment.shipmentNumber}`,
          { type: 'offer_accepted' }
        );
        await notifyAdmins(io, '✅ تم قبول عرض توصيل',
          `التاجر ${senderName} قبل عرض الكابتن للشحنة #${shipment.shipmentNumber}`,
          'offer_accepted', { type: 'offer_accepted', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 3. Merchant rejects offer
      if (role === 'merchant' && norm(status) === 'جديدة' && norm(oldStatus) === 'في انتظار القبول') {
        await notify(captainFcm, captainId,
          'تم رفض عرض التوصيل ❌',
          `رفض التاجر ${senderName} عرضك لتوصيل الشحنة #${shipment.shipmentNumber}`,
          { type: 'offer_rejected' }
        );
      }

      // 4. Captain confirms pickup from merchant → status 'picked up' / 'تم استلام الشحنة'
      if (['picked up', 'تم استلام الشحنة', 'تم التنفيذ'].includes(norm(status))) {
        const msg = `تم استلام الشحنة #${shipment.shipmentNumber} بنجاح من قبل الكابتن ${senderName}.`;
        await notify(merchantFcm, merchantId, `تم استلام الشحنة 📦`, msg, { type: 'shipment_picked_up' });
        await notifyAdmins(io, '📦 تم استلام الشحنة',
          `الشحنة #${shipment.shipmentNumber} تم استلامها بواسطة ${senderName}`,
          'shipment_picked_up', { type: 'shipment_picked_up', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 5. Captain in transit
      if (['in transit', 'ongoing', 'فى الطريق للتسليم', 'في الطريق للتسليم'].includes(norm(status))) {
        const msg = `الكابتن ${senderName} في الطريق لتسليم الشحنة #${shipment.shipmentNumber} إلى العنوان المحدد.`;
        await notify(merchantFcm, merchantId, `الشحنة في الطريق للتسليم 🛵`, msg, { type: 'shipment_in_transit' });
        await notifyAdmins(io, '🛵 شحنة في الطريق للتسليم',
          `الشحنة #${shipment.shipmentNumber} في الطريق للتسليم بواسطة ${senderName}`,
          'shipment_in_transit', { type: 'shipment_in_transit', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 6. Captain confirms delivery → 'منتهية' / 'delivered' / 'completed'
      if (['منتهية', 'delivered', 'completed', 'تم التوصيل بنجاح', 'تم التسليم بنجاح', 'مكتمل'].includes(norm(status))) {
        const msg = `تم تسليم الشحنة #${shipment.shipmentNumber} بنجاح واكتمالها 🎉`;
        await notify(merchantFcm, merchantId, `تم تسليم الشحنة بنجاح ✅`, msg, { type: 'shipment_delivered' });
        await notify(captainFcm, captainId, `تم تسليم الشحنة #${shipment.shipmentNumber}`, msg, { type: 'shipment_delivered' });
        await notifyAdmins(io, '✅ شحنة تم تسليمها',
          `الشحنة #${shipment.shipmentNumber} تم تسليمها بنجاح`,
          'shipment_delivered', { type: 'shipment_delivered', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 6. Merchant reopens (بانتظار القبول / Pending Review)
      if (status === 'بانتظار القبول' || status === 'Pending Review') {
        if (captainId) {
          await notify(captainFcm, captainId,
            `تم إلغاء التوصيل 🔄`,
            `الشحنة #${shipment.shipmentNumber} متاحة لكابتن آخر`,
            { type: 'shipment_cancelled' }
          );
        }
        await notifyAdmins(io, '🔄 شحنة بانتظار القبول',
          `الشحنة #${shipment.shipmentNumber} بانتظار كابتن جديد`,
          'shipment_pending', { type: 'shipment_pending', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 7. Dispatcher assignment flow
      if (status === 'Ready For Assignment' || status === 'Assigned To Captain') {
        if (captainId) {
          await notify(captainFcm, captainId,
            `تم تعيينك لتوصيل شحنة 📋`,
            `تم تعيينك لتوصيل الشحنة #${shipment.shipmentNumber}`,
            { type: 'shipment_assigned' }
          );
        }
        await notifyAdmins(io, '📋 شحنة تم تعيينها',
          `الشحنة #${shipment.shipmentNumber} تم تعيينها لكابتن`,
          'shipment_assigned', { type: 'shipment_assigned', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }

      // 8. Payment pending
      // 8.5 Admin approves shipment directly without negotiation
      if (
        ['admin', 'employee'].includes(role) &&
        ['Ready For Assignment', 'Assigned To Captain'].includes(status) &&
        ['جديدة', 'بانتظار القبول', 'Pending Review'].includes(oldStatus)
      ) {
        await notify(merchantFcm, merchantId,
          `✅ تم قبول شحنتك`,
          `وافقت الإدارة على شحنتك رقم #${shipment.shipmentNumber} بنجاح وجاري العمل عليها.`,
          { type: 'shipment_approved_directly' }
        );
      }

      // 9. Ongoing / In Transit updates
      if (status === 'ongoing' || status === 'Picked Up' || status === 'In Transit') {
        await notify(merchantFcm, merchantId,
          `تحديث الشحنة #${shipment.shipmentNumber}`,
          `جاري تنفيذ شحنتك من قبل المندوب.`,
          { type: 'shipment_updates' }
        );
        if (captainId) {
          await notify(captainFcm, captainId,
            `تحديث الشحنة #${shipment.shipmentNumber}`,
            `جاري تنفيذ الشحنة.`,
            { type: 'shipment_updates' }
          );
        }
      }

      // 10. New shipment (not from rejection)
      if (status === 'جديدة' && oldStatus !== 'في انتظار القبول') {
        await notifyAdmins(io, '📦 شحنة جديدة',
          `شحنة جديدة #${shipment.shipmentNumber} من ${senderName}`,
          'shipment_new', { type: 'shipment_new', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
          userId
        );
      }
    } catch (_) {}

    // ── Referral & cleanup logic (independent of notifications) ───────────────

    if (status === 'منتهية' || status === 'Delivered' || status === 'Completed') {
      checkAndRewardReferral(merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
      if (captainId) {
        checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));
      }

      // Permanently delete all chat messages for this shipment
      try {
        await pool.query('DELETE FROM messages WHERE shipmentId = ?', [id]);
        console.log(`🗑️ Permanently deleted all chat messages for completed shipment ${id}`);
        
        // Also emit a socket event to let the room know that the chat has been deleted and closed
        if (io) {
          io.to(`shipment_${id}`).emit('chat_deleted', { shipmentId: id });
        }
      } catch (chatDelErr) {
        console.error(`❌ Error deleting messages for shipment ${id}:`, chatDelErr);
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (status === 'Ready For Assignment') {
      const { triggerAutoAssignment } = require('../utils/autoAssignment');
      triggerAutoAssignment(id, null).catch(err => console.error('Error triggering auto assignment:', err.message));
      // Notify shift captains if linked
      try {
        const [sRows] = await pool.query('SELECT shift_id, shipmentNumber, price FROM shipments WHERE id = ?', [id]);
        if (sRows.length > 0 && sRows[0].shift_id && io) {
          const shiftId = sRows[0].shift_id;
          const payload = { id: id.toString(), type: 'shipment', shipmentNumber: sRows[0].shipmentNumber, status: 'Ready For Assignment' };
          io.to(`shift_${shiftId}`).emit('ORDER_CREATED', payload);
          io.to(`shift:${shiftId}`).emit('ORDER_CREATED', payload);
        }
      } catch (_) {}
      if (io) io.to('admins').emit('dashboard_update');
    }

    res.status(200).json({
      status: 1,
      message: 'تم تحديث حالة الشحنة بنجاح'
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

    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
    if (shipments.length === 0) {
      return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
    }

    const shipment = shipments[0];
    if (shipment.merchantId !== merchantId) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتأكيد استلام هذه الشحنة' });
    }

    const allowedStatuses = ['Assigned To Captain', 'Captain Arrived'];
    if (!allowedStatuses.includes(shipment.status)) {
      return res.status(400).json({ status: 0, message: 'لا يمكن تأكيد استلام الشحنة في الحالة الحالية' });
    }

    const newStatus = 'Picked Up';
    await pool.query(
      `UPDATE shipments 
       SET status = ?, 
           pickupConfirmedAt = NOW(), 
           pickupLatitude = ?, 
           pickupLongitude = ? 
       WHERE id = ?`,
      [newStatus, latitude ? parseFloat(latitude) : null, longitude ? parseFloat(longitude) : null, id]
    );

    const io = req.app.get('io');
    if (io) {
      io.to(`shipment_${id}`).emit('statusUpdate', { status: newStatus });
      io.to('admins').emit('dashboard_update');
    }

    // Emit granular shipment_updated event
    try {
      const eventData = await fetchShipmentEventData(id);
      if (eventData && io) {
        io.to('admins').emit('shipment_updated', eventData);
      }
    } catch (_) {}

    if (shipment.captainId) {
      sendNotification(io, shipment.captainId, 'تم تأكيد الاستلام 📦', `أكد التاجر استلام الشحنة #${shipment.shipmentNumber}. يمكنك الآن بدء التوصيل.`, 'order', { type: 'shipment_picked_up', shipmentId: id.toString() });
    }

    res.status(200).json({
      status: 1,
      message: 'تم تأكيد استلام الشحنة بنجاح وبدء مسار التوصيل'
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

    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
    if (shipments.length === 0) {
      return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
    }

    const shipment = shipments[0];
    if (Number(shipment.merchantId) !== Number(userId) && Number(shipment.captainId) !== Number(userId) && !['admin', 'employee'].includes(role)) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتأكيد تسليم هذه الشحنة' });
    }

    const allowedStatuses = ['picked up', 'in transit', 'delivered', 'completed', 'تم استلام الشحنة', 'في الطريق للتسليم', 'فى الطريق للتسليم', 'تم التوصيل بنجاح', 'تم التسليم بنجاح', 'مكتمل'];
    if (!allowedStatuses.includes(norm(shipment.status))) {
      return res.status(400).json({ status: 0, message: 'لا يمكن تأكيد تسليم الشحنة في الحالة الحالية' });
    }

    const newStatus = 'Completed';
    const captainId = shipment.captainId || (role === 'captain' ? userId : null);

    if (!captainId) {
      return res.status(400).json({ status: 0, message: 'لا يوجد كابتن معين لهذه الشحنة' });
    }

    const price = parseFloat(shipment.price || 0);
    const captainShare = parseFloat(shipment.captainShare || (price * 0.8));
    const platformShare = parseFloat(shipment.platformShare || (price * 0.2));
    const isOnlinePaid = (shipment.isPaid === 1 || shipment.paymentStatus === 'paid' || ['kashier', 'online', 'card', 'wallet'].includes((shipment.paymentMethod || '').toLowerCase()));

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      await conn.query(
        `UPDATE shipments 
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

        const txTitleCaptain = `أرباح توصيل شحنة إلكترونية #${shipment.shipmentNumber}`;
        await conn.query(
          "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'deposit', 'success', 'online', ?)",
          [captainId, txTitleCaptain, captainShare, `#SHP${shipment.id}`]
        );
      } else {
        // 1. الدفع عند الاستلام (كاش): الكابتن استلم 100% من سعر الشحنة والتوصيل نقداً + رسوم الخدمة + الإكرامية
        // المنصة تستحق: عمولة 20% + رسوم الخدمة + الإكرامية
        const serviceFee = parseFloat(shipment.serviceFee || 0);
        const tip = parseFloat(shipment.tip || 0);
        const totalPlatformDue = Math.round((platformShare + serviceFee + tip) * 100) / 100;

        if (totalPlatformDue > 0) {
          await conn.query(
            'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
            [totalPlatformDue, captainId]
          );

          const txTitleFee = `عمولة ورسوم المنصة (20% + خدمة + إكرامية) - شحنة كاش #${shipment.shipmentNumber}`;
          await conn.query(
            "INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, reference) VALUES (?, ?, ?, 'withdraw', 'success', 'cash_commission', ?)",
            [captainId, txTitleFee, totalPlatformDue, `#SHP${shipment.id}`]
          );
        }
      }

      await conn.commit();

      checkAndRewardReferral(shipment.merchantId).catch(err => console.error('Error rewarding merchant referral:', err));
      checkAndRewardReferral(captainId).catch(err => console.error('Error rewarding captain referral:', err));

      const io = req.app.get('io');
      if (io) {
        io.to(`shipment_${id}`).emit('statusUpdate', { status: newStatus });
        io.to(`shipment_${id}`).emit('chat_deleted', { shipmentId: id });
        io.to('admins').emit('dashboard_update');
      }

      // Emit granular shipment_updated event
      try {
        const eventData = await fetchShipmentEventData(id);
        if (eventData && io) {
          io.to('admins').emit('shipment_updated', eventData);
        }
      } catch (_) {}

      await pool.query('DELETE FROM messages WHERE shipmentId = ?', [id]);

      if (isOnlinePaid) {
        sendNotification(io, captainId, 'تم تأكيد تسليم الشحنة 🎉', `أكد التاجر تسليم الشحنة الإلكترونية #${shipment.shipmentNumber}. تم إيداع ${captainShare} ج.م في محفظتك.`, 'order', { type: 'shipment_completed', shipmentId: id.toString(), amount: captainShare.toString() });
        if (shipment.merchantId) {
          sendNotification(io, shipment.merchantId, `تم تسليم الشحنة #${shipment.shipmentNumber}`, 'تم تسليم الشحنة للمستلم بنجاح واكتمال العملية 🎉', 'order', { type: 'shipment_completed', shipmentId: id.toString() });
        }
      } else {
        sendNotification(io, captainId, 'تم تأكيد تسليم الشحنة 🎉', `تم تأكيد تسليم الشحنة الكاش #${shipment.shipmentNumber}. تم تسجيل عمولة المنصة 20% (${platformShare} ج.م) على محفظتك.`, 'order', { type: 'shipment_completed', shipmentId: id.toString(), amount: platformShare.toString() });
        if (shipment.merchantId) {
          sendNotification(io, shipment.merchantId, `تم تسليم الشحنة #${shipment.shipmentNumber}`, 'تم تسليم الشحنة للمستلم بنجاح واستلام قيمتها نقداً واكتمال العملية 🎉', 'order', { type: 'shipment_completed', shipmentId: id.toString() });
        }
      }

      res.status(200).json({
        status: 1,
        message: 'تم تأكيد تسليم الشحنة بنجاح وتسوية المعاملة المالية في المحفظة'
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

      const [shipments] = await conn.query('SELECT * FROM shipments WHERE id = ? FOR UPDATE', [id]);
      if (shipments.length === 0) {
        await conn.rollback();
        return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
      }

      const shipment = shipments[0];
      if (shipment.captainId !== captainId) {
        await conn.rollback();
        return res.status(403).json({ status: 0, message: 'غير مصرح لك بالرد على تكليف هذه الشحنة' });
      }

      if (shipment.captainApprovalStatus !== 'pending') {
        await conn.rollback();
        return res.status(400).json({ status: 0, message: 'تم الرد على هذا التكليف مسبقاً أو غير معلق' });
      }

      const targetRoom = `shipment_${id}`;
      const io = req.app.get('io');

      // Fetch captain's real name from DB (not in JWT)
      const [captainRows] = await conn.query('SELECT firstName, lastName FROM users WHERE id = ?', [captainId]);
      const captainName = captainRows.length > 0 ? `${captainRows[0].firstName || ''} ${captainRows[0].lastName || ''}`.trim() : 'كابتن';

      if (response === 'accept') {
        const [updateResult] = await conn.query(
          `UPDATE shipments 
           SET captainApprovalStatus = 'accepted',
               shift_id = COALESCE(shift_id, (SELECT sc.shiftId FROM shift_captains sc JOIN shifts s ON sc.shiftId = s.id WHERE sc.captainId = ? AND s.status = 'active' AND sc.clockInTime IS NOT NULL AND sc.clockOutTime IS NULL LIMIT 1))
           WHERE id = ? AND captainId = ? AND captainApprovalStatus = 'pending'`,
          [captainId, id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف متاحاً لك حالياً' });
        }

        await conn.commit();

        const { resolveAttempt } = require('../utils/autoAssignment');
        await resolveAttempt(pool, { shipmentId: id, captainId, status: 'accepted', reason: 'Captain accepted assignment' });

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: shipment.status });
          io.to(targetRoom).emit('captain_response', { response: 'accept', captainId });
          io.to('admins').emit('dashboard_update');
        }

        // Notify admins about captain acceptance
        const { notifyAdmins } = require('../utils/adminNotifier');
        const shipmentPrice = parseFloat(shipment.price || 0).toFixed(2);
        notifyAdmins(io,
          `✅ قبول تكليف شحنة #${shipment.shipmentNumber}`,
          `الكابتن ${captainName} قبل تكليف الشحنة رقم ${shipment.shipmentNumber} بقيمة ${shipmentPrice} ج.م`,
          'system',
          { type: 'captain_accepted', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber, captainName, price: shipmentPrice }
        );

        // Emit granular shipment_updated event
        try {
          const eventData = await fetchShipmentEventData(id);
          if (eventData && io) {
            io.to('admins').emit('shipment_updated', eventData);
          }
        } catch (_) {}

        res.status(200).json({
          status: 1,
          message: 'تم قبول تكليف الشحنة بنجاح'
        });
      } else {
        // Reject: reset captainId, captainApprovalStatus, and return status to Ready For Assignment
        const [updateResult] = await conn.query(
          "UPDATE shipments SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment' WHERE id = ? AND captainId = ? AND captainApprovalStatus = 'pending'",
          [id, captainId]
        );
        if (updateResult.affectedRows === 0) {
          await conn.rollback();
          return res.status(400).json({ status: 0, message: 'عذراً، لم يعد هذا التكليف معلقاً لديك' });
        }

        await conn.commit();

        const { resolveAttempt, triggerAutoAssignment } = require('../utils/autoAssignment');
        await resolveAttempt(pool, { shipmentId: id, captainId, status: 'rejected', reason: 'Captain rejected assignment' });

        // Notify all admins and employees
        const { notifyAdmins } = require('../utils/adminNotifier');
        const shipmentPrice = parseFloat(shipment.price || 0).toFixed(2);
        notifyAdmins(io,
          `❌ رفض تكليف شحنة #${shipment.shipmentNumber}`,
          `الكابتن ${captainName} رفض تكليف الشحنة رقم ${shipment.shipmentNumber} بقيمة ${shipmentPrice} ج.م`,
          'system',
          { type: 'captain_rejected', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber, captainName, price: shipmentPrice }
        );

        if (io) {
          io.to(targetRoom).emit('statusUpdate', { status: 'Ready For Assignment' });
          io.to(targetRoom).emit('captain_response', { response: 'reject', captainId });
          io.to('admins').emit('dashboard_update');
        }

        // Instantly trigger auto-assignment to search for the next captain in the background
        triggerAutoAssignment(id, null).catch(err => console.error('Error triggering auto assignment after reject:', err.message));

        // Emit granular shipment_updated event
        try {
          const eventData = await fetchShipmentEventData(id);
          if (eventData && io) {
            io.to('admins').emit('shipment_updated', eventData);
          }
        } catch (_) {}

        res.status(200).json({
          status: 1,
          message: 'تم رفض تكليف الشحنة وإعادة إتاحتها للتعيين'
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

// 9. COMPUTE PRICING (calculate platform & captain shares, notify admins)
const computePricing = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const io = req.app.get('io');

    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
    if (shipments.length === 0) {
      return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
    }

    const shipment = shipments[0];
    const priceVal = parseFloat(shipment.price || 0);
    const platformShare = priceVal * 0.20;
    const captainShare = priceVal * 0.80;

    await pool.query(
      'UPDATE shipments SET platformShare = ?, captainShare = ? WHERE id = ?',
      [platformShare, captainShare, id]
    );

    // Notify admins
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        'تم حساب تسعير الشحنة 💰',
        `تم تطبيق خصم 20% على الشحنة #${shipment.shipmentNumber}. سعر الكابتن: ${captainShare.toFixed(2)} ج.م`,
        'shipment',
        { type: 'pricing_computed', shipmentId: id.toString(), shipmentNumber: shipment.shipmentNumber },
        req.user?.id
      );
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم حساب التسعير بنجاح',
      data: {
        id: shipment.id.toString(),
        price: priceVal,
        platformShare,
        captainShare
      }
    });
  } catch (error) {
    next(error);
  }
};

const claimShipment = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const adminId = req.user.id;

    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
    if (shipments.length === 0) {
      return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
    }

    await pool.query('UPDATE shipments SET assignedAdminId = ? WHERE id = ?', [adminId, id]);

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
    }

    try {
      const eventData = await fetchShipmentEventData(id);
      if (eventData && io) {
        io.to('admins').emit('shipment_updated', eventData);
      }
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم استلام الشحنة بنجاح للبدء بمتابعتها',
      data: { assignedAdminId: adminId }
    });
  } catch (error) {
    next(error);
  }
};

const deleteShipment = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const merchantId = req.user.id;

    const [shipments] = await pool.query(
      'SELECT * FROM shipments WHERE id = ? AND merchantId = ?',
      [id, merchantId]
    );

    if (shipments.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الشحنة غير موجودة أو لا تملك صلاحية حذفها'
      });
    }

    const shipment = shipments[0];
    if (shipment.status !== 'Pending Review') {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن حذف الشحنة بعد قبولها أو البدء في تنفيذها'
      });
    }

    const [images] = await pool.query(
      'SELECT * FROM shipment_images WHERE shipmentId = ?',
      [id]
    );
    const fs = require('fs');
    const path = require('path');
    for (const img of images) {
      try {
        const fullPath = path.join(__dirname, '..', img.imageUrl);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      } catch (_) {}
    }
    await pool.query('DELETE FROM shipment_images WHERE shipmentId = ?', [id]);
    await pool.query('DELETE FROM shipments WHERE id = ?', [id]);

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
      io.emit('shipment_deleted', { id: id.toString() });
    }

    res.status(200).json({
      status: 1,
      message: 'تم حذف الشحنة بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

const updateShipment = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const isAdminOrEmp = req.user.role === 'admin' || req.user.role === 'employee';
    const userId = req.user.id;

    let shipments;
    if (isAdminOrEmp) {
      const [rows] = await pool.query('SELECT * FROM shipments WHERE id = ?', [id]);
      shipments = rows;
    } else {
      const [rows] = await pool.query(
        'SELECT * FROM shipments WHERE id = ? AND merchantId = ?',
        [id, userId]
      );
      shipments = rows;
    }

    if (shipments.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الشحنة غير موجودة أو لا تملك صلاحية تعديلها'
      });
    }

    const shipment = shipments[0];
    if (!isAdminOrEmp && shipment.status !== 'Pending Review') {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن تعديل الشحنة بعد قبولها أو البدء في تنفيذها'
      });
    }

    const {
      title,
      fromAddress,
      toAddress,
      fromGovernorate,
      fromArea,
      toGovernorate,
      toArea,
      goodsPrice,
      itemPrice,
      price,
      weight,
      notes,
      isFragile,
      isWithoutAdvance,
      toLatitude,
      toLongitude,
      merchantLatitude,
      merchantLongitude,
      merchantPhone,
      merchantId
    } = req.body;

    if (!title || title.trim().length === 0 || !fromAddress || !toAddress || !price) {
      return res.status(400).json({
        status: 0,
        message: 'عنوان الاستلام، عنوان التسليم، وسعر التوصيل مطلوبة'
      });
    }

    const updatedMerchantId = (isAdminOrEmp && merchantId) ? parseInt(merchantId, 10) : shipment.merchantId;
    const isNoAdvance = isWithoutAdvance === 'true' || isWithoutAdvance === true || isWithoutAdvance === 1;
    const finalGoodsPrice = isNoAdvance ? 0.00 : (parseFloat(goodsPrice || itemPrice || 0) || 0.00);

    const finalMerchantPhone = merchantPhone !== undefined
      ? (merchantPhone ? merchantPhone.toString().trim() : null)
      : (shipment.merchantPhone || null);

    await pool.query(
      `UPDATE shipments SET 
        title = ?, fromAddress = ?, toAddress = ?, 
        fromGovernorate = ?, fromArea = ?, toGovernorate = ?, toArea = ?, 
        price = ?, goodsPrice = ?, weight = ?, notes = ?, 
        isFragile = ?, isWithoutAdvance = ?, 
        toLatitude = ?, toLongitude = ?, 
        merchantLatitude = ?, merchantLongitude = ?,
        merchantPhone = ?,
        merchantId = ?
      WHERE id = ?`,
      [
        title || null,
        fromAddress,
        toAddress,
        fromGovernorate || null,
        fromArea || null,
        toGovernorate || null,
        toArea || null,
        parseFloat(price),
        finalGoodsPrice,
        weight ? parseFloat(weight) : null,
        notes || null,
        isFragile === 'true' || isFragile === true || isFragile === 1 ? 1 : 0,
        isNoAdvance ? 1 : 0,
        toLatitude ? parseFloat(toLatitude) : null,
        toLongitude ? parseFloat(toLongitude) : null,
        merchantLatitude ? parseFloat(merchantLatitude) : null,
        merchantLongitude ? parseFloat(merchantLongitude) : null,
        finalMerchantPhone,
        updatedMerchantId,
        id
      ]
    );

    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const imageUrl = `/uploads/${file.filename}`;
        await pool.query(
          'INSERT INTO shipment_images (shipmentId, imageUrl) VALUES (?, ?)',
          [id, imageUrl]
        );
      }
    }

    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('dashboard_update');
    }

    try {
      const eventData = await fetchShipmentEventData(id);
      if (eventData && io) {
        io.to('admins').emit('shipment_updated', eventData);
      }
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم تحديث الشحنة بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

const getShipmentLogs = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const logs = await getStatusLogs(pool, { shipmentId: id });
    res.status(200).json({
      status: 1,
      data: logs
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createShipment,
  getShipments,
  getShipmentById,
  getShipmentLogs,
  updateShipmentStatus,
  confirmPickup,
  confirmDelivery,
  handleCaptainResponse,
  computePricing,
  claimShipment,
  deleteShipment,
  updateShipment
};

