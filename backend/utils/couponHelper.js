const findCouponByCode = async (conn, rawCode) => {
  if (!rawCode || typeof rawCode !== 'string') return null;
  const cleanCode = rawCode.trim();
  if (!cleanCode) return null;

  // 1. Try exact match
  let [rows] = await conn.query(
    "SELECT * FROM coupons WHERE LOWER(TRIM(code)) = LOWER(TRIM(?)) FOR UPDATE",
    [cleanCode]
  );
  if (rows.length > 0) return rows[0];

  // 2. Normalized prefix match (بتوصل <-> بنوصل)
  const altCode = cleanCode.startsWith('بتوصل')
      ? cleanCode.replace(/^بتوصل/i, 'بنوصل')
      : (cleanCode.startsWith('بنوصل') ? cleanCode.replace(/^بنوصل/i, 'بتوصل') : cleanCode);

  [rows] = await conn.query(
    "SELECT * FROM coupons WHERE LOWER(TRIM(code)) = LOWER(TRIM(?)) FOR UPDATE",
    [altCode]
  );
  if (rows.length > 0) return rows[0];

  // 3. Suffix match (e.g. NV3BJR)
  const suffixMatch = cleanCode.match(/[A-Z0-9]{4,12}$/i);
  if (suffixMatch) {
    const codeSuffix = suffixMatch[0];
    [rows] = await conn.query(
      "SELECT * FROM coupons WHERE LOWER(TRIM(code)) LIKE CONCAT('%', LOWER(?)) FOR UPDATE",
      [codeSuffix]
    );
    if (rows.length > 0) return rows[0];
  }

  return null;
};

const processCoupon = async (conn, { code, price, userId, isShipment, entityId }) => {
  if (!code || code.trim().length === 0) return { discountApplied: 0.00, couponCode: null };

  const coupon = await findCouponByCode(conn, code);

  if (!coupon) {
    throw new Error('الكوبون غير موجود');
  }

  if (coupon.status === 0) {
    throw new Error('هذا الكوبون غير فعال حالياً');
  }

  if (coupon.usedCount >= coupon.maxUsages) {
    throw new Error('لقد انتهت مرات استخدام هذا الكوبون بالكامل');
  }

  // Check user restriction
  if (coupon.targetUserRole === 'specific') {
    const [users] = await conn.query(
      "SELECT 1 FROM coupon_users WHERE couponId = ? AND userId = ?",
      [coupon.id, userId]
    );
    if (users.length === 0) {
      throw new Error('هذا الكوبون غير مخصص لحسابك');
    }
  }

  // Check if this user has already used this coupon
  const [usages] = await conn.query(
    "SELECT 1 FROM coupon_usages WHERE couponId = ? AND userId = ?",
    [coupon.id, userId]
  );
  if (usages.length > 0) {
    throw new Error('لقد قمت باستخدام هذا الكوبون مسبقاً');
  }

  // Check Expiration
  if (coupon.expirationType === 'date') {
    const now = new Date();
    const expiry = new Date(coupon.expiryDate);
    if (expiry < now) {
      throw new Error('عذراً، هذا الكوبون قد انتهت صلاحيته');
    }
  } else if (coupon.expirationType === 'day_of_week') {
    const currentDayOfWeek = new Date().getDay() + 1; // JS 0-6 -> 1-7
    if (currentDayOfWeek !== coupon.expiryDayOfWeek) {
      throw new Error('هذا الكوبون غير صالح للاستخدام اليوم');
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

  // Update used count
  await conn.query(
    "UPDATE coupons SET usedCount = usedCount + 1 WHERE id = ?",
    [coupon.id]
  );

  // Insert usage record
  await conn.query(
    `INSERT INTO coupon_usages (couponId, userId, shipmentId, orderId, discountApplied)
     VALUES (?, ?, ?, ?, ?)`,
    [
      coupon.id,
      userId,
      isShipment ? entityId : null,
      !isShipment ? entityId : null,
      discountApplied
    ]
  );

  return {
    discountApplied,
    couponCode: coupon.code
  };
};

module.exports = {
  processCoupon
};
