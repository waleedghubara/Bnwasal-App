const { getPool } = require('../config/db');

// Helper to format date in Arabic format (optional, or standard date)
const formatDate = (date) => {
  if (!date) return null;
  const d = new Date(date);
  return d.toISOString();
};

const getReferralSummary = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    // 1. Fetch current user to get or generate their referral code and points
    const [users] = await pool.query(
      'SELECT id, firstName, lastName, referralCode, walletBalance, points FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'المستخدم غير موجود'
      });
    }

    const user = users[0];
    let referralCode = user.referralCode;

    // Fallback: If referralCode is empty, generate it now
    if (!referralCode) {
      const prefixName = user.firstName.toUpperCase().replace(/[^A-Z]/g, '').substring(0, 4) || 'USER';
      referralCode = `WASAL-${prefixName}-${userId}`;
      await pool.query('UPDATE users SET referralCode = ? WHERE id = ?', [referralCode, userId]);
    }

    // 2. Fetch list of users who registered using this user's referral code
    const [referralRows] = await pool.query(
      `SELECT r.id as referralId, r.status, r.rewardAmount, r.createdAt as referralDate,
              u.firstName, u.lastName, u.createdAt as registeredDate
       FROM referrals r
       INNER JOIN users u ON r.refereeId = u.id
       WHERE r.referrerId = ?
       ORDER BY r.createdAt DESC`,
      [userId]
    );

    // 3. Calculate statistics
    let totalRewards = 0.00;
    let successCount = 0;
    let pendingCount = 0;
    const invitedCount = referralRows.length;

    const referralsList = referralRows.map(r => {
      const amt = parseFloat(r.rewardAmount || 15.00);
      const isRewarded = r.status === 'rewarded' || r.status === 'completed';
      
      if (isRewarded) {
        totalRewards += amt;
        successCount += 1;
      } else {
        pendingCount += 1;
      }

      return {
        id: r.referralId.toString(),
        name: `${r.firstName} ${r.lastName}`,
        status: r.status, // 'pending', 'completed', 'rewarded'
        date: formatDate(r.referralDate),
        amount: isRewarded ? amt : 0.00
      };
    });

    res.status(200).json({
      status: 1,
      data: {
        referralCode,
        walletBalance: parseFloat(user.walletBalance || 0.00),
        points: parseInt(user.points || 0, 10),
        statistics: {
          totalRewards: parseFloat(totalRewards.toFixed(2)),
          invitedCount: invitedCount,
          successCount: successCount,
          pendingCount: pendingCount
        },
        referrals: referralsList
      }
    });
  } catch (error) {
    next(error);
  }
};

const convertPoints = async (req, res, next) => {
  const pool = getPool();
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const userId = req.user.id;

    // 1. Fetch user points and walletBalance
    const [users] = await connection.query(
      'SELECT points, walletBalance FROM users WHERE id = ? FOR UPDATE',
      [userId]
    );

    if (users.length === 0) {
      await connection.rollback();
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];
    const points = user.points || 0;

    if (points < 1000) {
      await connection.rollback();
      return res.status(400).json({
        status: 0,
        message: 'يجب أن يكون لديك 1000 نقطة على الأقل للتحويل'
      });
    }

    // 2. Calculate convertable points and equivalent cash amount
    const pointsToConvert = Math.floor(points / 1000) * 1000;
    const cashReward = pointsToConvert * 1.0; // 1 EGP per point

    // 3. Deduct points and add cash to wallet
    await connection.query(
      'UPDATE users SET points = points - ?, walletBalance = walletBalance + ? WHERE id = ?',
      [pointsToConvert, cashReward, userId]
    );

    // 4. Create a transaction log
    await connection.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status) 
       VALUES (?, ?, ?, 'deposit', 'success')`,
      [userId, `تحويل عدد ${pointsToConvert} نقطة دعوة إلى رصيد`, cashReward]
    );

    await connection.commit();

    res.status(200).json({
      status: 1,
      message: `تم تحويل ${pointsToConvert} نقطة بنجاح إلى ${cashReward.toFixed(2)} ج.م رصيد في محفظتك!`,
      data: {
        convertedPoints: pointsToConvert,
        cashReward: cashReward,
        newPoints: points - pointsToConvert,
        newWalletBalance: parseFloat(user.walletBalance || 0.00) + cashReward
      }
    });
  } catch (error) {
    await connection.rollback();
    next(error);
  } finally {
    connection.release();
  }
};

module.exports = {
  getReferralSummary,
  convertPoints
};
