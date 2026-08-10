const { getPool } = require('../config/db');
const { createDbNotification, sendPushNotification } = require('./notificationHelper');

/**
 * Checks if the user was referred by someone, and if they have a pending referral,
 * rewards both the referrer (15.00) and the referee (15.00) upon first completion of a shipment or order.
 * @param {number} userId - The user who might be the referred friend (referee)
 */
const checkAndRewardReferral = async (userId) => {
  const pool = getPool();
  try {
    // 1. Find if this user has a pending referral where they are the referee
    const [referrals] = await pool.query(
      'SELECT * FROM referrals WHERE refereeId = ? AND status = ?',
      [userId, 'pending']
    );

    if (referrals.length === 0) {
      return; // No pending referral found for this user
    }

    const referral = referrals[0];
    const referrerId = referral.referrerId;
    const rewardAmount = parseFloat(referral.rewardAmount || 15.00);

    // 2. Update referral status to 'rewarded'
    await pool.query(
      'UPDATE referrals SET status = ? WHERE id = ?',
      ['rewarded', referral.id]
    );

    // 3. Update Referred User's (Referee) wallet balance in users table
    await pool.query(
      'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
      [rewardAmount, userId]
    );

    // 4. Update Referrer's wallet balance in users table
    await pool.query(
      'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
      [rewardAmount, referrerId]
    );

    // 5. Insert transaction log for Referee
    await pool.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status) 
       VALUES (?, ?, ?, 'deposit', 'success')`,
      [userId, `مكافأة ترحيبية للتسجيل عبر كود الدعوة`, rewardAmount]
    );

    // 6. Insert transaction log for Referrer
    const [refereeUser] = await pool.query(
      'SELECT firstName, lastName FROM users WHERE id = ?',
      [userId]
    );
    const refereeName = refereeUser.length > 0 ? `${refereeUser[0].firstName} ${refereeUser[0].lastName}` : 'صديقك';

    await pool.query(
      `INSERT INTO wallet_transactions (userId, title, amount, type, status) 
       VALUES (?, ?, ?, 'deposit', 'success')`,
      [referrerId, `مكافأة دعوة صديقك (${refereeName}) للتسجيل والنشاط`, rewardAmount]
    );

    // 7. Store DB Notification & push notifications for referee
    await createDbNotification(
      userId,
      'مكافأة التسجيل! 🎉',
      `تم إضافة ${rewardAmount} ج.م إلى محفظتك كهدية ترحيبية للتسجيل عبر كود الدعوة وإتمام أول عملية.`,
      'wallet'
    );

    // 8. Store DB Notification & push notifications for referrer
    await createDbNotification(
      referrerId,
      'مكافأة دعوة صديق! 🎉',
      `تم إضافة ${rewardAmount} ج.م إلى محفظتك لنجاح دعوة صديقك ${refereeName} وإتمامه أول عملية.`,
      'wallet'
    );

    // Try to send push notifications in the background
    const [users] = await pool.query(
      'SELECT id, fcmToken FROM users WHERE id IN (?, ?)',
      [userId, referrerId]
    );

    for (const u of users) {
      if (u.fcmToken) {
        const title = u.id === userId ? 'مكافأة التسجيل! 🎉' : 'مكافأة دعوة صديق! 🎉';
        const body = u.id === userId
          ? `تم إضافة ${rewardAmount} ج.م إلى محفظتك كهدية ترحيبية.`
          : `تم إضافة ${rewardAmount} ج.م إلى محفظتك لنجاح دعوة صديقك ${refereeName}.`;
        
        sendPushNotification(u.fcmToken, title, body, {
          type: 'wallet_deposit',
          amount: rewardAmount.toString()
        }).catch(err => console.error('Push Notification Error in Referral Reward:', err));
      }
    }

    console.log(`🎁 Referral reward successfully paid out for referee ${userId} to referrer ${referrerId}`);
  } catch (error) {
    console.error('❌ Error processing referral reward:', error);
  }
};

module.exports = {
  checkAndRewardReferral
};
