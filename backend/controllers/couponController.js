const { getPool } = require('../config/db');

const findCouponByCode = async (dbOrConn, rawCode) => {
  if (!rawCode || typeof rawCode !== 'string') return null;
  const cleanCode = rawCode.trim();
  if (!cleanCode) return null;

  // 1. Try exact match (case insensitive)
  let [rows] = await dbOrConn.query(
    "SELECT * FROM coupons WHERE LOWER(TRIM(code)) = LOWER(TRIM(?)) LIMIT 1",
    [cleanCode]
  );
  if (rows.length > 0) return rows[0];

  // 2. Normalized prefix match (بتوصل <-> بنوصل)
  const altCode = cleanCode.startsWith('بتوصل')
      ? cleanCode.replace(/^بتوصل/i, 'بنوصل')
      : (cleanCode.startsWith('بنوصل') ? cleanCode.replace(/^بنوصل/i, 'بتوصل') : cleanCode);

  [rows] = await dbOrConn.query(
    "SELECT * FROM coupons WHERE LOWER(TRIM(code)) = LOWER(TRIM(?)) LIMIT 1",
    [altCode]
  );
  if (rows.length > 0) return rows[0];

  // 3. Match by suffix code (e.g. NV3BJR)
  const suffixMatch = cleanCode.match(/[A-Z0-9]{4,12}$/i);
  if (suffixMatch) {
    const codeSuffix = suffixMatch[0];
    [rows] = await dbOrConn.query(
      "SELECT * FROM coupons WHERE LOWER(TRIM(code)) LIKE CONCAT('%', LOWER(?)) LIMIT 1",
      [codeSuffix]
    );
    if (rows.length > 0) return rows[0];
  }

  return null;
};

// 1. VALIDATE COUPON (For merchants creating shipments/orders)
const validateCoupon = async (req, res, next) => {
  try {
    const pool = getPool();
    const { code, price } = req.query;
    const userId = req.user.id;

    if (!code || !price) {
      return res.status(400).json({ status: 0, message: 'الكود والسعر مطلوبان' });
    }

    const coupon = await findCouponByCode(pool, code);

    if (!coupon) {
      return res.status(404).json({ status: 0, message: 'الكوبون غير موجود' });
    }

    if (coupon.status === 0) {
      return res.status(400).json({ status: 0, message: 'هذا الكوبون غير فعال حالياً' });
    }

    if (coupon.usedCount >= coupon.maxUsages) {
      return res.status(400).json({ status: 0, message: 'لقد انتهت مرات استخدام هذا الكوبون بالكامل' });
    }

    // Check user restriction
    if (coupon.targetUserRole === 'specific') {
      const [users] = await pool.query(
        "SELECT 1 FROM coupon_users WHERE couponId = ? AND userId = ?",
        [coupon.id, userId]
      );
      if (users.length === 0) {
        return res.status(400).json({ status: 0, message: 'هذا الكوبون غير مخصص لحسابك' });
      }
    }

    // Check if this user has already used this coupon
    const [usages] = await pool.query(
      "SELECT 1 FROM coupon_usages WHERE couponId = ? AND userId = ?",
      [coupon.id, userId]
    );
    if (usages.length > 0) {
      return res.status(400).json({ status: 0, message: 'لقد قمت باستخدام هذا الكوبون مسبقاً' });
    }

    // Check Expiration
    if (coupon.expirationType === 'date') {
      const now = new Date();
      const expiry = new Date(coupon.expiryDate);
      if (expiry < now) {
        return res.status(400).json({ status: 0, message: 'عذراً، هذا الكوبون قد انتهت صلاحيته' });
      }
    } else if (coupon.expirationType === 'day_of_week') {
      const currentDayOfWeek = new Date().getDay() + 1; // JS 0-6 (Sunday-Saturday) -> 1-7
      if (currentDayOfWeek !== coupon.expiryDayOfWeek) {
        return res.status(400).json({ status: 0, message: 'هذا الكوبون غير صالح للاستخدام اليوم' });
      }
    }

    // Calculate discount
    let discountApplied = 0.00;
    const initialPrice = parseFloat(price);
    if (coupon.discountType === 'full') {
      discountApplied = initialPrice;
    } else {
      discountApplied = Math.min(parseFloat(coupon.discountValue), initialPrice);
    }

    const discountedPrice = Math.max(initialPrice - discountApplied, 0.00);

    res.status(200).json({
      status: 1,
      valid: true,
      data: {
        id: coupon.id.toString(),
        code: coupon.code,
        discountType: coupon.discountType,
        discountValue: parseFloat(coupon.discountValue),
        discountApplied,
        discountedPrice
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. CREATE COUPON (Admin/Employee only)
const createCoupon = async (req, res, next) => {
  try {
    const pool = getPool();
    const {
      code,
      discountType,
      discountValue,
      expirationType,
      expiryDate,
      expiryDayOfWeek,
      maxUsages,
      targetUserRole,
      userIds // array of user IDs
    } = req.body;

    if (!code || !discountType) {
      return res.status(400).json({ status: 0, message: 'الكود ونوع الخصم مطلوبان' });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [result] = await conn.query(
        `INSERT INTO coupons (
          code, discountType, discountValue, expirationType,
          expiryDate, expiryDayOfWeek, maxUsages, targetUserRole
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          code.trim().toUpperCase(),
          discountType,
          discountValue ? parseFloat(discountValue) : 0.00,
          expirationType || 'never',
          expiryDate || null,
          expiryDayOfWeek ? parseInt(expiryDayOfWeek) : null,
          maxUsages ? parseInt(maxUsages) : 999999,
          targetUserRole || 'all'
        ]
      );

      const couponId = result.insertId;

      if (targetUserRole === 'specific' && Array.isArray(userIds)) {
        for (const uid of userIds) {
          await conn.query(
            "INSERT INTO coupon_users (couponId, userId) VALUES (?, ?)",
            [couponId, uid]
          );
        }
      }

      await conn.commit();
      res.status(201).json({ status: 1, message: 'تم إنشاء الكوبون بنجاح' });
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

// 3. GET ALL COUPONS (Admin/Employee only)
const getCoupons = async (req, res, next) => {
  try {
    const pool = getPool();
    const [coupons] = await pool.query(
      "SELECT c.*, (SELECT COUNT(*) FROM coupon_usages u WHERE u.couponId = c.id) as realUsedCount FROM coupons c ORDER BY c.createdAt DESC"
    );

    // Fetch user mappings for each coupon
    for (const coupon of coupons) {
      if (coupon.targetUserRole === 'specific') {
        const [users] = await pool.query(
          "SELECT u.id, u.firstName, u.lastName, u.storeName FROM users u JOIN coupon_users cu ON u.id = cu.userId WHERE cu.couponId = ?",
          [coupon.id]
        );
        coupon.users = users;
      } else {
        coupon.users = [];
      }
    }

    res.status(200).json({ status: 1, data: coupons });
  } catch (error) {
    next(error);
  }
};

// 4. DELETE COUPON (Admin/Employee only)
const deleteCoupon = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    await pool.query("DELETE FROM coupons WHERE id = ?", [id]);
    res.status(200).json({ status: 1, message: 'تم حذف الكوبون بنجاح' });
  } catch (error) {
    next(error);
  }
};

// 5. TOGGLE COUPON STATUS (Admin/Employee only)
const toggleCouponStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { status } = req.body; // 0 or 1
    await pool.query("UPDATE coupons SET status = ? WHERE id = ?", [status, id]);
    res.status(200).json({ status: 1, message: 'تم تحديث حالة الكوبون بنجاح' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  validateCoupon,
  createCoupon,
  getCoupons,
  deleteCoupon,
  toggleCouponStatus
};
