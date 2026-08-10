const { getPool } = require('../config/db');

/**
 * Idempotent wallet credit for a Kashier session (webhook + check-session).
 * Uses row lock to prevent double credit.
 */
async function creditPendingDeposit(sessionId, userId) {
  const pool = getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [rows] = await conn.query(
      `SELECT id, status, amount FROM wallet_transactions
       WHERE reference = ? AND userId = ? FOR UPDATE`,
      [sessionId, userId]
    );

    if (rows.length === 0) {
      await conn.rollback();
      return { ok: false, reason: 'not_found' };
    }

    const row = rows[0];
    if (row.status === 'success') {
      await conn.commit();
      return { ok: true, alreadyProcessed: true, amount: parseFloat(row.amount) };
    }

    const amount = parseFloat(row.amount);
    if (!amount || amount <= 0) {
      await conn.rollback();
      return { ok: false, reason: 'invalid_amount' };
    }

    await conn.query('UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?', [
      amount,
      userId,
    ]);
    await conn.query(`UPDATE wallet_transactions SET status = 'success' WHERE id = ?`, [
      row.id,
    ]);

    await conn.commit();
    return { ok: true, amount, alreadyProcessed: false };
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { creditPendingDeposit };
