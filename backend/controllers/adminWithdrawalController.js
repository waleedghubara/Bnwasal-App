const { getPool } = require('../config/db');
const { sendNotification } = require('../utils/notificationDispatcher');

// GET /api/admin/withdrawals
const getWithdrawals = async (req, res, next) => {
  try {
    const pool = getPool();
    const status = req.query.status || 'pending';

    const [rows] = await pool.query(
      `SELECT wt.id, wt.userId, wt.title, wt.amount, wt.status, wt.paymentMethod, wt.accountDetails, wt.createdAt,
              u.firstName, u.lastName, u.email, u.phone, u.role, u.storeName, u.walletBalance, u.profileImage
       FROM wallet_transactions wt
       JOIN users u ON wt.userId = u.id
       WHERE wt.type = 'withdraw' AND wt.paymentMethod IN ('wallet', 'bank') AND wt.status = ?
       ORDER BY wt.createdAt DESC`,
      [status]
    );

    res.status(200).json({
      status: 1,
      data: rows.map(r => ({
        id: r.id.toString(),
        userId: r.userId.toString(),
        title: r.title,
        amount: parseFloat(r.amount),
        status: r.status,
        paymentMethod: r.paymentMethod,
        accountDetails: r.accountDetails ? JSON.parse(r.accountDetails) : {},
        createdAt: r.createdAt.toISOString(),
        date: new Date(r.createdAt).toLocaleString('ar-EG', {
          hour: '2-digit',
          minute: '2-digit',
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
        }),
        user: {
          name: `${r.firstName} ${r.lastName}`,
          storeName: r.storeName || '',
          email: r.email,
          phone: r.phone,
          role: r.role,
          walletBalance: parseFloat(r.walletBalance),
          profileImage: r.profileImage || null
        }
      }))
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/admin/withdrawals/:id/approve
const approveWithdrawal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const pool = getPool();

    // Check if withdrawal exists and is pending
    const [txRows] = await pool.query(
      `SELECT id, userId, amount, status FROM wallet_transactions WHERE id = ? AND type = 'withdraw'`,
      [id]
    );

    if (txRows.length === 0) {
      return res.status(404).json({ status: 0, message: 'طلب السحب غير موجود' });
    }

    const tx = txRows[0];
    if (tx.status !== 'pending') {
      return res.status(400).json({ status: 0, message: `طلب السحب هذا تم معالجته بالفعل وحالته الحالية هي: ${tx.status}` });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Update status to success
      await conn.query(
        `UPDATE wallet_transactions SET status = 'success' WHERE id = ?`,
        [id]
      );

      await conn.commit();

      // Send notification to user
      const io = global.io || null;
      await sendNotification(
        io,
        tx.userId,
        'تمت الموافقة على طلب السحب 💵',
        `تمت الموافقة على طلب السحب بقيمة ${tx.amount} جنيه وتم تحويل المبلغ بنجاح إلى حسابك.`,
        'wallet',
        {
          type: 'withdrawal_approved',
          transactionId: id.toString(),
          amount: tx.amount.toString()
        }
      );

      // Notify other admins
      try {
        const [userRows] = await pool.query(
          'SELECT firstName, lastName FROM users WHERE id = ?',
          [tx.userId]
        );
        const userName = userRows.length > 0 ? `${userRows[0].firstName} ${userRows[0].lastName}` : `مستخدم رقم ${tx.userId}`;
        const { notifyAdmins } = require('../utils/adminNotifier');
        await notifyAdmins(
          io,
          'تم قبول عملية سحب 💵',
          `تمت الموافقة على طلب سحب بقيمة ${tx.amount} جنيه للعميل ${userName}.`,
          'wallet',
          {
            transactionId: id.toString(),
            userId: tx.userId.toString(),
            amount: tx.amount.toString()
          },
          req.user.id
        );
      } catch (err) {
        console.error('Error sending withdrawal approved admin notification:', err);
      }

      // Emit balance update socket event to user
      if (io) {
        const [userRows] = await pool.query('SELECT walletBalance FROM users WHERE id = ?', [tx.userId]);
        const newBalance = userRows.length > 0 ? parseFloat(userRows[0].walletBalance) : 0;
        io.to(`user_${tx.userId}`).emit('wallet_updated', {
          newBalance,
          message: 'تم تحديث رصيد محفظتك بعد إتمام السحب',
        });
      }

      res.status(200).json({
        status: 1,
        message: 'تمت الموافقة على طلب السحب بنجاح'
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

// POST /api/admin/withdrawals/:id/reject
const rejectWithdrawal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const pool = getPool();

    // Check if withdrawal exists and is pending
    const [txRows] = await pool.query(
      `SELECT id, userId, amount, status FROM wallet_transactions WHERE id = ? AND type = 'withdraw'`,
      [id]
    );

    if (txRows.length === 0) {
      return res.status(404).json({ status: 0, message: 'طلب السحب غير موجود' });
    }

    const tx = txRows[0];
    if (tx.status !== 'pending') {
      return res.status(400).json({ status: 0, message: `طلب السحب هذا تم معالجته بالفعل وحالته الحالية هي: ${tx.status}` });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Update status to failed
      await conn.query(
        `UPDATE wallet_transactions SET status = 'failed' WHERE id = ?`,
        [id]
      );

      // Refund the user's wallet
      await conn.query(
        `UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?`,
        [parseFloat(tx.amount), tx.userId]
      );

      await conn.commit();

      // Send notification to user
      const io = global.io || null;
      await sendNotification(
        io,
        tx.userId,
        'تم رفض طلب السحب ❌',
        `تم رفض طلب السحب بقيمة ${tx.amount} جنيه وتم إرجاع المبلغ إلى رصيد محفظتك.`,
        'wallet',
        {
          type: 'withdrawal_rejected',
          transactionId: id.toString(),
          amount: tx.amount.toString()
        }
      );

      // Notify other admins
      try {
        const [userRows] = await pool.query(
          'SELECT firstName, lastName FROM users WHERE id = ?',
          [tx.userId]
        );
        const userName = userRows.length > 0 ? `${userRows[0].firstName} ${userRows[0].lastName}` : `مستخدم رقم ${tx.userId}`;
        const { notifyAdmins } = require('../utils/adminNotifier');
        await notifyAdmins(
          io,
          'تم رفض عملية سحب ❌',
          `تم رفض طلب سحب بقيمة ${tx.amount} جنيه للعميل ${userName} وإرجاع المبلغ لمحفظته.`,
          'wallet',
          {
            transactionId: id.toString(),
            userId: tx.userId.toString(),
            amount: tx.amount.toString()
          },
          req.user.id
        );
      } catch (err) {
        console.error('Error sending withdrawal rejected admin notification:', err);
      }

      // Emit balance update socket event to user
      if (io) {
        const [userRows] = await pool.query('SELECT walletBalance FROM users WHERE id = ?', [tx.userId]);
        const newBalance = userRows.length > 0 ? parseFloat(userRows[0].walletBalance) : 0;
        io.to(`user_${tx.userId}`).emit('wallet_updated', {
          newBalance,
          message: 'تم رفض طلب السحب وإعادة الرصيد لمحفظتك',
        });
      }

      res.status(200).json({
        status: 1,
        message: 'تم رفض طلب السحب بنجاح وإعادة الرصيد للمستخدم'
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

module.exports = {
  getWithdrawals,
  approveWithdrawal,
  rejectWithdrawal
};
