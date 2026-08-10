const { getPool } = require('../config/db');
const https = require('https');
const { verifyKashierWebhook } = require('../utils/kashierWebhook');
const { creditPendingDeposit } = require('../utils/walletDeposit');

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

    // 1. Calculate from completed orders
    const [[ordersData]] = await pool.query(
      `SELECT 
        COALESCE(SUM(captainShare), COALESCE(SUM(deliveryFee), 0) * 0.8) as captShare,
        COALESCE(SUM(platformShare), COALESCE(SUM(deliveryFee), 0) * 0.2) as platShare
       FROM orders 
       WHERE captainId = ? AND (status = 'Completed' OR status = 'delivered' OR status = 'منتهية')`,
      [userId]
    );

    // 2. Calculate from completed shipments
    const [[shipmentsData]] = await pool.query(
      `SELECT 
        COALESCE(SUM(captainShare), COALESCE(SUM(price), 0) * 0.8) as captShare,
        COALESCE(SUM(platformShare), COALESCE(SUM(price), 0) * 0.2) as platShare
       FROM shipments 
       WHERE captainId = ? AND (status = 'تم التسليم' OR status = 'delivered' OR status = 'Completed')`,
      [userId]
    );

    let captainEarnings = parseFloat(ordersData?.captShare || 0) + parseFloat(shipmentsData?.captShare || 0);
    let duePlatformFees = parseFloat(ordersData?.platShare || 0) + parseFloat(shipmentsData?.platShare || 0);

    // Fallback: If no order records yet but user has a wallet balance (e.g. 520 EGP), apply 80% captain / 20% platform rule
    if (captainEarnings === 0 && duePlatformFees === 0 && currentBalance > 0) {
      captainEarnings = Math.round(currentBalance * 0.80 * 100) / 100;
      duePlatformFees = Math.round(currentBalance * 0.20 * 100) / 100;
    }

    const totalBalance = currentBalance > 0 ? currentBalance : (captainEarnings + duePlatformFees);
    const availableBalance = Math.max(0, currentBalance - duePlatformFees);

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
        pending_balance: pendingWithdrawal ? pendingWithdrawal.amount : 0,
        pendingWithdrawal,
        recent_transactions: transactions.map(tx => {
          let category = 'other';
          const t = tx.title || '';
          if (t.includes('طلب') || t.includes('شحنة') || t.includes('توصيل')) {
            category = 'orders';
          } else if (t.includes('منصة') || t.includes('عمولة')) {
            category = 'platform_fees';
          } else if (tx.type === 'withdraw') {
            category = 'withdrawals';
          } else if (t.includes('شحن') || t.includes('إيداع') || tx.type === 'deposit') {
            category = 'deposits';
          }

          return {
            id: tx.id.toString(),
            title: tx.title,
            amount: parseFloat(tx.amount),
            type: tx.type,
            category: category,
            status: tx.status,
            reference: tx.reference || `#TXN${12588 + parseInt(tx.id)}`,
            date: new Date(tx.date).toLocaleString('ar-EG', {
              hour: '2-digit',
              minute: '2-digit',
              day: '2-digit',
              month: '2-digit',
              year: 'numeric',
            }),
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
    const { amount, paymentMethod, name, phone, walletProvider, bankName, bankAccountNumber } = req.body;
    const userId = req.user.id;

    if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
      return res.status(400).json({ status: 0, message: 'المبلغ غير صالح' });
    }

    if (!paymentMethod || (paymentMethod !== 'wallet' && paymentMethod !== 'bank')) {
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

    if (paymentMethod === 'wallet') {
      if (!phone || !name || !walletProvider) {
        return res.status(400).json({ status: 0, message: 'جميع بيانات المحفظة مطلوبة' });
      }
      accountDetailsObj = { phone, name, walletProvider };
      title = `طلب سحب للمحفظة (${walletProvider}) - ${phone}`;
    } else {
      if (!bankName || !bankAccountNumber || !name) {
        return res.status(400).json({ status: 0, message: 'جميع بيانات الحساب البنكي مطلوبة' });
      }
      accountDetailsObj = { bankName, bankAccountNumber, name };
      title = `طلب سحب للحساب البنكي (${bankName}) - ${bankAccountNumber}`;
    }

    const accountDetailsStr = JSON.stringify(accountDetailsObj);

    // Deduct balance and insert transaction
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Deduct immediately
      await conn.query(
        'UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?',
        [amountVal, userId]
      );

      // Create pending transaction record
      const [result] = await conn.query(
        `INSERT INTO wallet_transactions (userId, title, amount, type, status, paymentMethod, accountDetails)
         VALUES (?, ?, ?, 'withdraw', 'pending', ?, ?)`,
        [userId, title, amountVal, paymentMethod, accountDetailsStr]
      );

      await conn.commit();

      // Emit socket event to admins room
      const io = global.io || null;
      if (io) {
        io.to('admins').emit('new_withdrawal_request', {
          transactionId: result.insertId,
          userId,
          amount: amountVal,
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
const getTransactions = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
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
          status: tx.status,
          date: new Date(tx.date).toLocaleString('ar-EG', {
            hour: '2-digit',
            minute: '2-digit',
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
          }),
        })),
        total,
        page,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── POST /api/wallet/create-deposit-session ──────────────────────────────────
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

module.exports = {
  getWalletData,
  getTransactions,
  createDepositSession,
  kashierWebhook,
  paymentCallback,
  checkDepositSession,
  withdraw,
};
