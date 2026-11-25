const XLSX = require('xlsx');
const { getPool } = require('../config/db');
const https = require('https');
const { verifyKashierWebhook } = require('../utils/kashierWebhook');
const { creditPendingDeposit } = require('../utils/walletDeposit');


const ARABIC_MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

const getCairoDateStr = (dateVal = new Date()) => {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(new Date(dateVal));
  } catch (_) {
    return new Date(dateVal).toISOString().slice(0, 10);
  }
};

const parsePeriodRange = (period = 'monthly', dateQuery = null) => {
  const cairoToday = getCairoDateStr();
  let dateStr = (dateQuery || cairoToday).toString().trim();
  let [y, m, d] = dateStr.split('-');
  let year = parseInt(y, 10);
  let month = parseInt(m, 10); // 1 - 12
  let day = parseInt(d, 10) || 1;

  if (isNaN(year) || isNaN(month)) {
    const [cy, cm, cd] = cairoToday.split('-');
    year = parseInt(cy, 10);
    month = parseInt(cm, 10);
    day = parseInt(cd, 10);
  }

  const pad = (n) => String(n).padStart(2, '0');

  let startDate, endDate, periodLabel;

  if (period === 'all' || period === 'total') {
    startDate = '2020-01-01 00:00:00';
    endDate = '2099-12-31 23:59:59';
    periodLabel = 'كشف الحساب الكلي (جميع الأوقات)';
  } else if (period === 'daily') {
    const curDateStr = `${year}-${pad(month)}-${pad(day)}`;
    startDate = `${curDateStr} 00:00:00`;
    endDate = `${curDateStr} 23:59:59`;
    periodLabel = `${day} ${ARABIC_MONTHS[month - 1]} ${year}`;
  } else if (period === 'weekly') {
    const targetDt = new Date(year, month - 1, day);
    const startDt = new Date(targetDt.getTime() - 6 * 24 * 60 * 60 * 1000);
    const sYear = startDt.getFullYear();
    const sMonth = startDt.getMonth() + 1;
    const sDay = startDt.getDate();
    startDate = `${sYear}-${pad(sMonth)}-${pad(sDay)} 00:00:00`;
    endDate = `${year}-${pad(month)}-${pad(day)} 23:59:59`;
    periodLabel = `${sDay} ${ARABIC_MONTHS[sMonth - 1]} - ${day} ${ARABIC_MONTHS[month - 1]} ${year}`;
  } else {
    // monthly
    const lastDay = new Date(year, month, 0).getDate();
    startDate = `${year}-${pad(month)}-01 00:00:00`;
    endDate = `${year}-${pad(month)}-${pad(lastDay)} 23:59:59`;
    periodLabel = `${ARABIC_MONTHS[month - 1]} ${year}`;
  }

  return { startDate, endDate, periodLabel };
};

const formatArabicDateTime = (dateVal) => {
  if (!dateVal) return '';
  const d = new Date(dateVal);
  const now = new Date();
  
  let hours = d.getHours();
  const minutes = d.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'م' : 'ص';
  hours = hours % 12;
  hours = hours ? hours : 12;
  const timeStr = `${hours}:${minutes} ${ampm}`;

  const day = d.getDate();
  const monthName = ARABIC_MONTHS[d.getMonth()];
  
  const cairoToday = getCairoDateStr(now);
  const cairoDate = getCairoDateStr(d);
  
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const cairoYesterday = getCairoDateStr(yesterday);
  
  if (cairoDate === cairoToday) {
    return `${timeStr} • اليوم`;
  } else if (cairoDate === cairoYesterday) {
    return `${timeStr} • أمس`;
  }
  return `${timeStr} • ${day} ${monthName}`;
};

async function notifyDepositSuccess(pool, userId, depositAmount, sessionId) {
  const io = global.io || null;
  try {
    const [userRows] = await pool.query(
      'SELECT firstName, lastName FROM users WHERE id = ?',
      [userId]
    );
    const userName =
      userRows.length > 0
        ? `${userRows[0].firstName} ${userRows[0].lastName}`
        : `مستخدم رقم ${userId}`;
    const { notifyAdmins } = require('../utils/adminNotifier');
    await notifyAdmins(
      io,
      'إيداع ناجح بنجاح 🎉',
      `تم إيداع مبلغ ${depositAmount} جنيه بنجاح لمحفظة العميل ${userName}.`,
      'wallet',
      { sessionId, userId: userId.toString(), amount: depositAmount.toString() }
    );
  } catch (e) {
    console.error('Error sending successful deposit notification to admin:', e);
  }

  if (io) {
    const [balRows] = await pool.query('SELECT walletBalance FROM users WHERE id = ?', [userId]);
    const newBalance = balRows.length > 0 ? parseFloat(balRows[0].walletBalance) : 0;
    io.to(`user_${userId}`).emit('wallet_updated', {
      newBalance,
      depositAmount,
      message: `تم إضافة ${depositAmount} جنيه لمحفظتك بنجاح 🎉`,
    });
  }

  try {
    const { sendNotification } = require('../utils/notificationDispatcher');
    await sendNotification(
      io,
      userId,
      'إيداع ناجح 🎉',
      `تم شحن رصيد محفظتك بمبلغ ${depositAmount} جنيه بنجاح.`,
      'wallet',
      { type: 'deposit_success', amount: depositAmount.toString() }
    );
  } catch (err) {
    console.error('Error sending deposit success notification to user:', err);
  }

  console.log(`✅ Wallet credited: user ${userId} +${depositAmount} EGP`);
}

// ─── Kashier Config ───────────────────────────────────────────────────────────
const KASHIER_BASE_URL = process.env.KASHIER_BASE_URL || 'https://api.kashier.io';
const KASHIER_API_KEY = process.env.KASHIER_API_KEY;
const KASHIER_SECRET_KEY = process.env.KASHIER_SECRET_KEY;
const KASHIER_MERCHANT_ID = process.env.KASHIER_MERCHANT_ID;

// ─── Helper: HTTP request to Kashier ─────────────────────────────────────────
function kashierRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(KASHIER_BASE_URL + path);
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method,
      headers: {
        'Authorization': KASHIER_SECRET_KEY,
        'api-key': KASHIER_API_KEY,
        'Content-Type': 'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ─── GET /api/wallet/data ─────────────────────────────────────────────────────
const getWalletData = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const filter = req.query.filter || 'all';

    // Get wallet balance and user info
    const [users] = await pool.query(
      'SELECT walletBalance, role FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const currentBalance = parseFloat(users[0].walletBalance || 0);
    const userRole = users[0].role || 'client';
    let captainEarnings = 0;
    let duePlatformFees = 0;
    let totalBalance = currentBalance;
    let availableBalance = currentBalance;

    if (userRole === 'merchant') {
      // 1. All-time completed store orders (إجمالي مبيعات المتجر لكل الأوقات)
      const [[allTimeMerchant]] = await pool.query(
        `SELECT 
           COALESCE(SUM(orderPrice), 0) as totalAllTimeSales,
           COUNT(*) as totalAllTimeOrders
         FROM orders 
         WHERE merchantId = ? AND (
           status IN ('مكتمل', 'completed', 'Completed', 'delivered', 'Delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام')
           OR storeOrderStatus = 'COMPLETED'
         )`,
        [userId]
      );
      const allTimeSales = parseFloat(allTimeMerchant?.totalAllTimeSales || 0);

      // 2. Fetch completed UNSETTLED store orders for this merchant (المستحقات الحالية المتبادلة)
      const [unsettledOrders] = await pool.query(
        `SELECT 
           id, orderPrice, deliveryFee, paymentMethod, status, platformCommission, isPaid, isSettled
         FROM orders 
         WHERE merchantId = ? AND (
           status IN ('مكتمل', 'completed', 'Completed', 'delivered', 'Delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام')
           OR storeOrderStatus = 'COMPLETED'
         ) AND (isSettled = 0 OR isSettled IS NULL)`,
        [userId]
      );

      let unsettledSales = 0;
      let cashSales = 0;
      let onlineSales = 0;
      let platformDues = 0; // إحنا لينا كام عنده (عمولة المنصة على الطلبات)
      let merchantDues = 0; // هو ليه كام عندنا (مستحقات المنتجات المدفوعة أونلاين)
      const platformFeePerOrder = 5; // 5 EGP or custom order commission

      const isOnline = (method, isPaid) => {
        if (isPaid === 1 || isPaid === true) return true;
        if (!method) return false;
        const m = String(method).trim().toLowerCase();
        return ['online', 'kashier', 'card', 'wallet', 'محفظة', 'فيزا'].includes(m);
      };

      for (const ord of unsettledOrders) {
        const pPrice = parseFloat(ord.orderPrice || 0);
        const commission = ord.platformCommission && parseFloat(ord.platformCommission) > 0
          ? parseFloat(ord.platformCommission)
          : platformFeePerOrder;

        unsettledSales += pPrice;
        platformDues += commission;

        if (isOnline(ord.paymentMethod, ord.isPaid)) {
          onlineSales += pPrice;
          merchantDues += pPrice; // Platform collected online payment for store product, merchant is owed this!
        } else {
          cashSales += pPrice;
        }
      }

      unsettledSales = Math.round(unsettledSales * 100) / 100;
      cashSales = Math.round(cashSales * 100) / 100;
      onlineSales = Math.round(onlineSales * 100) / 100;
      platformDues = Math.round(platformDues * 100) / 100;
      merchantDues = Math.round(merchantDues * 100) / 100;

      duePlatformFees = platformDues;
      captainEarnings = allTimeSales; // Total store sales / revenue for all time
      // إجمالي الرصيد والأرباح الكلية للمحفظة كلها (يراعي الرصيد السالب أو الموجب بدقة):
      totalBalance = Math.round((currentBalance + allTimeSales) * 100) / 100;
      availableBalance = Math.round((merchantDues > 0 ? (merchantDues + Math.min(0, currentBalance)) : (currentBalance - duePlatformFees)) * 100) / 100;

      const netBalance = Math.round((platformDues - merchantDues) * 100) / 100;

      res.locals = res.locals || {};
      res.locals.captainFinancials = {
        platformDues,
        captainDues: merchantDues, // هو ليه كام عندنا من الدفع الإلكتروني
        netBalance,
        grossDeliveryFees: allTimeSales,
        cashCollected: cashSales,
        onlineCollected: onlineSales,
      };
    } else {
      // 1. All-time completed earnings across all orders and shipments (إجمالي أرباح التوصيل الكلية لكل الأوقات)
      const [[allTimeOrders]] = await pool.query(
        `SELECT 
           COALESCE(SUM(captainShare), 0) as totalCapShare,
           COALESCE(SUM(deliveryFee), 0) as totalFee
         FROM orders 
         WHERE captainId = ? AND (
           status IN ('Completed', 'منتهي', 'تم التنفيذ', 'Delivered', 'completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل') 
           OR storeOrderStatus = 'COMPLETED' 
           OR captainTripStatus = 'DELIVERED_SUCCESSFULLY'
         )`,
        [userId]
      );

      const [[allTimeShipments]] = await pool.query(
        `SELECT 
           COALESCE(SUM(captainShare), 0) as totalCapShare,
           COALESCE(SUM(price), 0) as totalPrice
         FROM shipments 
         WHERE captainId = ? AND status IN ('منتهية', 'Completed', 'تم التنفيذ', 'delivered', 'Delivered', 'completed', 'تم التوصيل', 'تم التسليم', 'مكتمل')`,
        [userId]
      );

      let allTimeCapEarnings = parseFloat(allTimeOrders?.totalCapShare || 0) + parseFloat(allTimeShipments?.totalCapShare || 0);
      if (allTimeCapEarnings === 0) {
        const gross = parseFloat(allTimeOrders?.totalFee || 0) + parseFloat(allTimeShipments?.totalPrice || 0);
        if (gross > 0) {
          allTimeCapEarnings = Math.round(gross * 0.80 * 100) / 100;
        }
      }

      // 2. Calculate from completed UNSETTLED orders (Captain)
      const [ordersData] = await pool.query(
        `SELECT deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) as finishTime, deliveredAt, createdAt
         FROM orders 
         WHERE captainId = ? AND (
           LOWER(status) IN ('completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'مكتمل', 'منتهي', 'منتهية', 'تم التنفيذ', 'تم التوصيل بنجاح') 
           OR LOWER(storeOrderStatus) IN ('completed', 'delivered') 
           OR LOWER(captainTripStatus) IN ('delivered_successfully', 'completed')
         ) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)`,
        [userId]
      );

      // 3. Calculate from completed UNSETTLED shipments (Captain)
      const [shipmentsData] = await pool.query(
        `SELECT price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                COALESCE(deliveryConfirmedAt, updatedAt, createdAt) as finishTime, deliveryConfirmedAt, createdAt
         FROM shipments 
         WHERE captainId = ? AND (
           LOWER(status) IN ('منتهية', 'completed', 'تم التنفيذ', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل', 'تم التوصيل بنجاح')
         ) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)`,
        [userId]
      );

      let grossDeliveryFees = 0;
      let platformCommission = 0;
      let totalCaptainEarnings = 0;
      let cashCollected = 0;
      let onlineCollected = 0;
      let platformDues = 0;
      let captainDues = 0;

      const isOnline = (method) => {
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

      for (const ord of ordersData) {
        const fee = parseFloat(ord.deliveryFee || 0);
        const serviceFee = parseFloat(ord.serviceFee || 0);
        const tip = parseFloat(ord.tip || 0);
        const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);

        grossDeliveryFees += fee;
        platformCommission += platShare;
        totalCaptainEarnings += capShare;

        if (isOnline(ord.paymentMethod)) {
          onlineCollected += fee;
          captainDues += capShare;
        } else {
          cashCollected += (fee + serviceFee + tip);
          platformDues += (platShare + serviceFee + tip);
        }
      }

      for (const shp of shipmentsData) {
        const price = parseFloat(shp.price || 0);
        const serviceFee = parseFloat(shp.serviceFee || 0);
        const tip = parseFloat(shp.tip || 0);
        const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);

        grossDeliveryFees += price;
        platformCommission += platShare;
        totalCaptainEarnings += capShare;

        if (isOnline(shp.paymentMethod)) {
          onlineCollected += price;
          captainDues += capShare;
        } else {
          cashCollected += (price + serviceFee + tip);
          platformDues += (platShare + serviceFee + tip);
        }
      }

      grossDeliveryFees = Math.round(grossDeliveryFees * 100) / 100;
      platformCommission = Math.round(platformCommission * 100) / 100;
      totalCaptainEarnings = Math.round(totalCaptainEarnings * 100) / 100;
      cashCollected = Math.round(cashCollected * 100) / 100;
      onlineCollected = Math.round(onlineCollected * 100) / 100;
      platformDues = Math.round(platformDues * 100) / 100;
      captainDues = Math.round(captainDues * 100) / 100;
      duePlatformFees = platformDues;

      const finalAllTimeCapEarnings = Math.max(allTimeCapEarnings, totalCaptainEarnings);
      captainEarnings = finalAllTimeCapEarnings;
      // إجمالي الرصيد والأرباح الكلية للمحفظة كلها (يراعي الرصيد السالب أو الموجب بدقة):
      totalBalance = Math.round((currentBalance + finalAllTimeCapEarnings) * 100) / 100;
      availableBalance = Math.round((captainDues > 0 ? (captainDues + Math.min(0, currentBalance)) : (currentBalance - duePlatformFees)) * 100) / 100;

      const netBalance = Math.round((platformDues - captainDues) * 100) / 100;
      // Today summary calculation: includes all orders and shipments completed today (both settled and unsettled)
      const cairoToday = getCairoDateStr();
      let todayEarnings = 0;
      let todayCommission = 0;
      let todayOrdersCount = 0;

      try {
        const [todayOrders] = await pool.query(
          `SELECT deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                  COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) as finishTime
           FROM orders 
           WHERE captainId = ? AND (
             LOWER(status) IN ('completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'مكتمل', 'منتهي', 'منتهية', 'تم التنفيذ', 'تم التوصيل بنجاح') 
             OR LOWER(storeOrderStatus) IN ('completed', 'delivered') 
             OR LOWER(captainTripStatus) IN ('delivered_successfully', 'completed')
           )`,
          [userId]
        );

        for (const ord of todayOrders) {
          const dStr = getCairoDateStr(ord.finishTime);
          if (dStr === cairoToday) {
            const fee = parseFloat(ord.deliveryFee || 0);
            const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);
            todayEarnings += capShare;
            todayCommission += platShare;
            todayOrdersCount++;
          }
        }
      } catch (eTodayOrd) {
        console.error('Error in todayOrders query:', eTodayOrd);
      }

      try {
        const [todayShipments] = await pool.query(
          `SELECT price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                  COALESCE(deliveryConfirmedAt, updatedAt, createdAt) as finishTime
           FROM shipments 
           WHERE captainId = ? AND (
             LOWER(status) IN ('منتهية', 'completed', 'تم التنفيذ', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل', 'تم التوصيل بنجاح')
           )`,
          [userId]
        );

        for (const shp of todayShipments) {
          const dStr = getCairoDateStr(shp.finishTime);
          if (dStr === cairoToday) {
            const price = parseFloat(shp.price || 0);
            const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);
            todayEarnings += capShare;
            todayCommission += platShare;
            todayOrdersCount++;
          }
        }
      } catch (eTodayShp) {
        console.error('Error in todayShipments query:', eTodayShp);
      }

      todayEarnings = Math.round(todayEarnings * 100) / 100;
      todayCommission = Math.round(todayCommission * 100) / 100;
      const todayNet = Math.round((todayEarnings - todayCommission) * 100) / 100;
      const nowCairo = new Date();
      const todayDateFormatted = `${nowCairo.getDate()} ${ARABIC_MONTHS[nowCairo.getMonth()]}`;

      // Fetch last settlement for captain
      let lastSettlement = null;
      try {
        const [lastSettlementRows] = await pool.query(
          `SELECT id, settlementNumber, settledAmount, netBalance, settlementDate, createdAt, notes
           FROM captain_settlements
           WHERE captainId = ?
           ORDER BY createdAt DESC
           LIMIT 1`,
          [userId]
        );
        if (lastSettlementRows.length > 0) {
          const ls = lastSettlementRows[0];
          const lsDate = new Date(ls.settlementDate || ls.createdAt);
          lastSettlement = {
            id: ls.id.toString(),
            settlementNumber: ls.settlementNumber,
            settledAmount: parseFloat(ls.settledAmount || 0),
            date: `${lsDate.getDate()} ${ARABIC_MONTHS[lsDate.getMonth()]} ${lsDate.getFullYear()}`,
            formattedAmount: `تم تحصيل ${parseFloat(ls.settledAmount || 0).toFixed(0)} ج.م`,
            notes: ls.notes || '',
          };
        }
      } catch (errLs) {
        console.error('Error fetching last settlement:', errLs);
      }

      res.locals = res.locals || {};
      res.locals.captainFinancials = {
        platformDues,
        captainDues,
        netBalance,
        grossDeliveryFees,
        cashCollected,
        onlineCollected,
        todaySummary: {
          earnings: todayEarnings,
          commission: todayCommission,
          net: todayNet,
          date_formatted: todayDateFormatted,
          count: todayOrdersCount,
        },
        duesSummary: {
          platform_dues: platformDues,
          remaining_dues: platformDues,
          last_settlement: lastSettlement,
        },
      };
    }

    // Get recent transactions with optional filter
    let filterClause = '';
    if (filter === 'orders' || filter === 'order') {
      filterClause = " AND (title LIKE '%طلب%' OR title LIKE '%شحنة%' OR title LIKE '%توصيل%')";
    } else if (filter === 'deposits' || filter === 'deposit' || filter === 'شحن') {
      filterClause = " AND (title LIKE '%شحن%' OR title LIKE '%إيداع%')";
    } else if (filter === 'withdrawals' || filter === 'withdraw' || filter === 'سحب') {
      filterClause = " AND (type = 'withdraw' AND title NOT LIKE '%منصة%')";
    } else if (filter === 'platform_fees' || filter === 'platform_fee' || filter === 'رسوم المنصة') {
      filterClause = " AND (title LIKE '%منصة%' OR title LIKE '%عمولة%')";
    }

    const [transactions] = await pool.query(
      `SELECT id, title, amount, type, status, reference, paymentMethod, createdAt as date
       FROM wallet_transactions
       WHERE userId = ? ${filterClause}
       ORDER BY createdAt DESC
       LIMIT 30`,
      [userId]
    );

    // For merchants, merge recent store orders into the transactions feed
    if (userRole === 'merchant') {
      try {
        const [merchantOrders] = await pool.query(
          `SELECT id, clientName, orderPrice, status, createdAt as date
           FROM orders
           WHERE merchantId = ?
           ORDER BY createdAt DESC
           LIMIT 20`,
          [userId]
        );

        const existingReferences = new Set(
          transactions.map(t => t.reference || '').filter(Boolean)
        );

        for (const ord of merchantOrders) {
          const orderRef = `#ORD${ord.id}`;
          if (!existingReferences.has(orderRef)) {
            const isDone = ['Completed', 'delivered', 'Delivered', 'تم التوصيل', 'مكتمل', 'منتهية', 'تم التسليم', 'تم الاستلام'].includes(ord.status);
            
            if (filter === 'all' || filter === 'orders' || filter === 'order') {
              transactions.push({
                id: `ord_${ord.id}`,
                title: `طلب متجر #${ord.id} - ${ord.clientName || 'عميل'}`,
                amount: parseFloat(ord.orderPrice || 0),
                type: 'deposit',
                category: 'orders',
                status: isDone ? 'success' : (['Cancelled', 'ملغى', 'مرفوض'].includes(ord.status) ? 'failed' : 'pending'),
                reference: orderRef,
                paymentMethod: 'store_order',
                date: ord.date,
              });
            }

            if (isDone && (filter === 'all' || filter === 'platform_fees' || filter === 'platform_fee' || filter === 'رسوم المنصة')) {
              transactions.push({
                id: `fee_${ord.id}`,
                title: `رسوم المنصة - طلب #${ord.id}`,
                amount: 5.0,
                type: 'withdraw',
                category: 'platform_fees',
                status: 'success',
                reference: `#FEE${ord.id}`,
                paymentMethod: 'platform_fee',
                date: ord.date,
              });
            }
          }
        }

        // Sort combined transactions newest first
        transactions.sort((a, b) => new Date(b.date) - new Date(a.date));
      } catch (errOrders) {
        console.error('Error fetching merchant orders for wallet:', errOrders);
      }
    }

    // Get pending withdrawal if exists
    let pendingWithdrawal = null;
    const [pendingRows] = await pool.query(
      `SELECT id, title, amount, type, status, paymentMethod, accountDetails, createdAt
       FROM wallet_transactions
       WHERE userId = ? AND type = 'withdraw' AND status = 'pending'
       LIMIT 1`,
      [userId]
    );

    if (pendingRows.length > 0) {
      const p = pendingRows[0];
      pendingWithdrawal = {
        id: p.id.toString(),
        title: p.title,
        amount: parseFloat(p.amount),
        type: p.type,
        status: p.status,
        paymentMethod: p.paymentMethod,
        accountDetails: p.accountDetails,
        createdAt: p.createdAt.toISOString(),
        date: new Date(p.createdAt).toLocaleString('ar-EG', {
          hour: '2-digit',
          minute: '2-digit',
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
        }),
      };
    }

    res.status(200).json({
      status: 1,
      data: {
        total_balance: totalBalance,
        captain_earnings: captainEarnings,
        due_platform_fees: duePlatformFees,
        current_balance: currentBalance,
        available_balance: availableBalance,
        platform_dues: res.locals?.captainFinancials?.platformDues ?? duePlatformFees,
        captain_dues: res.locals?.captainFinancials?.captainDues ?? 0,
        net_balance: res.locals?.captainFinancials?.netBalance ?? duePlatformFees,
        gross_delivery_fees: res.locals?.captainFinancials?.grossDeliveryFees ?? (captainEarnings + duePlatformFees),
        cash_collected: res.locals?.captainFinancials?.cashCollected ?? 0,
        online_collected: res.locals?.captainFinancials?.onlineCollected ?? 0,
        is_online_paid_exists: (res.locals?.captainFinancials?.captainDues ?? 0) > 0,
        today_summary: res.locals?.captainFinancials?.todaySummary ?? {
          earnings: 0,
          commission: 0,
          net: 0,
          date_formatted: `${new Date().getDate()} ${ARABIC_MONTHS[new Date().getMonth()]}`,
          count: 0,
        },
        dues_summary: res.locals?.captainFinancials?.duesSummary ?? {
          platform_dues: duePlatformFees,
          remaining_dues: duePlatformFees,
          last_settlement: null,
        },
        pending_balance: pendingWithdrawal ? pendingWithdrawal.amount : 0,
        pendingWithdrawal,
        recent_transactions: transactions.map(tx => {
          let category = tx.category || 'other';
          const t = tx.title || '';
          if (category === 'other') {
            if (t.includes('طلب') || t.includes('شحنة') || t.includes('توصيل')) {
              category = 'orders';
            } else if (t.includes('منصة') || t.includes('عمولة')) {
              category = 'platform_fees';
            } else if (tx.type === 'withdraw') {
              category = 'withdrawals';
            } else if (t.includes('شحن') || t.includes('إيداع') || tx.type === 'deposit') {
              category = 'deposits';
            }
          }

          return {
            id: tx.id.toString(),
            title: tx.title,
            amount: parseFloat(tx.amount),
            type: tx.type,
            category: category,
            status: tx.status,
            reference: tx.reference || `#TXN${12588 + (parseInt(tx.id) || 1)}`,
            date: tx.date ? new Date(tx.date).toLocaleString('ar-EG', {
              hour: '2-digit',
              minute: '2-digit',
              day: '2-digit',
              month: '2-digit',
              year: 'numeric',
            }) : '',
          };
        }),
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── POST /api/wallet/withdraw ───────────────────────────────────────────────
const withdraw = async (req, res, next) => {
  try {
    const { amount, paymentMethod, name } = req.body;
    const phone = (req.body.phone || req.body['?phone'] || '')?.toString().trim();
    const walletProvider = (req.body.walletProvider || req.body['?walletProvider'] || '')?.toString().trim();
    const bankName = (req.body.bankName || req.body['?bankName'] || '')?.toString().trim();
    const bankAccountNumber = (req.body.bankAccountNumber || req.body['?bankAccountNumber'] || '')?.toString().trim();
    const accountHolderName = (name || req.body['?name'] || '')?.toString().trim();
    const userId = req.user.id;

    if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
      return res.status(400).json({ status: 0, message: 'المبلغ غير صالح' });
    }

    if (!paymentMethod || (paymentMethod !== 'wallet' && paymentMethod !== 'bank' && paymentMethod !== 'instapay')) {
      return res.status(400).json({ status: 0, message: 'طريقة الدفع غير صالحة' });
    }

    const pool = getPool();

    // Check if user already has a pending withdrawal request
    const [pendingRequests] = await pool.query(
      "SELECT id FROM wallet_transactions WHERE userId = ? AND type = 'withdraw' AND status = 'pending'",
      [userId]
    );

    if (pendingRequests.length > 0) {
      return res.status(400).json({
        status: 0,
        message: 'لديك طلب سحب معلق بالفعل. يرجى الانتظار حتى يتم معالجته.'
      });
    }

    // Get current balance and name
    const [users] = await pool.query(
      'SELECT walletBalance, firstName, lastName FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const currentBalance = parseFloat(users[0].walletBalance || 0);
    const amountVal = parseFloat(amount);

    if (currentBalance < amountVal) {
      return res.status(400).json({ status: 0, message: 'رصيد محفظتك غير كافٍ لإتمام هذه العملية' });
    }

    let accountDetailsObj = {};
    let title = '';

    if (paymentMethod === 'instapay') {
      const instapayHandle = (req.body.instapayHandle || phone || '').toString().trim();
      if (!instapayHandle || !accountHolderName) {
        return res.status(400).json({ status: 0, message: 'جميع بيانات انستاباي مطلوبة (معرف انستاباي أو الهاتف واسم صاحب الحساب)' });
      }
      accountDetailsObj = { instapayHandle, name: accountHolderName, phone: instapayHandle };
      title = `طلب سحب عبر انستاباي - ${instapayHandle}`;
    } else if (paymentMethod === 'wallet') {
      if (!phone || !accountHolderName || !walletProvider) {
        return res.status(400).json({ status: 0, message: 'جميع بيانات المحفظة مطلوبة' });
      }
      accountDetailsObj = { phone, name: accountHolderName, walletProvider };
      title = `طلب سحب للمحفظة (${walletProvider}) - ${phone}`;
    } else {
      if (!bankName || !bankAccountNumber || !accountHolderName) {
        return res.status(400).json({ status: 0, message: 'جميع بيانات الحساب البنكي مطلوبة' });
      }
      accountDetailsObj = { bankName, bankAccountNumber, name: accountHolderName };
      title = `طلب سحب للحساب البنكي (${bankName}) - ${bankAccountNumber}`;
    }

    const accountDetailsStr = JSON.stringify(accountDetailsObj);

    const userRole = users[0].role || 'client';
    let totalDeduction = amountVal;
    let actualPlatformFee = 0;

    // Only apply default driver 20% platform commission formula for captains
    if (userRole === 'captain') {
      const platformFee = Math.round((amountVal / 0.80 - amountVal) * 100) / 100;
      totalDeduction = Math.min(currentBalance, Math.round((amountVal + platformFee) * 100) / 100);
      actualPlatformFee = Math.round((totalDeduction - amountVal) * 100) / 100;
    }

    // Deduct balance and insert transaction
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Deduct total amount (withdrawal amount + platform fee if applicable)
      await conn.query(
        'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
        [totalDeduction, userId]
      );

      // Create pending transaction record for the requested withdrawal
      const [result] = await conn.query(
        `INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, accountDetails)
         VALUES (?, ?, ?, 'withdraw', 'pending', ?, ?)`,
        [userId, title, amountVal, paymentMethod, accountDetailsStr]
      );

      // If platform fee was deducted, record platform fee transaction
      if (actualPlatformFee > 0) {
        await conn.query(
          `INSERT INTO wallet_transactions (userId, title, amount, type, status)
           VALUES (?, ?, ?, 'withdraw', 'success')`,
          [userId, `عمولة المنصة من طلب السحب (${actualPlatformFee} جنيه)`, actualPlatformFee]
        );
      }

      await conn.commit();

      // Emit socket event to admins room
      const io = global.io || null;
      if (io) {
        io.to('admins').emit('new_withdrawal_request', {
          transactionId: result.insertId,
          userId,
          amount: amountVal,
          platformFee: actualPlatformFee,
          totalDeducted: totalDeduction,
          paymentMethod,
          title
        });
      }

      // Notify admins via web-push / socket / FCM
      try {
        const userName = `${users[0].firstName} ${users[0].lastName}`;
        const { notifyAdmins } = require('../utils/adminNotifier');
        await notifyAdmins(
          io,
          'طلب سحب جديد قيد الانتظار 💵',
          `العميل ${userName} طلب سحب مبلغ ${amountVal} جنيه عبر ${paymentMethod === 'wallet' ? 'المحفظة الإلكترونية' : 'الحساب البنكي'}.`,
          'wallet',
          {
            transactionId: result.insertId.toString(),
            userId: userId.toString(),
            amount: amountVal.toString(),
            paymentMethod
          }
        );
      } catch (err) {
        console.error('Error sending withdraw admin notification:', err);
      }

      // Notify User / Merchant about their withdrawal request
      try {
        const { sendNotification } = require('../utils/notificationDispatcher');
        await sendNotification(
          io,
          userId,
          'تم استلام طلب السحب 💵',
          `تم استلام طلب سحب مبلغ ${amountVal} جنيه بنجاح وجارٍ مراجعته من الإدارة.`,
          'wallet',
          {
            type: 'withdrawal_requested',
            transactionId: result.insertId.toString(),
            amount: amountVal.toString()
          }
        );
      } catch (err) {
        console.error('Error sending withdraw notification to user:', err);
      }

      res.status(200).json({
        status: 1,
        message: 'تم تقديم طلب السحب بنجاح وهو قيد المراجعة الآن',
        data: {
          transactionId: result.insertId.toString(),
          amount: amountVal,
          status: 'pending',
          createdAt: new Date().toISOString()
        }
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

// ─── GET /api/wallet/transactions ─────────────────────────────────────────────
// ─── GET /api/wallet/transactions ─────────────────────────────────────────────
const getTransactions = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const userRole = req.user.role || 'client';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const filter = (req.query.filter || 'all').toLowerCase();

    if (userRole === 'captain' || userRole === 'driver') {
      // Build unified transaction feed for captain matching GEBLY Captain Wallet design
      let allItems = [];

      // 1. Fetch completed orders (Earnings & Commissions)
      try {
        const [orders] = await pool.query(
          `SELECT id, orderNumber, deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                  COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) as finishTime, deliveredAt, createdAt
           FROM orders
           WHERE captainId = ? AND (
             LOWER(status) IN ('completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'مكتمل', 'منتهي', 'منتهية', 'تم التنفيذ', 'تم التوصيل بنجاح')
             OR LOWER(storeOrderStatus) IN ('completed', 'delivered')
             OR LOWER(captainTripStatus) IN ('delivered_successfully', 'completed')
           )
           ORDER BY finishTime DESC
           LIMIT 100`,
          [userId]
        );

        for (const ord of orders) {
          const fee = parseFloat(ord.deliveryFee || 0);
          const rawPlat = ord.platformShare;
          const rawCap = ord.captainShare;
          let platShare = Math.round(fee * 0.20 * 100) / 100;
          let capShare = Math.max(0, fee - platShare);
          if (rawPlat != null && rawCap != null && parseFloat(rawCap) > 0) {
            platShare = parseFloat(rawPlat);
            capShare = parseFloat(rawCap);
          }
          const d = ord.finishTime || ord.deliveredAt || ord.createdAt;

          // Earnings entry
          allItems.push({
            id: `ord_${ord.id}_earn`,
            title: 'أرباح طلب مكتمل',
            amount: capShare,
            type: 'deposit',
            category: 'earnings',
            status: 'success',
            date: formatArabicDateTime(d),
            rawDate: new Date(d),
            reference: ord.orderNumber || `#ORD${ord.id}`,
            description: `طلب رقم ${ord.orderNumber || ord.id}`,
          });

          // Commission entry
          allItems.push({
            id: `ord_${ord.id}_comm`,
            title: 'عمولة المنصة',
            amount: platShare,
            type: 'withdraw',
            category: 'commission',
            status: 'success',
            date: formatArabicDateTime(d),
            rawDate: new Date(d),
            reference: ord.orderNumber || `#ORD${ord.id}`,
            description: `عمولة طلب رقم ${ord.orderNumber || ord.id}`,
          });
        }
      } catch (errOrd) {
        console.error('Error fetching captain orders for transactions:', errOrd);
      }

      // 2. Fetch completed shipments (Earnings & Commissions)
      try {
        const [shipments] = await pool.query(
          `SELECT id, shipmentNumber, price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
                  COALESCE(deliveryConfirmedAt, updatedAt, createdAt) as finishTime, deliveryConfirmedAt, createdAt
           FROM shipments
           WHERE captainId = ? AND (
             LOWER(status) IN ('منتهية', 'completed', 'تم التنفيذ', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل', 'تم التوصيل بنجاح')
           )
           ORDER BY finishTime DESC
           LIMIT 100`,
          [userId]
        );

        for (const shp of shipments) {
          const price = parseFloat(shp.price || 0);
          let platShare = Math.round(price * 0.20 * 100) / 100;
          let capShare = Math.max(0, price - platShare);
          if (shp.platformShare != null && shp.captainShare != null && parseFloat(shp.captainShare) > 0) {
            platShare = parseFloat(shp.platformShare);
            capShare = parseFloat(shp.captainShare);
          }
          const d = shp.finishTime || shp.deliveryConfirmedAt || shp.createdAt;

          // Earnings entry
          allItems.push({
            id: `shp_${shp.id}_earn`,
            title: 'أرباح شحنة مكتملة',
            amount: capShare,
            type: 'deposit',
            category: 'earnings',
            status: 'success',
            date: formatArabicDateTime(d),
            rawDate: new Date(d),
            reference: shp.shipmentNumber || `#SHP${shp.id}`,
            description: `شحنة رقم ${shp.shipmentNumber || shp.id}`,
          });

          // Commission entry
          allItems.push({
            id: `shp_${shp.id}_comm`,
            title: 'عمولة المنصة',
            amount: platShare,
            type: 'withdraw',
            category: 'commission',
            status: 'success',
            date: formatArabicDateTime(d),
            rawDate: new Date(d),
            reference: shp.shipmentNumber || `#SHP${shp.id}`,
            description: `عمولة شحنة رقم ${shp.shipmentNumber || shp.id}`,
          });
        }
      } catch (errShp) {
        console.error('Error fetching captain shipments for transactions:', errShp);
      }

      // 3. Fetch past settlements
      try {
        const [settlements] = await pool.query(
          `SELECT id, settlementNumber, settledAmount, settlementScope, settlementDate, createdAt, notes
           FROM captain_settlements
           WHERE captainId = ?
           ORDER BY createdAt DESC
           LIMIT 50`,
          [userId]
        );

        for (const s of settlements) {
          const d = s.settlementDate || s.createdAt;
          allItems.push({
            id: `settle_${s.id}`,
            title: 'تسوية مالية من الإدارة',
            amount: parseFloat(s.settledAmount || 0),
            type: 'settlement',
            category: 'settlement',
            status: 'success',
            date: formatArabicDateTime(d),
            rawDate: new Date(d),
            reference: s.settlementNumber,
            description: s.notes || `تسوية رقم ${s.settlementNumber}`,
          });
        }
      } catch (errSet) {
        console.error('Error fetching captain settlements for transactions:', errSet);
      }

      // 4. Fetch manual wallet transactions (e.g. deposit / withdraw)
      try {
        const [wt] = await pool.query(
          `SELECT id, title, amount, type, status, reference, createdAt as date
           FROM wallet_transactions
           WHERE userId = ? AND title NOT LIKE '%طلب%' AND title NOT LIKE '%شحنة%' AND title NOT LIKE '%تسوية%'
           ORDER BY createdAt DESC
           LIMIT 30`,
          [userId]
        );

        for (const t of wt) {
          allItems.push({
            id: `tx_${t.id}`,
            title: t.title,
            amount: parseFloat(t.amount || 0),
            type: t.type,
            category: t.type === 'deposit' ? 'deposits' : 'withdrawals',
            status: t.status,
            date: formatArabicDateTime(t.date),
            rawDate: new Date(t.date),
            reference: t.reference || `#TXN${t.id}`,
            description: t.title,
          });
        }
      } catch (errWt) {
        console.error('Error fetching manual wallet transactions for captain:', errWt);
      }

      // Sort newest first
      allItems.sort((a, b) => b.rawDate - a.rawDate);

      // Apply filter
      if (filter === 'earnings' || filter === 'orders') {
        allItems = allItems.filter(i => i.category === 'earnings');
      } else if (filter === 'commission' || filter === 'platform_fees' || filter === 'commissions') {
        allItems = allItems.filter(i => i.category === 'commission');
      } else if (filter === 'settlements' || filter === 'settlement') {
        allItems = allItems.filter(i => i.category === 'settlement');
      }

      const total = allItems.length;
      const offset = (page - 1) * limit;
      const paginated = allItems.slice(offset, offset + limit);

      return res.status(200).json({
        status: 1,
        data: {
          transactions: paginated,
          total,
          page,
          totalPages: Math.ceil(total / limit) || 1,
        },
      });
    }

    // Default flow for merchant & client
    const offset = (page - 1) * limit;
    const [transactions] = await pool.query(
      `SELECT id, title, amount, type, status, createdAt as date
       FROM wallet_transactions
       WHERE userId = ?
       ORDER BY createdAt DESC
       LIMIT ? OFFSET ?`,
      [userId, limit, offset]
    );

    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) as total FROM wallet_transactions WHERE userId = ?',
      [userId]
    );

    res.status(200).json({
      status: 1,
      data: {
        transactions: transactions.map(tx => ({
          id: tx.id.toString(),
          title: tx.title,
          amount: parseFloat(tx.amount),
          type: tx.type,
          category: tx.type,
          status: tx.status,
          date: formatArabicDateTime(tx.date),
        })),
        total,
        page,
        totalPages: Math.ceil(total / limit) || 1,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── GET /api/wallet/statement ────────────────────────────────────────────────
const getAccountStatement = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const period = (req.query.period || 'monthly').toLowerCase(); // 'daily', 'weekly', 'monthly'
    const { startDate, endDate, periodLabel } = parsePeriodRange(period, req.query.date);

    const [orders] = await pool.query(
      `SELECT id, orderNumber, deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
              COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) as finishTime,
              deliveredAt, createdAt
       FROM orders
       WHERE captainId = ? AND (
         LOWER(status) IN ('completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'مكتمل', 'منتهي', 'منتهية', 'تم التنفيذ', 'تم التوصيل بنجاح')
         OR LOWER(storeOrderStatus) IN ('completed', 'delivered')
         OR LOWER(captainTripStatus) IN ('delivered_successfully', 'completed')
       ) AND (
         COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) BETWEEN ? AND ?
       )
       ORDER BY finishTime DESC`,
      [userId, startDate, endDate]
    );

    const [shipments] = await pool.query(
      `SELECT id, shipmentNumber, price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip,
              COALESCE(deliveryConfirmedAt, updatedAt, createdAt) as finishTime,
              deliveryConfirmedAt, createdAt
       FROM shipments
       WHERE captainId = ? AND (
         LOWER(status) IN ('منتهية', 'completed', 'تم التنفيذ', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل', 'تم التوصيل بنجاح')
       ) AND (
         COALESCE(deliveryConfirmedAt, updatedAt, createdAt) BETWEEN ? AND ?
       )
       ORDER BY finishTime DESC`,
      [userId, startDate, endDate]
    );

    let totalEarnings = 0;
    let platformCommission = 0;
    const items = [];

    const resolveShares = (fee, rawPlat, rawCap) => {
      const totalFee = parseFloat(fee || 0);
      if (rawPlat != null && rawCap != null && parseFloat(rawCap) > 0) {
        return { platShare: parseFloat(rawPlat), capShare: parseFloat(rawCap) };
      }
      const defaultPlat = Math.round(totalFee * 0.20 * 100) / 100;
      return { platShare: defaultPlat, capShare: Math.max(0, totalFee - defaultPlat) };
    };

    for (const ord of orders) {
      const fee = parseFloat(ord.deliveryFee || 0);
      const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);
      totalEarnings += capShare;
      platformCommission += platShare;
      const d = ord.finishTime || ord.deliveredAt || ord.createdAt;
      items.push({
        id: `ord_${ord.id}`,
        number: ord.orderNumber || `#ORD${ord.id}`,
        type: 'طلب',
        paymentMethod: ord.paymentMethod || 'كاش',
        deliveryFee: fee,
        captainShare: capShare,
        platformShare: platShare,
        net: capShare,
        date: formatArabicDateTime(d),
        rawDate: d,
      });
    }

    for (const shp of shipments) {
      const price = parseFloat(shp.price || 0);
      const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);
      totalEarnings += capShare;
      platformCommission += platShare;
      const d = shp.finishTime || shp.deliveryConfirmedAt || shp.createdAt;
      items.push({
        id: `shp_${shp.id}`,
        number: shp.shipmentNumber || `#SHP${shp.id}`,
        type: 'شحنة',
        paymentMethod: shp.paymentMethod || 'كاش',
        deliveryFee: price,
        captainShare: capShare,
        platformShare: platShare,
        net: capShare,
        date: formatArabicDateTime(d),
        rawDate: d,
      });
    }

    items.sort((a, b) => new Date(b.rawDate) - new Date(a.rawDate));

    totalEarnings = Math.round(totalEarnings * 100) / 100;
    platformCommission = Math.round(platformCommission * 100) / 100;
    const netDues = Math.round((totalEarnings - platformCommission) * 100) / 100;

    res.status(200).json({
      status: 1,
      data: {
        period,
        period_label: periodLabel,
        start_date: startDate,
        end_date: endDate,
        total_earnings: totalEarnings,
        platform_commission: platformCommission,
        net_dues: netDues,
        deliveries_count: items.length,
        items,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── GET /api/wallet/statement/export ─────────────────────────────────────────
const exportAccountStatement = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const format = (req.query.format || 'excel').toLowerCase();
    const period = (req.query.period || 'monthly').toLowerCase();
    const { startDate, endDate, periodLabel } = parsePeriodRange(period, req.query.date);

    const [captainRows] = await pool.query(
      'SELECT firstName, lastName, phone FROM users WHERE id = ?',
      [userId]
    );
    const captainName = captainRows.length > 0 ? `${captainRows[0].firstName} ${captainRows[0].lastName}` : 'الكابتن';

    const [orders] = await pool.query(
      `SELECT id, orderNumber, deliveryFee, platformShare, captainShare, paymentMethod,
              COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) as finishTime,
              deliveredAt, createdAt
       FROM orders
       WHERE captainId = ? AND (
         LOWER(status) IN ('completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'تم الاستلام', 'مكتمل', 'منتهي', 'منتهية', 'تم التنفيذ', 'تم التوصيل بنجاح')
         OR LOWER(storeOrderStatus) IN ('completed', 'delivered')
         OR LOWER(captainTripStatus) IN ('delivered_successfully', 'completed')
       ) AND (
         COALESCE(deliveredAt, deliveryConfirmedAt, completedAt, updatedAt, createdAt) BETWEEN ? AND ?
       )
       ORDER BY finishTime DESC`,
      [userId, startDate, endDate]
    );

    const [shipments] = await pool.query(
      `SELECT id, shipmentNumber, price, platformShare, captainShare, paymentMethod,
              COALESCE(deliveryConfirmedAt, updatedAt, createdAt) as finishTime,
              deliveryConfirmedAt, createdAt
       FROM shipments
       WHERE captainId = ? AND (
         LOWER(status) IN ('منتهية', 'completed', 'تم التنفيذ', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل', 'تم التوصيل بنجاح')
       ) AND (
         COALESCE(deliveryConfirmedAt, updatedAt, createdAt) BETWEEN ? AND ?
       )
       ORDER BY finishTime DESC`,
      [userId, startDate, endDate]
    );

    let totalEarnings = 0;
    let platformCommission = 0;
    const items = [];

    const resolveShares = (fee, rawPlat, rawCap) => {
      const totalFee = parseFloat(fee || 0);
      if (rawPlat != null && rawCap != null && parseFloat(rawCap) > 0) {
        return { platShare: parseFloat(rawPlat), capShare: parseFloat(rawCap) };
      }
      const defaultPlat = Math.round(totalFee * 0.20 * 100) / 100;
      return { platShare: defaultPlat, capShare: Math.max(0, totalFee - defaultPlat) };
    };

    for (const ord of orders) {
      const fee = parseFloat(ord.deliveryFee || 0);
      const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);
      totalEarnings += capShare;
      platformCommission += platShare;
      const d = ord.deliveredAt || ord.createdAt;
      items.push({
        number: ord.orderNumber || `#ORD${ord.id}`,
        type: 'طلب متجر',
        paymentMethod: ord.paymentMethod || 'كاش',
        deliveryFee: fee,
        captainShare: capShare,
        platformShare: platShare,
        net: capShare,
        date: formatArabicDateTime(d),
      });
    }

    for (const shp of shipments) {
      const price = parseFloat(shp.price || 0);
      const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);
      totalEarnings += capShare;
      platformCommission += platShare;
      const d = shp.deliveryConfirmedAt || shp.createdAt;
      items.push({
        number: shp.shipmentNumber || `#SHP${shp.id}`,
        type: 'شحنة توصيل',
        paymentMethod: shp.paymentMethod || 'كاش',
        deliveryFee: price,
        captainShare: capShare,
        platformShare: platShare,
        net: capShare,
        date: formatArabicDateTime(d),
      });
    }

    totalEarnings = Math.round(totalEarnings * 100) / 100;
    platformCommission = Math.round(platformCommission * 100) / 100;
    const netDues = Math.round((totalEarnings - platformCommission) * 100) / 100;

    if (format === 'excel' || format === 'xlsx') {
      const wb = XLSX.utils.book_new();

      const summaryData = [
        ['كشف حساب كابتن - منصة GEBLY'],
        ['اسم الكابتن:', captainName],
        ['الفترة:', periodLabel],
        ['تاريخ التصدير:', new Date().toLocaleString('ar-EG')],
        [],
        ['إجمالي الأرباح (ج.م)', 'عمولات المنصة (ج.م)', 'صافي المستحق (ج.م)', 'إجمالي الطلبات'],
        [totalEarnings, platformCommission, netDues, items.length],
        [],
        ['م', 'رقم الطلب / الشحنة', 'النوع', 'طريقة الدفع', 'قيمة التوصيل (ج.م)', 'أرباح الكابتن (ج.م)', 'عمولة المنصة (ج.م)', 'الصافي (ج.م)', 'التاريخ والوقت'],
      ];

      items.forEach((item, index) => {
        summaryData.push([
          index + 1,
          item.number,
          item.type,
          item.paymentMethod,
          item.deliveryFee,
          item.captainShare,
          item.platformShare,
          item.net,
          item.date,
        ]);
      });

      const ws = XLSX.utils.aoa_to_sheet(summaryData);
      XLSX.utils.book_append_sheet(wb, ws, 'كشف الحساب');

      const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="statement_${period}_${getCairoDateStr(targetDate)}.xlsx"`);
      return res.send(buffer);
    }

    // PDF / HTML Format
    const rowsHtml = items.map((it, idx) => `
      <tr>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; text-align: center;">${idx + 1}</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; font-weight: bold;">${it.number}</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0;">${it.type}</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0;">${it.paymentMethod}</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; text-align: center;">${it.deliveryFee.toFixed(2)} ج.م</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; text-align: center; color: #10B981; font-weight: bold;">${it.captainShare.toFixed(2)} ج.م</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; text-align: center; color: #F97316;">${it.platformShare.toFixed(2)} ج.م</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; text-align: center; font-weight: bold;">${it.net.toFixed(2)} ج.م</td>
        <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; font-size: 12px; color: #64748B;">${it.date}</td>
      </tr>
    `).join('');

    const htmlContent = `
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
      <meta charset="utf-8">
      <title>كشف حساب كابتن - ${periodLabel}</title>
      <style>
        body { font-family: 'Cairo', Arial, sans-serif; background: #F8FAFC; margin: 0; padding: 24px; color: #0F172A; }
        .card { background: white; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); padding: 24px; margin-bottom: 20px; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #FD5001; padding-bottom: 16px; margin-bottom: 20px; }
        .logo { font-size: 26px; font-weight: bold; color: #FD5001; }
        .metrics-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
        .metric-box { background: #F1F5F9; border-radius: 12px; padding: 16px; text-align: center; }
        .metric-val { font-size: 22px; font-weight: bold; margin-top: 6px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th { background: #0F1E36; color: white; padding: 12px; font-size: 13px; text-align: center; }
        @media print {
          body { background: white; padding: 0; }
          .no-print { display: none; }
          .card { box-shadow: none; border: 1px solid #E2E8F0; }
        }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <div>
            <div class="logo">GEBLY</div>
            <div style="color: #64748B; font-size: 13px;">رصيد شامل .. شفافية كاملة .. تحت إدارة GEBLY</div>
          </div>
          <div style="text-align: left;">
            <h2 style="margin: 0; color: #0F1E36;">كشف حساب كابتن</h2>
            <div style="color: #64748B; font-size: 14px;">الكابتن: <b>${captainName}</b></div>
            <div style="color: #64748B; font-size: 13px;">الفترة: <b>${periodLabel}</b></div>
          </div>
        </div>

        <div class="metrics-grid">
          <div class="metric-box" style="border-top: 4px solid #10B981;">
            <div style="color: #64748B; font-size: 14px;">إجمالي الأرباح</div>
            <div class="metric-val" style="color: #10B981;">${totalEarnings.toFixed(2)} ج.م</div>
          </div>
          <div class="metric-box" style="border-top: 4px solid #F97316;">
            <div style="color: #64748B; font-size: 14px;">عمولات المنصة</div>
            <div class="metric-val" style="color: #F97316;">${platformCommission.toFixed(2)} ج.م</div>
          </div>
          <div class="metric-box" style="border-top: 4px solid #FD5001;">
            <div style="color: #64748B; font-size: 14px;">صافي المستحق</div>
            <div class="metric-val" style="color: #FD5001;">${netDues.toFixed(2)} ج.م</div>
          </div>
        </div>

        <h3 style="color: #0F1E36; margin-bottom: 12px;">سجل الطلبات والشحنات المنفذة (${items.length} عملية)</h3>
        <table>
          <thead>
            <tr>
              <th>م</th>
              <th>رقم الطلب / الشحنة</th>
              <th>النوع</th>
              <th>الدفع</th>
              <th>قيمة التوصيل</th>
              <th>أرباح الكابتن</th>
              <th>عمولة المنصة</th>
              <th>الصافي</th>
              <th>التاريخ والوقت</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml || '<tr><td colspan="9" style="text-align:center; padding: 20px;">لا توجد طلبات منفذة في هذه الفترة</td></tr>'}
          </tbody>
        </table>

        <div style="margin-top: 30px; text-align: center; color: #94A3B8; font-size: 12px; border-top: 1px solid #E2E8F0; padding-top: 14px;">
          تم استخراج هذا التقرير آلياً عبر نظام GEBLY المالي • التاريخ: ${new Date().toLocaleString('ar-EG')}
        </div>
      </div>
      <script>
        window.onload = function() {
          if (window.location.search.includes('print=true')) {
            window.print();
          }
        };
      </script>
    </body>
    </html>
    `;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(htmlContent);
  } catch (error) {
    next(error);
  }
};

// ─── GET /api/wallet/dues ─────────────────────────────────────────────────────
const getCaptainDues = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    // 1. Calculate platform dues from unsettled orders & shipments
    const [orders] = await pool.query(
      `SELECT deliveryFee, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip
       FROM orders
       WHERE captainId = ? AND (
         status IN ('Completed', 'منتهي', 'تم التنفيذ', 'Delivered', 'completed', 'delivered', 'تم التوصيل', 'تم التسليم', 'مكتمل')
         OR storeOrderStatus = 'COMPLETED'
         OR captainTripStatus = 'DELIVERED_SUCCESSFULLY'
       ) AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)`,
      [userId]
    );

    const [shipments] = await pool.query(
      `SELECT price, platformShare, captainShare, paymentMethod, COALESCE(serviceFee, 0) as serviceFee, COALESCE(tip, 0) as tip
       FROM shipments
       WHERE captainId = ? AND status IN ('منتهية', 'Completed', 'تم التنفيذ', 'delivered', 'Delivered', 'completed', 'تم التوصيل', 'تم التسليم', 'مكتمل')
       AND (isCaptainSettled = 0 OR isCaptainSettled IS NULL)`,
      [userId]
    );

    let platformDues = 0;
    let captainDues = 0;

    const isOnline = (method) => {
      if (!method) return false;
      const m = String(method).trim().toLowerCase();
      return ['online', 'kashier', 'card', 'wallet', 'محفظة', 'فيزا'].includes(m);
    };

    const resolveShares = (fee, rawPlat, rawCap) => {
      const totalFee = parseFloat(fee || 0);
      if (rawPlat != null && rawCap != null && parseFloat(rawCap) > 0) {
        return { platShare: parseFloat(rawPlat), capShare: parseFloat(rawCap) };
      }
      const defaultPlat = Math.round(totalFee * 0.20 * 100) / 100;
      return { platShare: defaultPlat, capShare: Math.max(0, totalFee - defaultPlat) };
    };

    for (const ord of orders) {
      const fee = parseFloat(ord.deliveryFee || 0);
      const serviceFee = parseFloat(ord.serviceFee || 0);
      const tip = parseFloat(ord.tip || 0);
      const { platShare, capShare } = resolveShares(fee, ord.platformShare, ord.captainShare);

      if (isOnline(ord.paymentMethod)) {
        captainDues += capShare;
      } else {
        platformDues += (platShare + serviceFee + tip);
      }
    }

    for (const shp of shipments) {
      const price = parseFloat(shp.price || 0);
      const serviceFee = parseFloat(shp.serviceFee || 0);
      const tip = parseFloat(shp.tip || 0);
      const { platShare, capShare } = resolveShares(price, shp.platformShare, shp.captainShare);

      if (isOnline(shp.paymentMethod)) {
        captainDues += capShare;
      } else {
        platformDues += (platShare + serviceFee + tip);
      }
    }

    platformDues = Math.round(platformDues * 100) / 100;
    captainDues = Math.round(captainDues * 100) / 100;
    const netDues = Math.max(0, Math.round((platformDues - captainDues) * 100) / 100);

    // 2. Fetch last settlement
    let lastSettlement = null;
    let settlementsHistory = [];
    try {
      const [settlements] = await pool.query(
        `SELECT id, settlementNumber, settledAmount, netBalance, settlementType, settlementDate, createdAt, notes
         FROM captain_settlements
         WHERE captainId = ?
         ORDER BY createdAt DESC
         LIMIT 20`,
        [userId]
      );

      if (settlements.length > 0) {
        const ls = settlements[0];
        const lsDate = new Date(ls.settlementDate || ls.createdAt);
        lastSettlement = {
          id: ls.id.toString(),
          settlementNumber: ls.settlementNumber,
          settledAmount: parseFloat(ls.settledAmount || 0),
          netBalance: parseFloat(ls.netBalance || 0),
          date: `${lsDate.getDate()} ${ARABIC_MONTHS[lsDate.getMonth()]} ${lsDate.getFullYear()}`,
          formattedAmount: `تم تحصيل ${parseFloat(ls.settledAmount || 0).toFixed(0)} ج.م`,
          notes: ls.notes || '',
        };

        settlementsHistory = settlements.map(s => {
          const sd = new Date(s.settlementDate || s.createdAt);
          return {
            id: s.id.toString(),
            settlementNumber: s.settlementNumber,
            settledAmount: parseFloat(s.settledAmount || 0),
            date: `${sd.getDate()} ${ARABIC_MONTHS[sd.getMonth()]} ${sd.getFullYear()}`,
            formattedAmount: `تم تحصيل ${parseFloat(s.settledAmount || 0).toFixed(0)} ج.م`,
            notes: s.notes || '',
          };
        });
      }
    } catch (errSet) {
      console.error('Error fetching settlements for dues:', errSet);
    }

    const remainingDues = netDues;

    res.status(200).json({
      status: 1,
      data: {
        platform_dues: netDues,
        remaining_dues: remainingDues,
        last_settlement: lastSettlement,
        settlements_history: settlementsHistory,
      },
    });
  } catch (error) {
    next(error);
  }
};

const createDepositSession = async (req, res, next) => {
  try {
    const { amount } = req.body;
    const userId = req.user.id;

    if (!amount || isNaN(amount) || parseFloat(amount) < 1) {
      return res.status(400).json({ status: 0, message: 'المبلغ غير صالح. الحد الأدنى هو 1 جنيه' });
    }

    const pool = getPool();
    const [users] = await pool.query(
      'SELECT email, firstName, lastName, phone FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];
    const orderId = `wallet_${userId}_${Date.now()}`;
    const amountStr = parseFloat(amount).toFixed(2);

    // Backend URL for webhook (update when deployed to production)
    const serverBaseUrl = process.env.SERVER_URL || `http://localhost:${process.env.PORT || 5000}`;
    const webhookUrl = `${serverBaseUrl}/api/wallet/kashier-webhook`;

    // Kashier rejects local hosts/IPs with ports for redirect URLs.
    // If serverBaseUrl contains localhost, 127.0.0.1, or a raw IP, use a valid dummy domain that the Flutter app intercepts.
    const urlObj = new URL(serverBaseUrl);
    const isLocal = urlObj.hostname === 'localhost' || 
                    urlObj.hostname === '127.0.0.1' || 
                    /^[0-9.]+$/.test(urlObj.hostname);
    const redirectUrl = isLocal 
      ? 'https://we-deliver-payment.com/callback'
      : `${serverBaseUrl}/api/wallet/payment-callback`;

    // Create payment session at Kashier
    const sessionPayload = {
      merchantId: KASHIER_MERCHANT_ID,
      amount: amountStr,
      currency: 'EGP',
      order: orderId,
      paymentType: 'credit',
      type: 'one-time',
      allowedMethods: 'card,wallet',
      display: 'ar',
      description: `شحن محفظة - ${user.firstName || ''} ${user.lastName || ''}`.trim(),
      customer: {
        email: user.email || `user${userId}@bnwasal.com`,
        reference: userId.toString(),
      },
      serverWebhook: webhookUrl,
      merchantRedirect: redirectUrl,
      failureRedirect: false,
      enable3DS: true,
      metaData: {
        userId: userId.toString(),
        depositAmount: amountStr,
      },
    };

    const response = await kashierRequest('POST', '/v3/payment/sessions', sessionPayload);

    if (response.status !== 200 && response.status !== 201) {
      console.error('❌ Kashier session creation failed:', response.body);
      return res.status(502).json({
        status: 0,
        message: 'فشل في إنشاء جلسة الدفع مع كاشير. حاول مرة أخرى.',
        detail: response.body,
      });
    }

    const sessionData = response.body;
    const sessionUrl = sessionData.sessionUrl;
    const sessionId = sessionData._id;

    if (!sessionUrl) {
      return res.status(502).json({ status: 0, message: 'لم يتم الحصول على رابط الدفع من كاشير' });
    }

    // Auto-expire stale pending deposit sessions older than 1 hour
    await pool.query(
      `UPDATE wallet_transactions 
       SET status = 'failed' 
       WHERE userId = ? AND type = 'deposit' AND status = 'pending' 
         AND createdAt < DATE_SUB(NOW(), INTERVAL 1 HOUR)`,
      [userId]
    );

    // Store pending deposit record
    await pool.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference)
       VALUES (?, ?, ?, 'deposit', 'pending', ?)`,
      [userId, `إيداع رصيد بالمحفظة - ${amountStr} جنيه`, amountStr, sessionId]
    );

    // Notify admins about the pending deposit session
    try {
      const userName = `${user.firstName} ${user.lastName}`;
      const { notifyAdmins } = require('../utils/adminNotifier');
      const io = global.io || null;
      await notifyAdmins(
        io,
        'عملية إيداع معلقة 💳',
        `بدأ العميل ${userName} عملية إيداع بقيمة ${amountStr} جنيه وهي في انتظار الدفع.`,
        'wallet',
        {
          sessionId,
          userId: userId.toString(),
          amount: amountStr
        }
      );
    } catch (e) {
      console.error('Error sending pending deposit admin notification:', e);
    }

    res.status(200).json({
      status: 1,
      data: {
        sessionUrl,
        sessionId,
        orderId,
        amount: amountStr,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── POST /api/wallet/kashier-webhook (called by Kashier server) ──────────────
const kashierWebhook = async (req, res, next) => {
  try {
    if (!verifyKashierWebhook(req)) {
      console.warn('⛔ Kashier webhook rejected: invalid or missing signature');
      return res.status(401).json({ received: false, message: 'Invalid webhook signature' });
    }

    const pool = getPool();
    const payload = req.body;

    console.log('💳 Kashier Webhook received:', JSON.stringify(payload, null, 2));

    // Extract payment status & session id
    const status = payload?.status || payload?.data?.status;
    const sessionId = payload?._id || payload?.data?.sessionId || payload?.sessionId;

    const statusUpper = status ? status.toUpperCase() : null;
    // Only process successful payments
    if (!statusUpper || (statusUpper !== 'SUCCESS' && statusUpper !== 'PAID')) {
      console.log(`ℹ️ Kashier webhook status: ${status} — skipping`);
      if (sessionId) {
        const [failedTx] = await pool.query(
          `SELECT userId, amount FROM wallet_transactions WHERE reference = ? AND status = 'pending'`,
          [sessionId]
        );
        await pool.query(
          `UPDATE wallet_transactions SET status = 'failed' WHERE reference = ? AND status = 'pending'`,
          [sessionId]
        );

        try {
          if (failedTx.length > 0) {
            const failUserId = failedTx[0].userId;
            const failAmount = parseFloat(failedTx[0].amount);
            const [userRows] = await pool.query(
              'SELECT firstName, lastName FROM users WHERE id = ?',
              [failUserId]
            );
            const userName = userRows.length > 0 ? `${userRows[0].firstName} ${userRows[0].lastName}` : `مستخدم رقم ${failUserId}`;
            const { notifyAdmins } = require('../utils/adminNotifier');
            const io = global.io || null;
            await notifyAdmins(
              io,
              'فشل عملية إيداع ❌',
              `فشلت عملية إيداع بقيمة ${failAmount} جنيه للعميل ${userName} (حالة الدفع: ${status}).`,
              'wallet',
              {
                sessionId,
                userId: failUserId.toString(),
                amount: failAmount.toString(),
              }
            );
          }
        } catch (e) {
          console.error('Error sending failed deposit notification to admin:', e);
        }
      }
      return res.status(200).json({ received: true });
    }

    const [pendingTx] = await pool.query(
      `SELECT id, userId, amount, status FROM wallet_transactions WHERE reference = ?`,
      [sessionId]
    );

    if (pendingTx.length === 0) {
      console.error('❌ Kashier webhook: no pending transaction for session', sessionId);
      return res.status(200).json({ received: true });
    }

    const userId = pendingTx[0].userId;
    const depositAmount = parseFloat(pendingTx[0].amount);

    if (!userId || !depositAmount || depositAmount <= 0) {
      console.error('❌ Kashier webhook invalid pending transaction:', { userId, depositAmount });
      return res.status(200).json({ received: true });
    }

    const credit = await creditPendingDeposit(sessionId, userId);
    if (!credit.ok) {
      console.error('❌ Kashier webhook credit failed:', credit.reason, sessionId);
      return res.status(200).json({ received: true });
    }
    if (!credit.alreadyProcessed) {
      await notifyDepositSuccess(pool, userId, credit.amount, sessionId);
    } else {
      console.log(`ℹ️ Kashier webhook: session ${sessionId} already processed`);
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('❌ Kashier webhook error:', error);
    // Always return 200 to Kashier so it doesn't retry
    res.status(200).json({ received: true });
  }
};

// ─── GET /api/wallet/payment-callback (redirect after payment) ────────────────
const paymentCallback = async (req, res) => {
  // This page is shown in the WebView after payment
  const { status } = req.query;
  const isSuccess = status === 'SUCCESS' || status === 'success';

  res.send(`
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${isSuccess ? 'تم الدفع بنجاح' : 'فشل الدفع'}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Cairo', 'Segoe UI', sans-serif; }
    body { display: flex; align-items: center; justify-content: center; min-height: 100vh;
           background: ${isSuccess ? '#f0fdf4' : '#fef2f2'}; padding: 20px; }
    .card { background: white; border-radius: 20px; padding: 40px 30px; text-align: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.08); max-width: 400px; width: 100%; }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { font-size: 22px; font-weight: 800; color: ${isSuccess ? '#16a34a' : '#dc2626'};
         margin-bottom: 10px; }
    p { color: #6b7280; font-size: 14px; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">${isSuccess ? '✅' : '❌'}</div>
    <h1>${isSuccess ? 'تم الدفع بنجاح!' : 'فشل الدفع'}</h1>
    <p>${isSuccess
      ? 'تمت عملية الإيداع بنجاح. سيتم تحديث رصيد محفظتك خلال لحظات.'
      : 'حدث خطأ أثناء عملية الدفع. يرجى المحاولة مرة أخرى.'
    }</p>
  </div>
</body>
</html>
  `);
};

// ─── POST /api/wallet/check-session ───────────────────────────────────────────
// Flutter calls this after WebView closes to check if payment succeeded
const checkDepositSession = async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.id;

    if (!sessionId) {
      return res.status(400).json({ status: 0, message: 'sessionId مطلوب' });
    }

    const pool = getPool();

    // Check transaction status in our DB
    const [tx] = await pool.query(
      `SELECT status, amount FROM wallet_transactions WHERE reference = ? AND userId = ?`,
      [sessionId, userId]
    );

    if (tx.length === 0) {
      return res.status(404).json({ status: 0, message: 'الجلسة غير موجودة' });
    }

    const txStatus = tx[0].status;

    // If still pending, ask Kashier directly
    if (txStatus === 'pending') {
      try {
        const response = await kashierRequest('GET', `/v3/payment/sessions/${sessionId}/payment`);
        const kashierStatus = response.body?.data?.status?.toUpperCase();
        if (response.status === 200 && (kashierStatus === 'SUCCESS' || kashierStatus === 'PAID')) {
          const credit = await creditPendingDeposit(sessionId, userId);
          if (credit.ok && !credit.alreadyProcessed) {
            await notifyDepositSuccess(pool, userId, credit.amount, sessionId);
          }
          if (credit.ok) {
            const [userRows] = await pool.query(
              'SELECT walletBalance FROM users WHERE id = ?',
              [userId]
            );
            const updatedBalance =
              userRows.length > 0 ? parseFloat(userRows[0].walletBalance) : 0;
            return res.status(200).json({
              status: 1,
              paymentStatus: 'success',
              newBalance: updatedBalance,
              depositedAmount: credit.amount,
              message: `تم إضافة ${credit.amount} جنيه لمحفظتك بنجاح`,
            });
          }
        }
      } catch (e) {
        console.error('Error checking Kashier session:', e);
      }
    }

    // Get updated balance
    const [userRows] = await pool.query(
      'SELECT walletBalance FROM users WHERE id = ?',
      [userId]
    );
    const newBalance = userRows.length > 0 ? parseFloat(userRows[0].walletBalance) : 0;

    res.status(200).json({
      status: 1,
      paymentStatus: txStatus,
      newBalance,
      depositedAmount: parseFloat(tx[0].amount || 0),
    });
  } catch (error) {
    next(error);
  }
};

// ─── POST /api/wallet/direct-deposit (إيداع مباشر عبر انستاباي أو المحافظ الإلكترونية) ──
const submitDirectDeposit = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const { amount, paymentMethod, fromPhone, fromName } = req.body;

    const parsedAmount = parseFloat(amount);
    if (!parsedAmount || isNaN(parsedAmount) || parsedAmount < 1) {
      return res.status(400).json({ status: 0, message: 'المبلغ غير صالح. الحد الأدنى للإيداع 1 جنيه' });
    }
    if (!paymentMethod || !fromPhone || !fromName) {
      return res.status(400).json({ status: 0, message: 'جميع بيانات التحويل مطلوبة (طريقة الدفع، اسم ورقم المحوّل)' });
    }
    if (!req.file) {
      return res.status(400).json({ status: 0, message: 'صورة إيصال التحويل مطلوبة' });
    }

    const paymentRef = `DEP-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`;
    const receiptImage = req.file.filename;

    // 1. Insert into direct_payments
    await pool.query(
      `INSERT INTO direct_payments (paymentRef, merchantId, clientId, amount, paymentMethod, fromPhone, fromName, receiptImage, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [paymentRef, userId, userId, parsedAmount, paymentMethod, fromPhone.trim(), fromName.trim(), receiptImage]
    );

    // 2. Insert into wallet_transactions as pending deposit
    await pool.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference, category, paymentMethod, accountDetails)
       VALUES (?, ?, ?, 'deposit', 'pending', ?, 'deposits', ?, ?)`,
      [
        userId,
        `طلب إيداع عبر ${paymentMethod}`,
        parsedAmount,
        paymentRef,
        paymentMethod,
        JSON.stringify({ fromPhone: fromPhone.trim(), fromName: fromName.trim(), receiptImage })
      ]
    );

    // 3. Notify admins
    const io = global.io;
    try {
      const [uRows] = await pool.query('SELECT firstName, lastName, role, phone FROM users WHERE id = ?', [userId]);
      const u = uRows[0] || {};
      const userName = `${u.firstName || ''} ${u.lastName || ''}`.trim() || `مستخدم #${userId}`;
      const roleText = u.role === 'captain' ? 'الكابتن' : (u.role === 'merchant' ? 'التاجر' : 'العميل');

      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        '💳 طلب إيداع رصيد جديد',
        `قام ${roleText} ${userName} بطلب إيداع ${parsedAmount} ج.م عبر ${paymentMethod}. الإيصال بانتظار المراجعة.`,
        'wallet',
        {
          type: 'wallet_deposit_request',
          userId: userId.toString(),
          amount: parsedAmount.toString(),
          paymentRef,
          paymentMethod
        }
      );
    } catch (err) {
      console.error('Error notifying admins of direct deposit:', err);
    }

    res.status(201).json({
      status: 1,
      message: 'تم إرسال طلب الإيداع بنجاح! سيتم مراجعة الإيصال وشحن محفظتك فوراً.',
      data: { paymentRef, amount: parsedAmount }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getWalletData,
  getTransactions,
  getAccountStatement,
  exportAccountStatement,
  getCaptainDues,
  createDepositSession,
  kashierWebhook,
  paymentCallback,
  checkDepositSession,
  withdraw,
  submitDirectDeposit,
};
