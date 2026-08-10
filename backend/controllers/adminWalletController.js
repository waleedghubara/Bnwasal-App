const { getPool } = require('../config/db');

// GET /api/admin/wallet/transactions
const getTransactions = async (req, res, next) => {
  try {
    const pool = getPool();
    const type = req.query.type; // 'deposit' or 'withdraw' (optional)
    const status = req.query.status; // 'success', 'pending', 'failed' (optional)
    const search = req.query.search; // search term (optional)
    const userId = req.query.userId; // user ID (optional)
    
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    let query = `
      FROM wallet_transactions wt
      JOIN users u ON wt.userId = u.id
    `;
    const params = [];
    const conditions = [];

    if (type) {
      conditions.push('wt.type = ?');
      params.push(type);
    }

    if (userId) {
      conditions.push('wt.userId = ?');
      params.push(userId);
    }

    if (status) {
      conditions.push('wt.status = ?');
      params.push(status);
    }

    if (search) {
      conditions.push('(u.firstName LIKE ? OR u.lastName LIKE ? OR u.email LIKE ? OR u.phone LIKE ? OR u.storeName LIKE ? OR wt.title LIKE ? OR wt.reference LIKE ?)');
      const searchWildcard = `%${search}%`;
      params.push(searchWildcard, searchWildcard, searchWildcard, searchWildcard, searchWildcard, searchWildcard, searchWildcard);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    // Get total count
    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) as total ' + query,
      params
    );

    // Get records
    const selectQuery = `
      SELECT wt.id, wt.userId, wt.title, wt.amount, wt.type, wt.status, wt.reference, wt.paymentMethod, wt.accountDetails, wt.createdAt,
             u.firstName, u.lastName, u.email, u.phone, u.role, u.storeName, u.walletBalance
      ${query}
      ORDER BY wt.createdAt DESC
      LIMIT ? OFFSET ?
    `;

    const [rows] = await pool.query(selectQuery, [...params, limit, offset]);

    res.status(200).json({
      status: 1,
      data: {
        transactions: rows.map(r => ({
          id: r.id.toString(),
          userId: r.userId.toString(),
          title: r.title,
          amount: parseFloat(r.amount),
          type: r.type,
          status: r.status,
          reference: r.reference || '',
          paymentMethod: r.paymentMethod || '',
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
            walletBalance: parseFloat(r.walletBalance)
          }
        })),
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/admin/wallet/users
const getWalletUsers = async (req, res, next) => {
  try {
    const pool = getPool();
    const search = req.query.search;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    let query = "FROM users WHERE role IN ('merchant', 'captain') AND walletBalance > 0";
    const params = [];

    if (search) {
      query += " AND (firstName LIKE ? OR lastName LIKE ? OR email LIKE ? OR phone LIKE ? OR storeName LIKE ?)";
      const searchWildcard = `%${search}%`;
      params.push(searchWildcard, searchWildcard, searchWildcard, searchWildcard, searchWildcard);
    }

    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) as total ' + query,
      params
    );

    const selectQuery = `
      SELECT id, firstName, lastName, email, phone, role, storeName, walletBalance, profileImage, createdAt
      ${query}
      ORDER BY walletBalance DESC, firstName ASC
      LIMIT ? OFFSET ?
    `;

    const [rows] = await pool.query(selectQuery, [...params, limit, offset]);

    res.status(200).json({
      status: 1,
      data: {
        users: rows.map(r => ({
          id: r.id.toString(),
          name: `${r.firstName} ${r.lastName}`,
          storeName: r.storeName || '',
          email: r.email,
          phone: r.phone,
          role: r.role,
          walletBalance: parseFloat(r.walletBalance),
          profileImage: r.profileImage || '',
          createdAt: r.createdAt.toISOString()
        })),
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/admin/wallet/summary
const getWalletSummary = async (req, res, next) => {
  try {
    const pool = getPool();

    // Sum of successful top-ups (excluding delivery fees)
    const [[{ totalDeposits }]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as totalDeposits FROM wallet_transactions WHERE type = 'deposit' AND status = 'success' AND title NOT LIKE '%رسوم%' AND title NOT LIKE '%توصيل%' AND title NOT LIKE '%طلب%' AND title NOT LIKE '%شحنة%'"
    );

    // Sum of successful delivery fee payments
    const [[{ totalDeliveryFees }]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as totalDeliveryFees FROM wallet_transactions WHERE type = 'withdraw' AND (title LIKE '%رسوم%' OR title LIKE '%توصيل%' OR title LIKE '%دفع%') AND status = 'success'"
    );

    // Sum of successful withdrawals (real payouts)
    const [[{ totalWithdrawals }]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as totalWithdrawals FROM wallet_transactions WHERE type = 'withdraw' AND paymentMethod IN ('wallet', 'bank') AND status = 'success'"
    );

    // Sum of pending withdrawals
    const [[{ pendingWithdrawals }]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as pendingWithdrawals FROM wallet_transactions WHERE type = 'withdraw' AND paymentMethod IN ('wallet', 'bank') AND status = 'pending'"
    );

    // Sum of all user balances
    const [[{ totalUserBalances }]] = await pool.query(
      "SELECT COALESCE(SUM(walletBalance), 0) as totalUserBalances FROM users WHERE role IN ('merchant', 'captain')"
    );

    res.status(200).json({
      status: 1,
      data: {
        totalDeposits: parseFloat(totalDeposits),
        totalDeliveryFees: parseFloat(totalDeliveryFees),
        totalWithdrawals: parseFloat(totalWithdrawals),
        pendingWithdrawals: parseFloat(pendingWithdrawals),
        totalUserBalances: parseFloat(totalUserBalances)
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTransactions,
  getWalletUsers,
  getWalletSummary
};
