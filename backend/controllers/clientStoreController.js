const { getPool } = require('../config/db');
const { sendNotification } = require('../utils/notificationDispatcher');
const { notifyAdmins } = require('../utils/adminNotifier');
const { ALL_ZONES, PICKUP_ZONES, calculateZoneDeliveryFee, matchZone } = require('../utils/zoneDeliveryPricing');
const { kashierRequest, KASHIER_MERCHANT_ID } = require('../utils/kashierClient');
const {
  STORE_ORDER_STATUS,
  normalizeStoreOrderStatus,
  getArabicStoreStatus,
} = require('../constants/orderStatusConstants');
const {
  formatOpeningHoursSummary,
  checkStoreOperatingStatus,
} = require('../utils/storeHoursHelper');

// 1. GET ALL STORES
const getStores = async (req, res, next) => {
  try {
    const pool = getPool();
    const search = req.query.search ? req.query.search.trim() : '';

    let sql = `
      SELECT 
        u.id, 
        u.firstName, 
        u.lastName, 
        u.phone, 
        COALESCE(st.logo, u.profileImage) as profileImage,
        st.coverImage,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName, 
        COALESCE(NULLIF(st.description, ''), u.storeDescription) as storeDescription, 
        COALESCE(NULLIF(st.address, ''), u.storeAddress) as storeAddress,
        COALESCE(NULLIF(st.city, ''), u.city) as city,
        COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as openingHoursRaw,
        u.openingHours, 
        COALESCE(st.minOrderAmount, u.minOrderAmount, 0.00) as minOrderAmount, 
        COALESCE(u.deliveryFee, 0.00) as deliveryFee, 
        COALESCE(st.isOpen, u.isOpen, 1) as isOpen,
        COALESCE(st.latitude, u.latitude) as latitude,
        COALESCE(st.longitude, u.longitude) as longitude,
        COALESCE(NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, '')) as preparationTime,
        COALESCE(NULLIF(st.deliveryTime, ''), NULLIF(u.deliveryTime, '')) as deliveryTime,
        (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.revieweeId = u.id) as reviewAvg,
        (SELECT COUNT(*) FROM reviews r WHERE r.revieweeId = u.id) as reviewTotal,
        u.rating as fallbackRating,
        u.ratingCount as fallbackRatingCount,
        COALESCE(st.activityType, 'restaurant') as activityType,
        (SELECT COUNT(*) FROM merchant_products mp WHERE mp.merchantId = u.id AND mp.isAvailable = 1) as productsCount,
        (SELECT COUNT(*) FROM merchant_categories mc WHERE mc.merchantId = u.id) as categoriesCount
      FROM users u
      LEFT JOIN stores st ON st.merchantId = u.id
      WHERE u.role = 'merchant' AND u.status = 'active'
        AND (st.id IS NULL OR (st.deletedAt IS NULL AND st.status = 'active'))
    `;

    const params = [];
    const activityType = req.query.activityType ? req.query.activityType.trim() : '';
    if (activityType && activityType !== 'all') {
      sql += ' AND COALESCE(st.activityType, "restaurant") = ?';
      params.push(activityType);
    }
    if (search) {
      sql += ' AND (u.storeName LIKE ? OR u.storeDescription LIKE ? OR u.firstName LIKE ? OR u.lastName LIKE ? OR st.name LIKE ?)';
      const s = `%${search}%`;
      params.push(s, s, s, s, s);
    }

    sql += ' ORDER BY isOpen DESC, u.id DESC';

    const [rows] = await pool.query(sql, params);

    const stores = rows.map((s) => {
      const realRating = s.reviewAvg !== null ? parseFloat(s.reviewAvg) : (s.fallbackRating ? parseFloat(s.fallbackRating) : null);
      const realRatingCount = s.reviewAvg !== null ? parseInt(s.reviewTotal, 10) : (s.fallbackRatingCount ? parseInt(s.fallbackRatingCount, 10) : 0);
      const opStatus = checkStoreOperatingStatus(s.openingHoursRaw || s.openingHours, s.isOpen);

      return {
        id: s.id,
        storeName: s.storeName,
        storeDescription: s.storeDescription || '',
        storeAddress: s.storeAddress || '',
        city: s.city || s.storeAddress || '',
        phone: '',
        profileImage: s.profileImage,
        coverImage: s.coverImage,
        preparationTime: s.preparationTime || null,
        deliveryTime: s.deliveryTime || null,
        openingHours: opStatus.summary,
        minOrderAmount: parseFloat(s.minOrderAmount || 0),
        deliveryFee: parseFloat(s.deliveryFee || 0),
        isOpen: opStatus.isOpen,
        latitude: s.latitude ? parseFloat(s.latitude) : null,
        longitude: s.longitude ? parseFloat(s.longitude) : null,
        rating: realRating,
        ratingCount: realRatingCount,
        productsCount: parseInt(s.productsCount || 0, 10),
        categoriesCount: parseInt(s.categoriesCount || 0, 10),
        activityType: s.activityType || 'restaurant',
      };
    });

    // Sort: open stores first, then by id descending
    stores.sort((a, b) => (b.isOpen === a.isOpen ? 0 : b.isOpen ? 1 : -1));

    return res.status(200).json({
      status: 1,
      message: 'تم جلب المتاجر بنجاح',
      data: stores
    });
  } catch (error) {
    console.error('getStores Error:', error);
    next(error);
  }
};

// 2. GET STORE DETAILS WITH CATEGORIES & PRODUCTS
const getStoreDetails = async (req, res, next) => {
  try {
    const pool = getPool();
    const storeId = parseInt(req.params.id, 10);

    if (isNaN(storeId)) {
      return res.status(400).json({ status: 0, message: 'معرف المتجر غير صالح' });
    }

    // 1. Store profile
    const [storeRows] = await pool.query(
      `SELECT 
        u.id, u.firstName, u.lastName, u.phone, 
        COALESCE(st.logo, u.profileImage) as profileImage,
        st.coverImage,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(NULLIF(st.description, ''), u.storeDescription) as storeDescription, 
        COALESCE(NULLIF(st.address, ''), u.storeAddress) as storeAddress, 
        COALESCE(NULLIF(st.city, ''), u.city) as city, 
        COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as openingHoursRaw,
        u.openingHours, 
        COALESCE(st.minOrderAmount, u.minOrderAmount, 0.00) as minOrderAmount, 
        COALESCE(u.deliveryFee, 0.00) as deliveryFee, 
        COALESCE(st.isOpen, u.isOpen, 1) as isOpen,
        COALESCE(st.latitude, u.latitude) as latitude, 
        COALESCE(st.longitude, u.longitude) as longitude,
        COALESCE(NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, '')) as preparationTime,
        COALESCE(NULLIF(st.deliveryTime, ''), NULLIF(u.deliveryTime, '')) as deliveryTime,
        (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.revieweeId = u.id) as reviewAvg,
        (SELECT COUNT(*) FROM reviews r WHERE r.revieweeId = u.id) as reviewTotal,
        u.rating as fallbackRating,
        u.ratingCount as fallbackRatingCount,
        COALESCE(st.activityType, 'restaurant') as activityType
       FROM users u
       LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
       WHERE (u.id = ? OR st.id = ?) AND u.role = 'merchant' AND u.status = 'active'`,
      [storeId, storeId]
    );

    if (storeRows.length === 0) {
      return res.status(404).json({ status: 0, message: 'المتجر غير موجود أو غير متاح حالياً' });
    }

    const s = storeRows[0];
    const realRating = s.reviewAvg !== null ? parseFloat(s.reviewAvg) : (s.fallbackRating ? parseFloat(s.fallbackRating) : null);
    const realRatingCount = s.reviewAvg !== null ? parseInt(s.reviewTotal, 10) : (s.fallbackRatingCount ? parseInt(s.fallbackRatingCount, 10) : 0);

    const opStatus = checkStoreOperatingStatus(s.openingHoursRaw || s.openingHours, s.isOpen);

    const store = {
      id: s.id,
      storeName: s.storeName,
      storeDescription: s.storeDescription || '',
      storeAddress: s.storeAddress || '',
      city: s.city || s.storeAddress || '',
      phone: '',
      profileImage: s.profileImage,
      coverImage: s.coverImage,
      preparationTime: s.preparationTime || null,
      deliveryTime: s.deliveryTime || null,
      openingHours: opStatus.summary,
      minOrderAmount: parseFloat(s.minOrderAmount || 0),
      deliveryFee: parseFloat(s.deliveryFee || 0),
      isOpen: opStatus.isOpen,
      latitude: s.latitude ? parseFloat(s.latitude) : null,
      longitude: s.longitude ? parseFloat(s.longitude) : null,
      rating: realRating,
      ratingCount: realRatingCount,
      activityType: s.activityType || 'restaurant',
    };

    // 2. Categories
    const [categories] = await pool.query(
      `SELECT id, name, icon, image, sortOrder 
       FROM merchant_categories 
       WHERE merchantId = ? 
       ORDER BY sortOrder ASC, id ASC`,
      [s.id]
    );

    // 3. Products
    const [productsRaw] = await pool.query(
      `SELECT p.id, p.categoryId, p.name, p.description, p.price, p.discountPrice, 
              p.image, p.images, p.sizes, p.addons, p.isAvailable, p.notes,
              c.name as categoryName,
              COALESCE((SELECT ROUND(AVG(rating), 1) FROM reviews r WHERE r.productId = p.id), p.rating, 0.0) as rating,
              COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.productId = p.id), p.ratingCount, 0) as ratingCount,
              COALESCE(NULLIF(p.preparationTime, ''), NULLIF(u.preparationTime, '')) as preparationTime
       FROM merchant_products p
       JOIN users u ON p.merchantId = u.id
       LEFT JOIN merchant_categories c ON p.categoryId = c.id
       WHERE p.merchantId = ? AND p.isAvailable = 1
       ORDER BY p.id DESC`,
      [s.id]
    );

    const products = productsRaw.map((p) => {
      let parsedSizes = [];
      if (p.sizes) {
        try {
          parsedSizes = typeof p.sizes === 'string' ? JSON.parse(p.sizes) : p.sizes;
        } catch (_) {}
      }

      let parsedAddons = [];
      if (p.addons) {
        try {
          parsedAddons = typeof p.addons === 'string' ? JSON.parse(p.addons) : p.addons;
        } catch (_) {}
      }

      let parsedImages = [];
      if (p.images) {
        try {
          parsedImages = typeof p.images === 'string' ? JSON.parse(p.images) : p.images;
        } catch (_) {}
      }

      return {
        id: p.id,
        categoryId: p.categoryId,
        categoryName: p.categoryName || '',
        name: p.name,
        description: p.description || '',
        price: parseFloat(p.price || 0),
        discountPrice: p.discountPrice ? parseFloat(p.discountPrice) : null,
        image: p.image,
        images: parsedImages,
        sizes: parsedSizes,
        addons: parsedAddons,
        isAvailable: p.isAvailable === 1 || p.isAvailable === true,
        rating: parseFloat(p.rating || 0.0),
        ratingCount: parseInt(p.ratingCount || 0, 10),
        preparationTime: p.preparationTime || null,
        notes: p.notes,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب تفاصيل المتجر بنجاح',
      data: {
        store,
        categories,
        products
      }
    });
  } catch (error) {
    console.error('getStoreDetails Error:', error);
    next(error);
  }
};

// 3. GET ALL PRODUCTS ACROSS STORES (E-COMMERCE FEED)
const getAllProducts = async (req, res, next) => {
  try {
    const pool = getPool();
    const { storeId, categoryId, search } = req.query;

    let sql = `
      SELECT 
        p.id, p.merchantId, p.categoryId, p.name, p.description, p.price, p.discountPrice, 
        p.image, p.images, p.sizes, p.addons, p.isAvailable, p.notes,
        c.name as categoryName,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(st.logo, u.profileImage) as storeImage,
        COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as storeOpeningHoursRaw,
        u.openingHours as storeOpeningHours,
        COALESCE(st.isOpen, u.isOpen, 1) as storeIsOpen,
        COALESCE((SELECT ROUND(AVG(rating), 1) FROM reviews r WHERE r.productId = p.id), p.rating, 0.0) as rating,
        COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.productId = p.id), p.ratingCount, 0) as ratingCount,
        COALESCE(NULLIF(p.preparationTime, ''), NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, ''), '15-25 دقيقة') as preparationTime
      FROM merchant_products p
      JOIN users u ON p.merchantId = u.id
      LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
      LEFT JOIN merchant_categories c ON p.categoryId = c.id
      WHERE u.role = 'merchant' AND u.status = 'active' AND p.isAvailable = 1
    `;

    const params = [];

    if (storeId && !isNaN(parseInt(storeId, 10))) {
      sql += ' AND p.merchantId = ?';
      params.push(parseInt(storeId, 10));
    }

    if (categoryId && !isNaN(parseInt(categoryId, 10))) {
      sql += ' AND p.categoryId = ?';
      params.push(parseInt(categoryId, 10));
    }

    if (search && search.trim().length > 0) {
      sql += ' AND (p.name LIKE ? OR p.description LIKE ? OR u.storeName LIKE ?)';
      const s = `%${search.trim()}%`;
      params.push(s, s, s);
    }

    sql += ' ORDER BY p.id DESC';

    const [rows] = await pool.query(sql, params);

    const products = rows.map((p) => {
      let parsedSizes = [];
      if (p.sizes) {
        try {
          parsedSizes = typeof p.sizes === 'string' ? JSON.parse(p.sizes) : p.sizes;
        } catch (_) {}
      }

      let parsedAddons = [];
      if (p.addons) {
        try {
          parsedAddons = typeof p.addons === 'string' ? JSON.parse(p.addons) : p.addons;
        } catch (_) {}
      }

      let parsedImages = [];
      if (p.images) {
        try {
          parsedImages = typeof p.images === 'string' ? JSON.parse(p.images) : p.images;
        } catch (_) {}
      }

      const opStatus = checkStoreOperatingStatus(p.storeOpeningHoursRaw || p.storeOpeningHours, p.storeIsOpen);

      return {
        id: p.id,
        merchantId: p.merchantId,
        storeName: p.storeName,
        storeImage: p.storeImage,
        storeOpeningHours: opStatus.summary,
        storeIsOpen: opStatus.isOpen,
        categoryId: p.categoryId,
        categoryName: p.categoryName || '',
        name: p.name,
        description: p.description || '',
        price: parseFloat(p.price || 0),
        discountPrice: p.discountPrice ? parseFloat(p.discountPrice) : null,
        image: p.image,
        images: parsedImages,
        sizes: parsedSizes,
        addons: parsedAddons,
        isAvailable: p.isAvailable === 1 || p.isAvailable === true,
        rating: parseFloat(p.rating || 0.0),
        ratingCount: parseInt(p.ratingCount || 0, 10),
        preparationTime: p.preparationTime || '15-25 دقيقة',
        notes: p.notes,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب المنتجات بنجاح',
      data: products
    });
  } catch (error) {
    console.error('getAllProducts Error:', error);
    next(error);
  }
};

// 4. PLACE ORDER AT STORE
const placeStoreOrder = async (req, res, next) => {
  const pool = getPool();
  const conn = await pool.getConnection();
  try {
    const storeId = parseInt(req.params.id, 10);
    const clientId = req.user.id;

    if (isNaN(storeId)) {
      conn.release();
      return res.status(400).json({ status: 0, message: 'معرف المتجر غير صالح' });
    }

    let items = req.body.items;
    if (typeof items === 'string') {
      try {
        items = JSON.parse(items);
      } catch (e) {
        items = [];
      }
    }

    const {
      deliveryAddress,
      phone: rawPhone,
      customerPhone,
      clientName: rawClientName,
      customerName,
      notes,
      latitude,
      longitude,
      scheduleType = 'now',
      scheduledDate,
      scheduledTime,
      scheduledAt: rawScheduledAt,
      serviceFee: rawServiceFee,
      tip: rawTip,
      paymentMethod = 'cash',
      fromPhone: rawFromPhone,
      fromName: rawFromName,
      couponCode,
    } = req.body;

    const phone = (rawPhone || customerPhone || (req.user && req.user.phone) || '').toString().trim();

    if (!items || !Array.isArray(items) || items.length === 0) {
      conn.release();
      return res.status(400).json({ status: 0, message: 'يجب اختيار منتج واحد على الأقل لإتمام الطلب' });
    }

    if (!deliveryAddress || deliveryAddress.trim().length === 0) {
      conn.release();
      return res.status(400).json({ status: 0, message: 'عنوان التوصيل مطلوب' });
    }

    if (!phone || phone.length === 0) {
      conn.release();
      return res.status(400).json({ status: 0, message: 'رقم الهاتف للتواصل مطلوب' });
    }

    // 1. Fetch store info
    const [storeRows] = await conn.query(
      `SELECT u.id, u.storeName, u.firstName, u.lastName, u.phone as storePhone, u.city, u.storeAddress, u.deliveryFee, u.minOrderAmount,
              COALESCE(st.isOpen, u.isOpen, 1) as isOpen,
              COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as openingHours
       FROM users u
       LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
       WHERE (u.id = ? OR st.id = ?) AND u.role = 'merchant'`,
      [storeId, storeId]
    );

    if (storeRows.length === 0) {
      conn.release();
      return res.status(404).json({ status: 0, message: 'المتجر غير موجود' });
    }

    const store = storeRows[0];
    const opStatus = checkStoreOperatingStatus(store.openingHours, store.isOpen);
    if (!opStatus.isOpen && scheduleType === 'now') {
      conn.release();
      return res.status(400).json({
        status: 0,
        message: `عذراً، المتجر مغلق حالياً (${opStatus.reason}). مواعيد العمل: ${opStatus.summary}`
      });
    }

    // 2. Calculate items total price
    let orderPrice = 0;
    const itemSummaries = [];

    for (const item of items) {
      const q = parseInt(item.quantity || 1, 10);
      const unitP = parseFloat(item.unitPrice || item.price || 0);
      const totalP = parseFloat(item.totalPrice || (unitP * q));
      orderPrice += totalP;

      const sizeStr = item.size ? ` (${item.size})` : '';
      itemSummaries.push(`${q}x ${item.productName || 'منتج'}${sizeStr}`);
    }

    // Calculate delivery fee based on store zone and client zone
    const toZone = (req.body.deliveryLocation || req.body.clientCity || req.body.toZone || '').toString().trim();
    const fromZone = (store.city || store.storeAddress || 'الهانوفيل').toString().trim();
    let deliveryFee = 35.00;
    if (req.body.deliveryFee !== undefined && !isNaN(parseFloat(req.body.deliveryFee))) {
      deliveryFee = parseFloat(req.body.deliveryFee);
    } else {
      deliveryFee = calculateZoneDeliveryFee(fromZone, toZone);
    }

    // Coupon validation & processing
    let discountApplied = 0.00;
    let appliedCouponCode = null;

    if (couponCode && couponCode.toString().trim().length > 0) {
      const { processCoupon } = require('../utils/couponHelper');
      try {
        const couponResult = await processCoupon(conn, {
          code: couponCode.toString().trim(),
          price: (orderPrice + deliveryFee),
          userId: clientId,
          isShipment: false,
          entityId: null,
          deliveryFee: deliveryFee,
          orderPrice: orderPrice
        });
        discountApplied = couponResult.discountApplied;
        appliedCouponCode = couponResult.couponCode;
      } catch (couponErr) {
        conn.release();
        return res.status(400).json({ status: 0, message: couponErr.message });
      }
    }

    // Dynamic Service fee from app_settings (fallback 5.00 EGP) & tip
    let defaultServiceFee = 5.00;
    try {
      const [feeRows] = await conn.query("SELECT `value` FROM app_settings WHERE `key` = 'store_service_fee' LIMIT 1");
      if (feeRows.length > 0 && feeRows[0].value !== null && feeRows[0].value !== '') {
        const parsedFee = parseFloat(feeRows[0].value);
        if (!isNaN(parsedFee)) defaultServiceFee = parsedFee;
      }
    } catch (_) {}
    const serviceFee = req.body.serviceFee !== undefined ? (parseFloat(req.body.serviceFee) || 0.00) : defaultServiceFee;
    const tip = parseFloat(rawTip || 0.00) || 0.00;
    const totalAmount = parseFloat(Math.max((orderPrice + deliveryFee - discountApplied + serviceFee + tip), 0.00).toFixed(2));

    // Scheduling
    const finalScheduleType = scheduleType === 'scheduled' ? 'scheduled' : 'now';
    let scheduledAt = null;
    if (finalScheduleType === 'scheduled') {
      if (rawScheduledAt) {
        const d = new Date(rawScheduledAt);
        if (!isNaN(d.getTime())) {
          scheduledAt = d.toISOString().slice(0, 19).replace('T', ' ');
        }
      } else if (scheduledDate) {
        const timeStr = (scheduledTime || '00:00:00').toString().trim();
        const formattedTime = timeStr.length === 5 ? `${timeStr}:00` : timeStr;
        scheduledAt = `${scheduledDate} ${formattedTime}`.slice(0, 19);
      }
    }

    const orderNumber = 'ORD' + Date.now().toString().substring(4) + Math.floor(100 + Math.random() * 900);
    const detailsText = itemSummaries.join(', ');
    const storeDisplayName = store.storeName || `${store.firstName} ${store.lastName}`.trim() || 'متجر';

    const nameCandidate = (rawClientName || customerName || '').toString().trim();
    let clientName = nameCandidate.length > 0 ? nameCandidate : null;
    if (!clientName && req.user) {
      clientName = `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || 'عميل';
    }

    // Direct payment / Cash logic
    const isDirectPayment = paymentMethod !== 'cash';
    let paymentRef = null;
    let paymentSessionId = req.body.paymentSessionId || null;
    let paymentStatus = 'unpaid';
    let isPaid = 0;

    if (isDirectPayment) {
      paymentRef = `PAY-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`;
      paymentSessionId = paymentRef;
      paymentStatus = 'pending_verification';
    }

    const platformShare = parseFloat((deliveryFee * 0.20).toFixed(2));
    const captainShare = parseFloat((deliveryFee * 0.80).toFixed(2));

    const { findActiveShiftForOrder } = require('../utils/shiftMatcher');
    const shiftId = await findActiveShiftForOrder({
      merchantId: storeId,
      conn,
    });

    // Resolve store and merchant IDs and commission rates
    const [realStoreRows] = await conn.query(
      'SELECT id, merchantId, commissionRate, commissionType FROM stores WHERE (id = ? OR merchantId = ?) AND deletedAt IS NULL LIMIT 1',
      [storeId, storeId]
    );
    const resolvedStoreId = realStoreRows.length > 0 ? realStoreRows[0].id : null;
    const resolvedMerchantId = realStoreRows.length > 0 ? realStoreRows[0].merchantId : storeId;
    const commRate = realStoreRows.length > 0 ? realStoreRows[0].commissionRate : 5.0;
    const commType = realStoreRows.length > 0 ? realStoreRows[0].commissionType : 'percentage';

    const { calculateOrderCommission } = require('../utils/commissionCalculator');
    const commResult = calculateOrderCommission({
      orderPrice,
      commissionRate: commRate,
      commissionType: commType,
    });

    // 3. Statuses and initial flags based on payment method
    const initialStatus = isDirectPayment ? 'بانتظار تأكيد الدفع' : getArabicStoreStatus(STORE_ORDER_STATUS.UNDER_REVIEW);
    const initialStoreOrderStatus = isDirectPayment ? 'WAITING_PAYMENT_APPROVAL' : STORE_ORDER_STATUS.UNDER_REVIEW;
    const initialCaptainTripStatus = isDirectPayment ? 'WAITING_PAYMENT_APPROVAL' : 'PENDING_ASSIGNMENT';
    const initialPaymentStatus = isDirectPayment ? 'pending' : 'unpaid';
    const initialIsPaid = 0;

    // Insert order with schedule, fees, and statuses
    const [orderResult] = await conn.query(
      `INSERT INTO orders (
        orderNumber, merchantId, storeId, clientId, details, storeDescription, notes,
        deliveryAddress, clientName, phone, orderPrice, deliveryFee, serviceFee, tip,
        scheduleType, scheduledAt,
        latitude, longitude, status, platformShare, captainShare,
        isPaid, paymentMethod, paymentSessionId, paymentStatus, shift_id,
        platformCommission, merchantNet, commissionRateSnapshot, commissionTypeSnapshot,
        orderType, storeOrderStatus, captainTripStatus, couponCode, discountApplied
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'store', ?, ?, ?, ?)`,
      [
        orderNumber,
        resolvedMerchantId,
        resolvedStoreId,
        clientId,
        detailsText,
        storeDisplayName,
        notes || null,
        deliveryAddress.trim(),
        clientName,
        phone.trim(),
        orderPrice,
        deliveryFee,
        serviceFee,
        tip,
        finalScheduleType,
        scheduledAt,
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null,
        initialStatus,
        platformShare,
        captainShare,
        initialIsPaid,
        paymentMethod,
        paymentSessionId,
        initialPaymentStatus,
        shiftId || null,
        commResult.platformCommission,
        commResult.merchantNet,
        commResult.rateSnapshot,
        commResult.typeSnapshot,
        initialStoreOrderStatus,
        initialCaptainTripStatus,
        appliedCouponCode,
        discountApplied,
      ]
    );

    const orderId = orderResult.insertId;

    // Update coupon_usages table with actual orderId
    if (appliedCouponCode) {
      await conn.query(
        "UPDATE coupon_usages SET orderId = ? WHERE userId = ? AND shipmentId IS NULL AND orderId IS NULL ORDER BY usedAt DESC LIMIT 1",
        [orderId, clientId]
      );
    }

    // 4. Insert order_items
    for (const item of items) {
      const q = parseInt(item.quantity || 1, 10);
      const unitP = parseFloat(item.unitPrice || item.price || 0);
      const totalP = parseFloat(item.totalPrice || (unitP * q));
      let addonsJson = null;
      if (item.addons) {
        addonsJson = typeof item.addons === 'string' ? item.addons : JSON.stringify(item.addons);
      }

      await conn.query(
        `INSERT INTO order_items (
          orderId, productId, productName, productImage, size, addons, quantity, unitPrice, totalPrice, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId,
          item.productId ? parseInt(item.productId, 10) : null,
          item.productName || 'منتج',
          item.productImage || null,
          item.size || null,
          addonsJson,
          q,
          unitP,
          totalP,
          item.notes || null,
        ]
      );
    }

    // 5. If direct payment (e-wallet / InstaPay), create direct_payments record
    if (isDirectPayment) {
      const receiptImage = req.file ? req.file.filename : null;
      const paymentFromPhone = (rawFromPhone || phone || '').toString().trim();
      const paymentFromName = (rawFromName || clientName || '').toString().trim();

      await conn.query(
        `INSERT INTO direct_payments (
          paymentRef, merchantId, clientId, orderId, amount, paymentMethod, fromPhone, fromName, receiptImage, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
        [
          paymentRef,
          resolvedMerchantId,
          clientId,
          orderId,
          totalAmount,
          paymentMethod,
          paymentFromPhone,
          paymentFromName,
          receiptImage,
        ]
      );
    }

    await conn.commit();
    conn.release();

    // 6. Notifications and Socket Events
    try {
      const io = req.app.get('io');

      if (isDirectPayment) {
        // Direct Payment (E-Wallet / InstaPay):
        // Hold order confirmation to merchant until Admin explicitly approves!
        try {
          const { notifyAdmins } = require('../utils/adminNotifier');
          await notifyAdmins(
            io,
            '🧾 إيصال دفع جديد لطلب متجر',
            `قام العميل ${clientName} برفع إيصال دفع بقيمة ${totalAmount} ج.م للطلب رقم #${orderNumber} (${paymentMethod}). بانتظار مراجعتك واعتمادك.`,
            'payment',
            {
              type: 'direct_payment_submitted',
              orderId: orderId.toString(),
              itemNumber: orderNumber,
              amount: totalAmount.toString(),
              paymentRef,
            }
          );
        } catch (adminNotifErr) {
          console.error('Error notifying admins of direct payment:', adminNotifErr);
        }

        if (io) {
          io.to('admins').emit('new_direct_payment', {
            paymentRef,
            amount: totalAmount,
            itemNumber: orderNumber,
            paymentMethod,
            clientName,
            phone,
            storeName: storeDisplayName,
            orderDetails: detailsText,
          });
          io.to('admins').emit('dashboard_update');
        }

        // Notify client that payment receipt is under review
        await sendNotification(
          io,
          clientId,
          '⏳ إيصال التحويل قيد المراجعة',
          `تم استلام إيصال التحويل لطلبك رقم #${orderNumber} بنجاح، ويقوم فريق الإدارة بمراجعته الآن لتأكيد طلبك.`,
          'order',
          { type: 'payment_under_review', orderId: orderId.toString(), orderNumber, paymentRef }
        );

      } else {
        // Cash on delivery: Order is created under review for Admin Panel.
        // It must NOT reach the merchant until Admin reviews and forwards it!
        if (!isDirectPayment) {
          // Notify customer: order created and is currently under review
          await sendNotification(
            io,
            clientId,
            '🎉 تم إنشاء طلبك',
            `تم إنشاء طلبك رقم #${orderNumber} بنجاح وهو قيد المراجعة حالياً من قبل الإدارة.`,
            'order',
            { type: 'order_created', orderId: orderId.toString(), orderNumber, storeOrderStatus: STORE_ORDER_STATUS.UNDER_REVIEW }
          );

          // Notify Admin with priority alert: review order and contact merchant
          try {
            await notifyAdmins(
              io,
              'طلب متجر جديد (قيد المراجعة) 🔔',
              `طلب متجر جديد #${orderNumber} من ${storeDisplayName} قيد المراجعة - يرجى تأكيد توافر الطلب مع المتجر وإرساله`,
              'order',
              { 
                type: 'new_store_order', 
                orderId: orderId.toString(), 
                orderNumber, 
                storeOrderStatus: STORE_ORDER_STATUS.UNDER_REVIEW,
                needsReview: true
              }
            );
          } catch (adminErr) {
            console.error('Failed to notify admins of new store order:', adminErr);
          }
        }

        if (io) {
          io.to(`user_${clientId}`).emit('order_created', {
            id: orderId.toString(),
            orderNumber,
            storeName: storeDisplayName,
            orderPrice,
            deliveryFee,
            serviceFee,
            tip,
            totalAmount,
            scheduleType: finalScheduleType,
            scheduledAt,
            status: initialStatus,
            storeOrderStatus: initialStoreOrderStatus,
            createdAt: new Date().toISOString()
          });

          // Standard ORDER_CREATED event for shifts system & admin real-time sync
          const orderEventPayload = {
            orderId: orderId.toString(),
            id: orderId.toString(),
            orderNumber,
            shipmentId: null,
            shiftId: shiftId ? shiftId.toString() : null,
            captainId: null,
            orderType: 'store',
            status: initialStatus,
            storeOrderStatus: initialStoreOrderStatus,
            merchantId: storeId.toString(),
            storeName: storeDisplayName,
            clientName,
            phone,
            deliveryAddress: deliveryAddress.trim(),
            orderPrice,
            deliveryFee,
            serviceFee,
            tip,
            totalAmount,
            scheduleType: finalScheduleType,
            scheduledAt,
            createdAt: new Date().toISOString()
          };

          io.to('admins').emit('ORDER_CREATED', orderEventPayload);
          io.to('admins').emit('order_created', orderEventPayload);
          io.to('admins').emit('new_store_order', orderEventPayload);
          io.to('admins').emit('store_order_created', orderEventPayload);
          io.to('admins').emit('dashboard_update');

          if (shiftId) {
            io.to(`shift_${shiftId}`).emit('ORDER_CREATED', orderEventPayload);
            io.to(`shift:${shiftId}`).emit('ORDER_CREATED', orderEventPayload);
          }
        }
      }
    } catch (notifErr) {
      console.error('Notification error on placeStoreOrder:', notifErr);
    }

    return res.status(201).json({
      status: 1,
      message: isDirectPayment
        ? 'تم إرسال إيصال الدفع بنجاح وجارٍ مراجعته من قبل الإدارة لتأكيد الطلب'
        : 'تم إرسال طلبك إلى المتجر بنجاح وجارٍ متابعته',
      data: {
        isDirectPayment,
        paymentRef: isDirectPayment ? paymentRef : null,
        orderId,
        orderNumber,
        storeName: storeDisplayName,
        orderPrice,
        deliveryFee,
        serviceFee,
        tip,
        couponCode: appliedCouponCode,
        discountApplied,
        totalAmount,
        scheduleType: finalScheduleType,
        scheduledAt,
        paymentMethod,
        paymentStatus: initialPaymentStatus,
        status: initialStatus
      }
    });

  } catch (error) {
    if (conn) {
      try { await conn.rollback(); } catch (_) {}
      try { conn.release(); } catch (_) {}
    }
    console.error('placeStoreOrder Error:', error);
    next(error);
  }
};

// 5. GET ADVERTISING BANNERS (بنرات إعلانات المطاعم والمتاجر)
const getBanners = async (req, res, next) => {
  try {
    const pool = getPool();

    // Ensure store_banners table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS store_banners (
        id INT AUTO_INCREMENT PRIMARY KEY,
        merchantId INT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT NULL,
        image VARCHAR(500) NOT NULL,
        badge VARCHAR(100) DEFAULT 'إعلان مميز',
        actionType VARCHAR(50) DEFAULT 'store',
        actionValue VARCHAR(255) NULL,
        isActive TINYINT(1) DEFAULT 1,
        showPopup TINYINT(1) DEFAULT 1,
        displayOrder INT DEFAULT 0,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Fetch active banners from table
    const [bannerRows] = await pool.query(`
      SELECT 
        b.id,
        b.merchantId,
        b.storeId,
        b.title,
        b.description,
        b.image,
        b.badge,
        b.actionType,
        b.actionValue,
        b.showPopup,
        COALESCE(s.name, NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), '') as storeName,
        COALESCE(s.logo, u.profileImage) as storeImage,
        COALESCE(s.phone, u.phone) as storePhone,
        COALESCE(NULLIF(u.openingHours, ''), s.openingHours) as storeOpeningHoursRaw,
        COALESCE(s.openingHours, u.openingHours, '10:00 ص - 02:00 ص') as storeOpeningHours,
        COALESCE(s.isOpen, u.isOpen, 1) as storeIsOpen
      FROM store_banners b
      LEFT JOIN stores s ON (b.storeId = s.id OR (b.storeId IS NULL AND b.merchantId = s.merchantId))
      LEFT JOIN users u ON (b.merchantId = u.id OR s.merchantId = u.id)
      WHERE b.isActive = 1
        AND (
          (s.id IS NOT NULL AND s.deletedAt IS NULL AND s.status = 'active')
          OR (s.id IS NULL AND u.id IS NOT NULL AND u.status = 'active')
          OR (b.storeId IS NULL AND b.merchantId IS NULL)
        )
      ORDER BY b.displayOrder ASC, b.id DESC
    `);

    let banners = bannerRows.map((b) => ({
      id: b.id,
      merchantId: b.merchantId,
      storeId: b.storeId,
      storeName: b.storeName || b.title,
      storeImage: b.storeImage || null,
      storeOpeningHours: formatOpeningHoursSummary(b.storeOpeningHoursRaw || b.storeOpeningHours),
      storeIsOpen: b.storeIsOpen === 1 || b.storeIsOpen === true,
      title: b.title,
      description: b.description || '',
      image: b.image,
      badge: b.badge || 'إعلان مميز',
      actionType: b.actionType || 'store',
      actionValue: b.actionValue || (b.storeId ? b.storeId.toString() : (b.merchantId ? b.merchantId.toString() : '')),
      showPopup: b.showPopup === 1 || b.showPopup === true,
    }));

    // If no manual banners exist in database yet, auto-create dynamic promotional banners from active merchants
    if (banners.length === 0) {
      const [merchants] = await pool.query(`
        SELECT 
          u.id,
          COALESCE(NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
          u.storeDescription,
          u.profileImage,
          COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as openingHoursRaw,
          u.openingHours,
          COALESCE(st.isOpen, u.isOpen, 1) as isOpen,
          (SELECT image FROM merchant_products WHERE merchantId = u.id AND image IS NOT NULL AND image != '' LIMIT 1) as sampleProductImage
        FROM users u
        LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
        WHERE u.role = 'merchant' AND u.status = 'active'
        ORDER BY u.id DESC
        LIMIT 5
      `);

      for (const m of merchants) {
        const bannerImg = m.sampleProductImage || m.profileImage || '';
        if (bannerImg) {
          banners.push({
            id: m.id,
            merchantId: m.id,
            storeName: m.storeName,
            storeImage: m.profileImage,
            storeOpeningHours: formatOpeningHoursSummary(m.openingHoursRaw || m.openingHours),
            storeIsOpen: m.isOpen === 1 || m.isOpen === true,
            title: `عروض خاصة من ${m.storeName}`,
            description: m.storeDescription || 'اطلب الآن أشهى المأكولات والمنتجات الطازجة مع توصيل سريع لحد باب بيتك!',
            image: bannerImg,
            badge: 'إعلان مميز',
            actionType: 'store',
            actionValue: m.id.toString(),
            showPopup: true,
          });
        }
      }
    }

    return res.status(200).json({
      status: 1,
      message: 'تم جلب البنرات الإعلانية بنجاح',
      data: banners,
    });
  } catch (error) {
    console.error('getBanners Error:', error);
    next(error);
  }
};

// 5.1 GET OFFERS & PROMOTIONAL DEALS (قسم العروض والتخفيضات)
const getOffers = async (req, res, next) => {
  try {
    const pool = getPool();
    const { categoryId, storeId, search } = req.query;

    // 1. Fetch active banners
    let [banners] = await pool.query(`
      SELECT 
        b.id,
        b.merchantId,
        b.storeId,
        b.title,
        b.description,
        b.image,
        b.badge,
        b.actionType,
        b.actionValue,
        b.showPopup,
        COALESCE(s.name, NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(s.logo, u.profileImage) as storeImage,
        COALESCE(s.isOpen, u.isOpen, 1) as storeIsOpen
      FROM store_banners b
      LEFT JOIN stores s ON (b.storeId = s.id OR (b.storeId IS NULL AND b.merchantId = s.merchantId))
      LEFT JOIN users u ON (b.merchantId = u.id OR s.merchantId = u.id)
      WHERE b.isActive = 1
      ORDER BY b.displayOrder ASC, b.id DESC
    `);

    // 2. Fetch all products that have discounts / active offers
    let sql = `
      SELECT 
        p.id, p.merchantId, p.categoryId, p.name, p.description, p.price, p.discountPrice, 
        p.image, p.images, p.sizes, p.addons, p.isAvailable, p.notes,
        c.name as categoryName,
        ROUND(((p.price - p.discountPrice) / p.price) * 100) as discountPercentage,
        ROUND(p.price - p.discountPrice, 2) as savingsAmount,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(st.logo, u.profileImage) as storeImage,
        COALESCE(st.isOpen, u.isOpen, 1) as storeIsOpen,
        COALESCE((SELECT ROUND(AVG(rating), 1) FROM reviews r WHERE r.productId = p.id), p.rating, 0.0) as rating,
        COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.productId = p.id), p.ratingCount, 0) as ratingCount,
        COALESCE(NULLIF(p.preparationTime, ''), NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, ''), '15-25 دقيقة') as preparationTime
      FROM merchant_products p
      JOIN users u ON p.merchantId = u.id
      LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
      LEFT JOIN merchant_categories c ON p.categoryId = c.id
      WHERE u.role = 'merchant' AND u.status = 'active' AND p.isAvailable = 1
        AND p.discountPrice IS NOT NULL AND p.discountPrice > 0 AND p.discountPrice < p.price
    `;

    const params = [];

    if (storeId && !isNaN(parseInt(storeId, 10))) {
      sql += ' AND p.merchantId = ?';
      params.push(parseInt(storeId, 10));
    }

    if (categoryId && !isNaN(parseInt(categoryId, 10))) {
      sql += ' AND p.categoryId = ?';
      params.push(parseInt(categoryId, 10));
    }

    if (search && search.trim().length > 0) {
      sql += ' AND (p.name LIKE ? OR p.description LIKE ? OR u.storeName LIKE ?)';
      const s = `%${search.trim()}%`;
      params.push(s, s, s);
    }

    sql += ' ORDER BY discountPercentage DESC, p.id DESC';

    const [rows] = await pool.query(sql, params);

    const products = rows.map((p) => {
      let parsedSizes = [];
      if (p.sizes) {
        try { parsedSizes = typeof p.sizes === 'string' ? JSON.parse(p.sizes) : p.sizes; } catch (_) {}
      }
      let parsedAddons = [];
      if (p.addons) {
        try { parsedAddons = typeof p.addons === 'string' ? JSON.parse(p.addons) : p.addons; } catch (_) {}
      }
      let parsedImages = [];
      if (p.images) {
        try { parsedImages = typeof p.images === 'string' ? JSON.parse(p.images) : p.images; } catch (_) {}
      }
      return {
        ...p,
        price: parseFloat(p.price),
        discountPrice: p.discountPrice ? parseFloat(p.discountPrice) : null,
        discountPercentage: parseInt(p.discountPercentage) || 0,
        savingsAmount: parseFloat(p.savingsAmount) || 0,
        rating: parseFloat(p.rating || 0),
        ratingCount: parseInt(p.ratingCount || 0),
        storeIsOpen: p.storeIsOpen === 1 || p.storeIsOpen === true,
        sizes: parsedSizes,
        addons: parsedAddons,
        images: parsedImages,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب العروض والتخفيضات بنجاح',
      data: {
        banners: banners || [],
        products: products || [],
      },
    });
  } catch (error) {
    console.error('getOffers Error:', error);
    next(error);
  }
};

// 6. GET MOST POPULAR PRODUCTS (الأكثر طلباً)
const getMostPopularProducts = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user ? req.user.id : null;

    let sql = `
      SELECT 
        p.id, p.merchantId, p.categoryId, p.name, p.description, p.price, p.discountPrice, 
        p.image, p.images, p.sizes, p.addons, p.isAvailable, p.notes,
        c.name as categoryName,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(st.logo, u.profileImage) as storeImage,
        COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as storeOpeningHoursRaw,
        u.openingHours as storeOpeningHours,
        COALESCE(st.isOpen, u.isOpen, 1) as storeIsOpen,
        COALESCE((SELECT ROUND(AVG(rating), 1) FROM reviews r WHERE r.productId = p.id), p.rating, 0.0) as rating,
        COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.productId = p.id), p.ratingCount, 0) as ratingCount,
        COALESCE(NULLIF(p.preparationTime, ''), NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, ''), '15-25 دقيقة') as preparationTime,
        (SELECT COUNT(*) FROM order_items oi WHERE oi.productId = p.id) as orderCount,
        ${userId ? `EXISTS(SELECT 1 FROM user_favorite_products ufp WHERE ufp.userId = ${parseInt(userId, 10)} AND ufp.productId = p.id)` : '0'} as isFavorite
      FROM merchant_products p
      JOIN users u ON p.merchantId = u.id
      LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
      LEFT JOIN merchant_categories c ON p.categoryId = c.id
      WHERE u.role = 'merchant' AND u.status = 'active' AND p.isAvailable = 1
      ORDER BY orderCount DESC, p.id DESC
      LIMIT 20
    `;

    const [rows] = await pool.query(sql);

    const products = rows.map((p) => {
      let parsedSizes = [];
      if (p.sizes) {
        try {
          parsedSizes = typeof p.sizes === 'string' ? JSON.parse(p.sizes) : p.sizes;
        } catch (_) {}
      }

      let parsedAddons = [];
      if (p.addons) {
        try {
          parsedAddons = typeof p.addons === 'string' ? JSON.parse(p.addons) : p.addons;
        } catch (_) {}
      }

      let parsedImages = [];
      if (p.images) {
        try {
          parsedImages = typeof p.images === 'string' ? JSON.parse(p.images) : p.images;
        } catch (_) {}
      }

      const opStatus = checkStoreOperatingStatus(p.storeOpeningHoursRaw || p.storeOpeningHours, p.storeIsOpen);

      return {
        id: p.id,
        merchantId: p.merchantId,
        storeName: p.storeName,
        storeImage: p.storeImage,
        storeOpeningHours: opStatus.summary,
        storeIsOpen: opStatus.isOpen,
        categoryId: p.categoryId,
        categoryName: p.categoryName || '',
        name: p.name,
        description: p.description || '',
        price: parseFloat(p.price || 0),
        discountPrice: p.discountPrice ? parseFloat(p.discountPrice) : null,
        image: p.image,
        images: parsedImages,
        sizes: parsedSizes,
        addons: parsedAddons,
        isAvailable: p.isAvailable === 1 || p.isAvailable === true,
        isFavorite: p.isFavorite === 1 || p.isFavorite === true,
        rating: parseFloat(p.rating || 0.0),
        ratingCount: parseInt(p.ratingCount || 0, 10),
        preparationTime: p.preparationTime || '15-25 دقيقة',
        notes: p.notes,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب المنتجات الأكثر طلباً بنجاح',
      data: products
    });
  } catch (error) {
    console.error('getMostPopularProducts Error:', error);
    next(error);
  }
};

// 7. TOGGLE FAVORITE PRODUCT
const toggleFavoriteProduct = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const productId = parseInt(req.params.productId, 10);

    if (isNaN(productId)) {
      return res.status(400).json({ status: 0, message: 'معرف المنتج غير صالح' });
    }

    const [existing] = await pool.query(
      'SELECT id FROM user_favorite_products WHERE userId = ? AND productId = ?',
      [userId, productId]
    );

    let isFavorite = false;
    if (existing.length > 0) {
      await pool.query('DELETE FROM user_favorite_products WHERE userId = ? AND productId = ?', [userId, productId]);
      isFavorite = false;
    } else {
      await pool.query('INSERT INTO user_favorite_products (userId, productId) VALUES (?, ?)', [userId, productId]);
      isFavorite = true;
    }

    return res.status(200).json({
      status: 1,
      message: isFavorite ? 'تمت إضافة الوجبة إلى المفضلة' : 'تمت إزالة الوجبة من المفضلة',
      data: { isFavorite }
    });
  } catch (error) {
    console.error('toggleFavoriteProduct Error:', error);
    next(error);
  }
};

// 8. GET FAVORITE PRODUCTS
const getFavoriteProducts = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    const sql = `
      SELECT 
        p.id, p.merchantId, p.categoryId, p.name, p.description, p.price, p.discountPrice, 
        p.image, p.images, p.sizes, p.addons, p.isAvailable, p.notes,
        c.name as categoryName,
        COALESCE(NULLIF(st.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(st.logo, u.profileImage) as storeImage,
        COALESCE(NULLIF(u.openingHours, ''), st.openingHours) as storeOpeningHoursRaw,
        u.openingHours as storeOpeningHours,
        COALESCE(st.isOpen, u.isOpen, 1) as storeIsOpen,
        COALESCE((SELECT ROUND(AVG(rating), 1) FROM reviews r WHERE r.productId = p.id), p.rating, 0.0) as rating,
        COALESCE((SELECT COUNT(*) FROM reviews r WHERE r.productId = p.id), p.ratingCount, 0) as ratingCount,
        COALESCE(NULLIF(p.preparationTime, ''), NULLIF(st.preparationTime, ''), NULLIF(u.preparationTime, ''), '15-25 دقيقة') as preparationTime,
        1 as isFavorite
      FROM user_favorite_products ufp
      JOIN merchant_products p ON ufp.productId = p.id
      JOIN users u ON p.merchantId = u.id
      LEFT JOIN stores st ON st.merchantId = u.id AND st.deletedAt IS NULL
      LEFT JOIN merchant_categories c ON p.categoryId = c.id
      WHERE ufp.userId = ? AND u.role = 'merchant' AND u.status = 'active'
      ORDER BY ufp.id DESC
    `;

    const [rows] = await pool.query(sql, [userId]);

    const products = rows.map((p) => {
      let parsedSizes = [];
      if (p.sizes) {
        try {
          parsedSizes = typeof p.sizes === 'string' ? JSON.parse(p.sizes) : p.sizes;
        } catch (_) {}
      }

      let parsedAddons = [];
      if (p.addons) {
        try {
          parsedAddons = typeof p.addons === 'string' ? JSON.parse(p.addons) : p.addons;
        } catch (_) {}
      }

      let parsedImages = [];
      if (p.images) {
        try {
          parsedImages = typeof p.images === 'string' ? JSON.parse(p.images) : p.images;
        } catch (_) {}
      }

      const opStatus = checkStoreOperatingStatus(p.storeOpeningHoursRaw || p.storeOpeningHours, p.storeIsOpen);

      return {
        id: p.id,
        merchantId: p.merchantId,
        storeName: p.storeName,
        storeImage: p.storeImage,
        storeOpeningHours: opStatus.summary,
        storeIsOpen: opStatus.isOpen,
        categoryId: p.categoryId,
        categoryName: p.categoryName || '',
        name: p.name,
        description: p.description || '',
        price: parseFloat(p.price || 0),
        discountPrice: p.discountPrice ? parseFloat(p.discountPrice) : null,
        image: p.image,
        images: parsedImages,
        sizes: parsedSizes,
        addons: parsedAddons,
        isAvailable: p.isAvailable === 1 || p.isAvailable === true,
        isFavorite: true,
        rating: parseFloat(p.rating || 0.0),
        ratingCount: parseInt(p.ratingCount || 0, 10),
        preparationTime: p.preparationTime || '15-25 دقيقة',
        notes: p.notes,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب المنتجات المفضلة بنجاح',
      data: products
    });
  } catch (error) {
    console.error('getFavoriteProducts Error:', error);
    next(error);
  }
};

// 9. GET MAIN CATEGORIES (الأقسام والأنشطة الرئيسية للمتاجر)
const getMainCategories = async (req, res, next) => {
  try {
    const pool = getPool();

    // Query active store counts and sample images per activityType
    const [counts] = await pool.query(`
      SELECT 
        COALESCE(st.activityType, 'restaurant') as activityType,
        COUNT(DISTINCT u.id) as storeCount,
        COALESCE(NULLIF(MAX(st.coverImage), ''), NULLIF(MAX(st.logo), ''), NULLIF(MAX(u.profileImage), '')) as sampleImage
      FROM users u
      LEFT JOIN stores st ON st.merchantId = u.id
      WHERE u.role = 'merchant' AND u.status = 'active'
        AND (st.id IS NULL OR (st.deletedAt IS NULL AND st.status = 'active'))
      GROUP BY COALESCE(st.activityType, 'restaurant')
    `);

    const countMap = {};
    const imgMap = {};
    for (const c of counts) {
      countMap[c.activityType] = parseInt(c.storeCount || 0, 10);
      if (c.sampleImage) imgMap[c.activityType] = c.sampleImage;
    }

    const totalStores = Object.values(countMap).reduce((acc, curr) => acc + curr, 0);

    // Fetch from database table main_activity_categories if exists
    let dbCategories = [];
    try {
      const [rows] = await pool.query(
        'SELECT id, keyName, name, tag, icon, image FROM main_activity_categories WHERE isActive = 1 ORDER BY sortOrder ASC, id ASC'
      );
      if (rows && rows.length > 0) {
        dbCategories = rows;
      }
    } catch (_) {}

    // Fallback if table is not yet seeded
    if (dbCategories.length === 0) {
      dbCategories = [
        { id: 1, keyName: 'all', name: 'الكل', tag: 'الكل', icon: 'apps_rounded' },
        { id: 2, keyName: 'restaurant', name: 'مطاعم', tag: 'مطاعم', icon: 'restaurant_rounded' },
        { id: 3, keyName: 'supermarket', name: 'ماركت / سوبر ماركت', tag: 'ماركت', icon: 'shopping_cart_rounded' },
        { id: 4, keyName: 'bakery', name: 'مخبوزات', tag: 'مخبوزات', icon: 'bakery_dining_rounded' },
        { id: 5, keyName: 'roastery', name: 'محمصة و عطارة', tag: 'محمصة و عطارة', icon: 'grain_rounded' },
        { id: 6, keyName: 'sweets', name: 'حلويات', tag: 'حلويات', icon: 'cake_rounded' },
        { id: 7, keyName: 'vegetables', name: 'فواكه وخضروات', tag: 'فواكه وخضروات', icon: 'eco_rounded' },
        { id: 8, keyName: 'dairy', name: 'ألبان وجبن', tag: 'ألبان وجبن', icon: 'egg_rounded' },
        { id: 9, keyName: 'juices', name: 'عصائر وكوكتيلات', tag: 'عصائر وكوكتيلات', icon: 'local_drink_rounded' },
        { id: 10, keyName: 'coffee', name: 'قهوة وبُن', tag: 'قهوة وبُن', icon: 'local_cafe_rounded' },
        { id: 11, keyName: 'online', name: 'أونلاين', tag: 'أونلاين', icon: 'shopping_bag_rounded' },
        { id: 12, keyName: 'pharmacy', name: 'صيدلية', tag: 'صيدلية', icon: 'local_pharmacy_rounded' },
        { id: 13, keyName: 'clothes', name: 'ملابس وأزياء', tag: 'ملابس', icon: 'checkroom_rounded' },
        { id: 14, keyName: 'store', name: 'محل / متجر عام', tag: 'محل ومتاجر', icon: 'storefront_rounded' },
      ];
    }

    const categories = dbCategories.map((cat) => {
      const key = cat.keyName || cat.key;
      const storeCount = key === 'all' ? totalStores : (countMap[key] || 0);
      let img = cat.image || imgMap[key] || '';
      if (img && !img.startsWith('http')) {
        img = img.startsWith('/') ? img : `/${img}`;
      }

      return {
        id: cat.id,
        key: key,
        name: cat.name,
        tag: cat.tag || cat.name,
        icon: cat.icon || '',
        image: img,
        storeCount: storeCount,
      };
    });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب الأقسام الرئيسية بنجاح',
      data: categories
    });
  } catch (error) {
    console.error('getMainCategories Error:', error);
    next(error);
  }
};

// 10. GET DELIVERY ZONES
const getDeliveryZones = async (req, res, next) => {
  try {
    return res.status(200).json({
      status: 1,
      message: 'تم جلب مناطق التسعير بنجاح',
      data: {
        allZones: ALL_ZONES,
        pickupZones: PICKUP_ZONES,
      }
    });
  } catch (error) {
    console.error('getDeliveryZones Error:', error);
    next(error);
  }
};

// 11. CREATE KASHIER PAYMENT SESSION FOR STORE ORDER
const createStorePaymentSession = async (req, res, next) => {
  try {
    const pool = getPool();
    const storeId = parseInt(req.params.id, 10);
    const userId = req.user.id;

    if (isNaN(storeId)) {
      return res.status(400).json({ status: 0, message: 'معرف المتجر غير صالح' });
    }

    const {
      items,
      deliveryAddress,
      deliveryLocation,
      deliveryFee: rawDeliveryFee,
    } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ status: 0, message: 'يجب اختيار منتج واحد على الأقل' });
    }

    const [storeRows] = await pool.query(
      `SELECT id, storeName, firstName, lastName, city, storeAddress, COALESCE(isOpen, 1) as isOpen 
       FROM users WHERE id = ? AND role = 'merchant'`,
      [storeId]
    );

    if (storeRows.length === 0) {
      return res.status(404).json({ status: 0, message: 'المتجر غير موجود' });
    }

    const store = storeRows[0];
    if (store.isOpen === 0 || store.isOpen === false) {
      return res.status(400).json({ status: 0, message: 'المتجر مغلق حالياً ولا يستقبل طلبات جديدة' });
    }

    const [userRows] = await pool.query(
      'SELECT email, firstName, lastName, phone FROM users WHERE id = ?',
      [userId]
    );
    const user = userRows[0] || {};

    let orderPrice = 0;
    for (const item of items) {
      const q = parseInt(item.quantity || 1, 10);
      const unitP = parseFloat(item.unitPrice || item.price || 0);
      const totalP = parseFloat(item.totalPrice || (unitP * q));
      orderPrice += totalP;
    }

    const toZone = (deliveryLocation || '').toString().trim();
    const fromZone = (store.city || store.storeAddress || 'الهانوفيل').toString().trim();
    let deliveryFee = 35.00;
    if (rawDeliveryFee !== undefined && !isNaN(parseFloat(rawDeliveryFee))) {
      deliveryFee = parseFloat(rawDeliveryFee);
    } else {
      deliveryFee = calculateZoneDeliveryFee(fromZone, toZone);
    }

    let serviceFee = 5.00;
    try {
      const [feeRows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'store_service_fee' LIMIT 1");
      if (feeRows.length > 0 && feeRows[0].value !== null && feeRows[0].value !== '') {
        const parsedFee = parseFloat(feeRows[0].value);
        if (!isNaN(parsedFee)) serviceFee = parsedFee;
      }
    } catch (_) {}
    const totalAmount = orderPrice + deliveryFee + serviceFee;
    const amountStr = totalAmount.toFixed(2);
    const orderRef = `store_${storeId}_${userId}_${Date.now()}`;
    const storeDisplayName = store.storeName || `${store.firstName} ${store.lastName}`.trim() || 'متجر';

    const serverBaseUrl = process.env.SERVER_URL || `http://localhost:${process.env.PORT || 5000}`;
    const webhookUrl = `${serverBaseUrl}/api/wallet/kashier-webhook`;

    let redirectUrl = 'https://we-deliver-payment.com/callback';
    try {
      const urlObj = new URL(serverBaseUrl);
      const isLocal = urlObj.hostname === 'localhost' || urlObj.hostname === '127.0.0.1' || /^[0-9.]+$/.test(urlObj.hostname);
      if (!isLocal) {
        redirectUrl = `${serverBaseUrl}/api/wallet/payment-callback`;
      }
    } catch (_) {}

    const sessionPayload = {
      merchantId: KASHIER_MERCHANT_ID,
      amount: amountStr,
      currency: 'EGP',
      order: orderRef,
      paymentType: 'credit',
      type: 'one-time',
      allowedMethods: 'card,wallet',
      display: 'ar',
      description: `طلب طعام من ${storeDisplayName}`,
      customer: {
        email: user.email || `user${userId}@bnwasal.com`,
        reference: userId.toString(),
      },
      serverWebhook: webhookUrl,
      merchantRedirect: redirectUrl,
      failureRedirect: false,
      enable3DS: true,
      metaData: {
        type: 'store_order',
        storeId: storeId.toString(),
        clientId: userId.toString(),
        totalAmount: amountStr,
      },
    };

    const response = await kashierRequest('POST', '/v3/payment/sessions', sessionPayload);

    if (response.status !== 200 && response.status !== 201) {
      console.error('❌ Kashier session creation failed:', response.body);
      return res.status(502).json({
        status: 0,
        message: 'فشل في إنشاء جلسة الدفع عبر كاشير. حاول مرة أخرى.',
        detail: response.body,
      });
    }

    const sessionData = response.body;
    return res.status(200).json({
      status: 1,
      message: 'تم إنشاء جلسة الدفع بنجاح',
      data: {
        sessionUrl: sessionData.sessionUrl,
        sessionId: sessionData._id,
        amount: totalAmount,
        orderReference: orderRef,
      }
    });
  } catch (error) {
    console.error('createStorePaymentSession Error:', error);
    next(error);
  }
};

// 12. VERIFY STORE PAYMENT & FINALIZE ORDER
const verifyStorePayment = async (req, res, next) => {
  const pool = getPool();
  const conn = await pool.getConnection();
  try {
    const sessionId = req.params.sessionId;
    const clientId = req.user.id;

    if (!sessionId) {
      conn.release();
      return res.status(400).json({ status: 0, message: 'معرف جلسة الدفع مطلوب' });
    }

    // Check with Kashier
    const kashierRes = await kashierRequest('GET', `/v3/payment/sessions/${sessionId}/payment`);
    const kashierStatus = (kashierRes.body?.data?.status || kashierRes.body?.status || '').toUpperCase();
    const isSuccess = kashierRes.status === 200 && (kashierStatus === 'SUCCESS' || kashierStatus === 'PAID' || kashierStatus === 'CAPTURED');

    if (!isSuccess) {
      conn.release();
      return res.status(400).json({
        status: 0,
        message: 'لم يتم تأكيد عملية الدفع بنجاح من كاشير',
        kashierStatus,
      });
    }

    // Check if order already created with this sessionId
    const [existing] = await conn.query(
      'SELECT id, orderNumber FROM orders WHERE paymentSessionId = ?',
      [sessionId]
    );
    if (existing.length > 0) {
      conn.release();
      return res.status(200).json({
        status: 1,
        message: 'تم تأكيد الطلب مسبقاً بنجاح',
        data: { orderId: existing[0].id, orderNumber: existing[0].orderNumber, isPaid: true }
      });
    }

    const {
      storeId,
      items,
      deliveryAddress,
      phone: rawPhone,
      customerPhone,
      clientName: rawClientName,
      customerName,
      deliveryLocation,
      deliveryFee: rawDeliveryFee,
      notes,
      latitude,
      longitude,
    } = req.body;

    const phone = (rawPhone || customerPhone || (req.user && req.user.phone) || '').toString().trim();

    const [storeRows] = await conn.query(
      `SELECT id, storeName, firstName, lastName, phone as storePhone, city, storeAddress 
       FROM users WHERE id = ? AND role = 'merchant'`,
      [storeId]
    );

    const store = storeRows[0] || {};
    let orderPrice = 0;
    const itemSummaries = [];

    if (items && Array.isArray(items)) {
      for (const item of items) {
        const q = parseInt(item.quantity || 1, 10);
        const unitP = parseFloat(item.unitPrice || item.price || 0);
        const totalP = parseFloat(item.totalPrice || (unitP * q));
        orderPrice += totalP;
        const sizeStr = item.size ? ` (${item.size})` : '';
        itemSummaries.push(`${q}x ${item.productName || 'منتج'}${sizeStr}`);
      }
    }

    const toZone = (deliveryLocation || '').toString().trim();
    const fromZone = (store.city || store.storeAddress || 'الهانوفيل').toString().trim();
    let deliveryFee = 35.00;
    if (rawDeliveryFee !== undefined && !isNaN(parseFloat(rawDeliveryFee))) {
      deliveryFee = parseFloat(rawDeliveryFee);
    } else {
      deliveryFee = calculateZoneDeliveryFee(fromZone, toZone);
    }

    const orderNumber = 'ORD' + Date.now().toString().substring(4) + Math.floor(100 + Math.random() * 900);
    const detailsText = itemSummaries.join(', ');
    const storeDisplayName = store.storeName || `${store.firstName} ${store.lastName}`.trim() || 'متجر';

    const nameCandidate = (rawClientName || customerName || '').toString().trim();
    let clientName = nameCandidate.length > 0 ? nameCandidate : null;
    if (!clientName && req.user) {
      clientName = `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || 'عميل';
    }

    await conn.beginTransaction();

    const { findActiveShiftForOrder } = require('../utils/shiftMatcher');
    const shiftId = await findActiveShiftForOrder({
      merchantId: storeId,
      conn,
    });

    const [realStoreRows] = await conn.query(
      'SELECT id, merchantId, commissionRate, commissionType FROM stores WHERE (id = ? OR merchantId = ?) AND deletedAt IS NULL LIMIT 1',
      [storeId, storeId]
    );
    const resolvedStoreId = realStoreRows.length > 0 ? realStoreRows[0].id : null;
    const resolvedMerchantId = realStoreRows.length > 0 ? realStoreRows[0].merchantId : storeId;
    const commRate = realStoreRows.length > 0 ? realStoreRows[0].commissionRate : 5.0;
    const commType = realStoreRows.length > 0 ? realStoreRows[0].commissionType : 'percentage';

    const { calculateOrderCommission } = require('../utils/commissionCalculator');
    const commResult = calculateOrderCommission({
      orderPrice,
      commissionRate: commRate,
      commissionType: commType,
    });

    const platformShare = parseFloat((deliveryFee * 0.20).toFixed(2));
    const captainShare = parseFloat((deliveryFee * 0.80).toFixed(2));

    let serviceFee = 5.00;
    try {
      const [feeRows] = await conn.query("SELECT `value` FROM app_settings WHERE `key` = 'store_service_fee' LIMIT 1");
      if (feeRows.length > 0 && feeRows[0].value !== null && feeRows[0].value !== '') {
        const parsedFee = parseFloat(feeRows[0].value);
        if (!isNaN(parsedFee)) serviceFee = parsedFee;
      }
    } catch (_) {}
    // Insert Order with isPaid = 1 and paymentMethod = 'kashier' and shift_id, and store order statuses
    const [orderResult] = await conn.query(
      `INSERT INTO orders (
        orderNumber, merchantId, storeId, clientId, details, storeDescription, notes,
        deliveryAddress, clientName, phone, orderPrice, deliveryFee, serviceFee,
        latitude, longitude, status, platformShare, captainShare,
        isPaid, paymentMethod, paymentSessionId, paymentStatus, shift_id,
        platformCommission, merchantNet, commissionRateSnapshot, commissionTypeSnapshot,
        orderType, storeOrderStatus, captainTripStatus
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'kashier', ?, 'paid', ?, ?, ?, ?, ?, 'store', ?, 'PENDING_ASSIGNMENT')`,
      [
        orderNumber,
        resolvedMerchantId,
        resolvedStoreId,
        clientId,
        detailsText,
        storeDisplayName,
        notes || null,
        (deliveryAddress || '').trim(),
        clientName,
        phone.trim(),
        orderPrice,
        deliveryFee,
        serviceFee,
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null,
        getArabicStoreStatus(STORE_ORDER_STATUS.UNDER_REVIEW),
        platformShare,
        captainShare,
        sessionId,
        shiftId || null,
        commResult.platformCommission,
        commResult.merchantNet,
        commResult.rateSnapshot,
        commResult.typeSnapshot,
        STORE_ORDER_STATUS.UNDER_REVIEW,
      ]
    );

    const orderId = orderResult.insertId;

    if (items && Array.isArray(items)) {
      for (const item of items) {
        const q = parseInt(item.quantity || 1, 10);
        const unitP = parseFloat(item.unitPrice || item.price || 0);
        const totalP = parseFloat(item.totalPrice || (unitP * q));
        let addonsJson = null;
        if (item.addons) {
          addonsJson = typeof item.addons === 'string' ? item.addons : JSON.stringify(item.addons);
        }

        await conn.query(
          `INSERT INTO order_items (
            orderId, productId, productName, productImage, size, addons, quantity, unitPrice, totalPrice, notes
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            orderId,
            item.productId ? parseInt(item.productId, 10) : null,
            item.productName || 'منتج',
            item.productImage || null,
            item.size || null,
            addonsJson,
            q,
            unitP,
            totalP,
            item.notes || null,
          ]
        );
      }
    }

    // Record wallet transaction for store payout accounting
    try {
      await conn.query(
        `INSERT INTO wallet_transactions (userId, amount, type, description, status, reference)
         VALUES (?, ?, 'store_payout', ?, 'success', ?)`,
        [storeId, orderPrice, `مستحقات طلب مدفوع أونلاين عبر كاشير #${orderNumber}`, sessionId]
      );
    } catch (_) {}

    await conn.commit();
    conn.release();

    // Order created under review for Admin Panel.
    // It must NOT reach the merchant until Admin reviews and forwards it!
    try {
      const io = req.app.get('io');
      if (io) {
        const orderEventPayload = {
          orderId: orderId.toString(),
          id: orderId.toString(),
          orderNumber,
          shipmentId: null,
          shiftId: shiftId ? shiftId.toString() : null,
          captainId: null,
          orderType: 'store',
          status: getArabicStoreStatus(STORE_ORDER_STATUS.UNDER_REVIEW),
          storeOrderStatus: STORE_ORDER_STATUS.UNDER_REVIEW,
          merchantId: storeId.toString(),
          storeName: storeDisplayName,
          clientName,
          phone,
          deliveryAddress: (deliveryAddress || '').trim(),
          orderPrice,
          deliveryFee,
          totalAmount: orderPrice + deliveryFee,
          createdAt: new Date().toISOString()
        };

        io.to('admins').emit('ORDER_CREATED', orderEventPayload);
        io.to('admins').emit('order_created', orderEventPayload);
        io.to('admins').emit('new_store_order', orderEventPayload);
        io.to('admins').emit('store_order_created', orderEventPayload);
        io.to('admins').emit('dashboard_update');

        if (shiftId) {
          io.to(`shift_${shiftId}`).emit('ORDER_CREATED', orderEventPayload);
          io.to(`shift:${shiftId}`).emit('ORDER_CREATED', orderEventPayload);
        }

        // Notify Admins
        try {
          await notifyAdmins(
            io,
            'طلب متجر جديد مدفوع أونلاين (قيد المراجعة) 🔔',
            `طلب متجر جديد مدفوع كاشير #${orderNumber} من ${storeDisplayName} قيد المراجعة - يرجى تأكيد توافر الطلب مع المتجر وإرساله`,
            'order',
            { 
              type: 'new_store_order', 
              orderId: orderId.toString(), 
              orderNumber, 
              storeOrderStatus: STORE_ORDER_STATUS.UNDER_REVIEW,
              needsReview: true
            }
          );
        } catch (adminErr) {
          console.error('Failed to notify admins of new kashier store order:', adminErr);
        }
      }
    } catch (_) {}

    try {
      const io = req.app.get('io');
      // Notify customer that order is paid and under review
      await sendNotification(
        io,
        clientId,
        'تم استلام طلبك بنجاح 💳',
        `تم استلام دفعتك للطلب #${orderNumber} بنجاح، وهو قيد المراجعة حالياً من قبل الإدارة لتأكيده مع المتجر.`,
        'order',
        { orderId: orderId.toString(), orderNumber, type: 'order_created', storeOrderStatus: STORE_ORDER_STATUS.UNDER_REVIEW }
      );
    } catch (_) {}

    return res.status(200).json({
      status: 1,
      message: 'تم الدفع وتأكيد الطلب بنجاح',
      data: { orderId, orderNumber, isPaid: true }
    });
  } catch (error) {
    await conn.rollback();
    conn.release();
    console.error('verifyStorePayment Error:', error);
    next(error);
  }
};

// 11. GET CLIENT STORE ORDERS (سجل طلبات المتجر الخاصة بالعميل)
const getClientStoreOrders = async (req, res, next) => {
  try {
    const pool = getPool();
    const clientId = req.user.id;

    const [orderRows] = await pool.query(
      `SELECT 
        o.id,
        o.orderNumber,
        o.merchantId,
        o.storeId,
        o.clientId,
        o.captainId,
        o.details,
        o.notes,
        o.deliveryAddress,
        o.clientName,
        CAST(o.orderPrice AS DECIMAL(10,2)) as orderPrice,
        CAST(o.deliveryFee AS DECIMAL(10,2)) as deliveryFee,
        CAST(COALESCE(o.serviceFee, 0.00) AS DECIMAL(10,2)) as serviceFee,
        CAST(COALESCE(o.tip, 0.00) AS DECIMAL(10,2)) as tip,
        CAST(COALESCE(o.discountApplied, 0.00) AS DECIMAL(10,2)) as discountApplied,
        o.couponCode,
        ((CAST(o.orderPrice AS DECIMAL(10,2)) + CAST(o.deliveryFee AS DECIMAL(10,2)) + CAST(COALESCE(o.serviceFee, 0.00) AS DECIMAL(10,2)) + CAST(COALESCE(o.tip, 0.00) AS DECIMAL(10,2))) - CAST(COALESCE(o.discountApplied, 0.00) AS DECIMAL(10,2))) as totalAmount,
        COALESCE(o.scheduleType, 'now') as scheduleType,
        o.scheduledAt,
        o.status,
        COALESCE(o.storeOrderStatus, 'pending') as storeOrderStatus,
        COALESCE(o.captainTripStatus, 'PENDING_ASSIGNMENT') as captainTripStatus,
        o.paymentMethod,
        o.isPaid,
        o.createdAt,
        o.acceptedAt,
        o.readyAt,
        o.captainAssignedAt,
        o.pickedUpAt,
        o.deliveredAt,
        o.completedAt,
        COALESCE(NULLIF(s.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(s.logo, u.profileImage) as storeLogo,
        COALESCE(s.coverImage, u.profileImage) as storeCover,
        COALESCE(s.phone, u.phone) as storePhone,
        COALESCE(s.address, u.storeAddress) as storeAddress,
        c.firstName as captainFirstName,
        c.lastName as captainLastName,
        c.phone as captainPhone,
        c.profileImage as captainProfileImage
       FROM orders o
       LEFT JOIN stores s ON o.storeId = s.id
       LEFT JOIN users u ON o.merchantId = u.id
       LEFT JOIN users c ON o.captainId = c.id
       WHERE o.clientId = ? AND (o.orderType = 'store' OR o.storeId IS NOT NULL OR o.details LIKE '%[%')
       ORDER BY o.createdAt DESC`,
      [clientId]
    );

    if (orderRows.length === 0) {
      return res.status(200).json({
        status: 1,
        message: 'لا توجد طلبات متجر سابقة',
        data: []
      });
    }

    const orderIds = orderRows.map(o => o.id);
    const [itemRows] = await pool.query(
      `SELECT id, orderId, productId, productName, productImage, size, addons, quantity, unitPrice, totalPrice, notes
       FROM order_items
       WHERE orderId IN (?)
       ORDER BY id ASC`,
      [orderIds]
    );

    // Group items by orderId
    const itemsByOrder = {};
    for (const item of itemRows) {
      if (!itemsByOrder[item.orderId]) {
        itemsByOrder[item.orderId] = [];
      }
      let parsedAddons = [];
      if (item.addons) {
        try {
          parsedAddons = typeof item.addons === 'string' ? JSON.parse(item.addons) : item.addons;
        } catch (_) {}
      }
      itemsByOrder[item.orderId].push({
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        productImage: item.productImage,
        size: item.size,
        addons: parsedAddons,
        quantity: item.quantity,
        unitPrice: parseFloat(item.unitPrice || 0),
        totalPrice: parseFloat(item.totalPrice || 0),
        notes: item.notes,
      });
    }

    const formattedOrders = orderRows.map(o => {
      const canonicalStatus = normalizeStoreOrderStatus(o.storeOrderStatus || o.status);
      const arabicStatus = getArabicStoreStatus(canonicalStatus);
      return {
        id: o.id,
        orderNumber: o.orderNumber,
        merchantId: o.merchantId,
        storeId: o.storeId,
        details: o.details,
        notes: o.notes,
        deliveryAddress: o.deliveryAddress,
        clientName: o.clientName,
        phone: o.phone,
        orderPrice: parseFloat(o.orderPrice || 0),
        deliveryFee: parseFloat(o.deliveryFee || 0),
        serviceFee: parseFloat(o.serviceFee || 0),
        totalAmount: parseFloat(o.totalAmount || 0),
        status: arabicStatus,
        statusArabic: arabicStatus,
        storeOrderStatus: canonicalStatus,
        captainTripStatus: o.captainTripStatus,
        paymentMethod: o.paymentMethod || 'cash',
        isPaid: o.isPaid === 1 || o.isPaid === true,
        createdAt: o.createdAt,
        acceptedAt: o.acceptedAt,
        readyAt: o.readyAt,
        captainAssignedAt: o.captainAssignedAt,
        pickedUpAt: o.pickedUpAt,
        deliveredAt: o.deliveredAt,
        completedAt: o.completedAt,
      storeName: o.storeName,
      storeLogo: o.storeLogo,
      storeCover: o.storeCover,
      storePhone: o.storePhone,
      storeAddress: o.storeAddress,
      captain: o.captainId ? {
        id: o.captainId,
        name: `${o.captainFirstName || ''} ${o.captainLastName || ''}`.trim(),
        phone: o.captainPhone || '',
        profileImage: o.captainProfileImage,
      } : null,
      items: itemsByOrder[o.id] || [],
    };
  });

    return res.status(200).json({
      status: 1,
      message: 'تم جلب طلبات المتجر بنجاح',
      data: formattedOrders
    });
  } catch (error) {
    console.error('getClientStoreOrders Error:', error);
    next(error);
  }
};

// 12. GET SINGLE STORE ORDER DETAILS FOR CLIENT
const getClientStoreOrderDetails = async (req, res, next) => {
  try {
    const pool = getPool();
    const clientId = req.user.id;
    const orderId = parseInt(req.params.orderId, 10);

    const [orderRows] = await pool.query(
      `SELECT 
        o.id,
        o.orderNumber,
        o.merchantId,
        o.storeId,
        o.clientId,
        o.captainId,
        o.details,
        o.notes,
        o.deliveryAddress,
        o.clientName,
        o.phone,
        CAST(o.orderPrice AS DECIMAL(10,2)) as orderPrice,
        CAST(o.deliveryFee AS DECIMAL(10,2)) as deliveryFee,
        CAST(COALESCE(o.serviceFee, 0.00) AS DECIMAL(10,2)) as serviceFee,
        CAST(COALESCE(o.tip, 0.00) AS DECIMAL(10,2)) as tip,
        CAST(COALESCE(o.discountApplied, 0.00) AS DECIMAL(10,2)) as discountApplied,
        o.couponCode,
        ((CAST(o.orderPrice AS DECIMAL(10,2)) + CAST(o.deliveryFee AS DECIMAL(10,2)) + CAST(COALESCE(o.serviceFee, 0.00) AS DECIMAL(10,2)) + CAST(COALESCE(o.tip, 0.00) AS DECIMAL(10,2))) - CAST(COALESCE(o.discountApplied, 0.00) AS DECIMAL(10,2))) as totalAmount,
        COALESCE(o.scheduleType, 'now') as scheduleType,
        o.scheduledAt,
        o.status,
        COALESCE(o.storeOrderStatus, 'pending') as storeOrderStatus,
        COALESCE(o.captainTripStatus, 'PENDING_ASSIGNMENT') as captainTripStatus,
        o.paymentMethod,
        o.isPaid,
        o.createdAt,
        o.acceptedAt,
        o.readyAt,
        o.captainAssignedAt,
        o.pickedUpAt,
        o.deliveredAt,
        o.completedAt,
        COALESCE(NULLIF(s.name, ''), NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        COALESCE(s.logo, u.profileImage) as storeLogo,
        COALESCE(s.coverImage, u.profileImage) as storeCover,
        COALESCE(s.phone, u.phone) as storePhone,
        COALESCE(s.address, u.storeAddress) as storeAddress,
        c.firstName as captainFirstName,
        c.lastName as captainLastName,
        c.phone as captainPhone,
        c.profileImage as captainProfileImage
       FROM orders o
       LEFT JOIN stores s ON o.storeId = s.id
       LEFT JOIN users u ON o.merchantId = u.id
       LEFT JOIN users c ON o.captainId = c.id
       WHERE o.id = ? AND o.clientId = ?`,
      [orderId, clientId]
    );

    if (orderRows.length === 0) {
      return res.status(404).json({ status: 0, message: 'الطلب غير موجود أو لا تملك صلاحية الوصول إليه' });
    }

    const o = orderRows[0];
    const [itemRows] = await pool.query(
      `SELECT id, orderId, productId, productName, productImage, size, addons, quantity, unitPrice, totalPrice, notes
       FROM order_items
       WHERE orderId = ?
       ORDER BY id ASC`,
      [orderId]
    );

    const items = itemRows.map(item => {
      let parsedAddons = [];
      if (item.addons) {
        try {
          parsedAddons = typeof item.addons === 'string' ? JSON.parse(item.addons) : item.addons;
        } catch (_) {}
      }
      return {
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        productImage: item.productImage,
        size: item.size,
        addons: parsedAddons,
        quantity: item.quantity,
        unitPrice: parseFloat(item.unitPrice || 0),
        totalPrice: parseFloat(item.totalPrice || 0),
        notes: item.notes,
      };
    });

    const canonicalStatus = normalizeStoreOrderStatus(o.storeOrderStatus || o.status);
    const arabicStatus = getArabicStoreStatus(canonicalStatus);

    return res.status(200).json({
      status: 1,
      message: 'تم جلب تفاصيل الطلب بنجاح',
      data: {
        id: o.id,
        orderNumber: o.orderNumber,
        merchantId: o.merchantId,
        storeId: o.storeId,
        details: o.details,
        notes: o.notes,
        deliveryAddress: o.deliveryAddress,
        clientName: o.clientName,
        phone: o.phone,
        orderPrice: parseFloat(o.orderPrice || 0),
        deliveryFee: parseFloat(o.deliveryFee || 0),
        serviceFee: parseFloat(o.serviceFee || 0),
        totalAmount: parseFloat(o.totalAmount || 0),
        status: arabicStatus,
        statusArabic: arabicStatus,
        storeOrderStatus: canonicalStatus,
        captainTripStatus: o.captainTripStatus,
        paymentMethod: o.paymentMethod || 'cash',
        isPaid: o.isPaid === 1 || o.isPaid === true,
        createdAt: o.createdAt,
        acceptedAt: o.acceptedAt,
        readyAt: o.readyAt,
        captainAssignedAt: o.captainAssignedAt,
        pickedUpAt: o.pickedUpAt,
        deliveredAt: o.deliveredAt,
        completedAt: o.completedAt,
        storeName: o.storeName,
        storeLogo: o.storeLogo,
        storeCover: o.storeCover,
        storePhone: o.storePhone,
        storeAddress: o.storeAddress,
        captain: o.captainId ? {
          id: o.captainId,
          name: `${o.captainFirstName || ''} ${o.captainLastName || ''}`.trim(),
          phone: o.captainPhone || '',
          profileImage: o.captainProfileImage,
        } : null,
        items
      }
    });
  } catch (error) {
    console.error('getClientStoreOrderDetails Error:', error);
    next(error);
  }
};

// 13. RATE PRODUCT (تقييم منتج المتجر وحساب التقييم الفعلي)
const rateProduct = async (req, res, next) => {
  try {
    const pool = getPool();
    const reviewerId = req.user.id;
    const productId = parseInt(req.params.productId, 10);
    const { rating, comment, orderId } = req.body;

    if (isNaN(productId)) {
      return res.status(400).json({ status: 0, message: 'معرف المنتج غير صالح' });
    }

    const numRating = parseFloat(rating);
    if (isNaN(numRating) || numRating < 1 || numRating > 5) {
      return res.status(400).json({ status: 0, message: 'التقييم يجب أن يكون بين 1 و 5 نجوم' });
    }

    // 1. Verify product exists
    const [products] = await pool.query(
      'SELECT id, merchantId, name FROM merchant_products WHERE id = ?',
      [productId]
    );
    if (products.length === 0) {
      return res.status(404).json({ status: 0, message: 'المنتج غير موجود' });
    }
    const product = products[0];

    // 2. Check if user already reviewed this product
    const [existing] = await pool.query(
      'SELECT id FROM reviews WHERE productId = ? AND reviewerId = ?',
      [productId, reviewerId]
    );

    if (existing.length > 0) {
      // Update existing review
      await pool.query(
        `UPDATE reviews 
         SET rating = ?, comment = COALESCE(?, comment), orderId = COALESCE(?, orderId), createdAt = NOW()
         WHERE id = ?`,
        [numRating, comment ? comment.trim() : null, orderId || null, existing[0].id]
      );
    } else {
      // Insert new review
      await pool.query(
        `INSERT INTO reviews (productId, reviewerId, revieweeId, rating, comment, orderId, createdAt)
         VALUES (?, ?, ?, ?, ?, ?, NOW())`,
        [productId, reviewerId, product.merchantId, numRating, comment ? comment.trim() : null, orderId || null]
      );
    }

    // 3. Calculate actual average rating and rating count
    const [stats] = await pool.query(
      `SELECT ROUND(AVG(rating), 1) as avgRating, COUNT(*) as countReviews
       FROM reviews
       WHERE productId = ?`,
      [productId]
    );

    const actualRating = stats[0] && stats[0].avgRating ? parseFloat(stats[0].avgRating) : numRating;
    const actualCount = stats[0] && stats[0].countReviews ? parseInt(stats[0].countReviews, 10) : 1;

    // 4. Update product in DB
    await pool.query(
      'UPDATE merchant_products SET rating = ?, ratingCount = ? WHERE id = ?',
      [actualRating, actualCount, productId]
    );

    return res.status(200).json({
      status: 1,
      message: 'تم حفظ تقييمك للمنتج بنجاح',
      data: {
        productId,
        rating: actualRating,
        ratingCount: actualCount,
        myRating: numRating,
        comment: comment || ''
      }
    });
  } catch (error) {
    console.error('rateProduct Error:', error);
    next(error);
  }
};

// 14. GET PRODUCT REVIEWS
const getProductReviews = async (req, res, next) => {
  try {
    const pool = getPool();
    const productId = parseInt(req.params.productId, 10);

    if (isNaN(productId)) {
      return res.status(400).json({ status: 0, message: 'معرف المنتج غير صالح' });
    }

    const [reviews] = await pool.query(
      `SELECT 
        r.id,
        r.rating,
        r.comment,
        r.createdAt,
        u.firstName,
        u.lastName,
        u.profileImage
       FROM reviews r
       JOIN users u ON r.reviewerId = u.id
       WHERE r.productId = ?
       ORDER BY r.createdAt DESC
       LIMIT 50`,
      [productId]
    );

    const formattedReviews = reviews.map(r => ({
      id: r.id,
      rating: parseFloat(r.rating || 5),
      comment: r.comment || '',
      createdAt: r.createdAt,
      userName: `${r.firstName || ''} ${r.lastName || ''}`.trim() || 'عميل',
      userImage: r.profileImage
    }));

    return res.status(200).json({
      status: 1,
      message: 'تم جلب تقييمات المنتج بنجاح',
      data: formattedReviews
    });
  } catch (error) {
    console.error('getProductReviews Error:', error);
    next(error);
  }
};

module.exports = {
  getStores,
  getStoreDetails,
  getAllProducts,
  getBanners,
  getOffers,
  getMostPopularProducts,
  toggleFavoriteProduct,
  getFavoriteProducts,
  getMainCategories,
  placeStoreOrder,
  getDeliveryZones,
  createStorePaymentSession,
  verifyStorePayment,
  getClientStoreOrders,
  getClientStoreOrderDetails,
  rateProduct,
  getProductReviews,
};
