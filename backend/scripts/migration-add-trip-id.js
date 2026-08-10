require('dotenv').config();
const mysql = require('mysql2/promise');

async function runMigration() {
  const pool = await mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
  });

  const dbName = process.env.DB_NAME;

  console.log('🔄 Running migration: add trip_id to orders and shipments...');

  try {
    // ── orders.trip_id ──
    let [rows] = await pool.query(
      `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'orders' AND COLUMN_NAME = 'trip_id'`,
      [dbName]
    );
    if (rows[0].cnt > 0) {
      console.log('ℹ️  Column trip_id already exists in orders — skipping.');
    } else {
      await pool.query('ALTER TABLE orders ADD COLUMN trip_id INT NULL AFTER captainId');
      console.log('✅ Added trip_id to orders.');
    }

    // ── shipments.trip_id ──
    [rows] = await pool.query(
      `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'shipments' AND COLUMN_NAME = 'trip_id'`,
      [dbName]
    );
    if (rows[0].cnt > 0) {
      console.log('ℹ️  Column trip_id already exists in shipments — skipping.');
    } else {
      await pool.query('ALTER TABLE shipments ADD COLUMN trip_id INT NULL AFTER captainId');
      console.log('✅ Added trip_id to shipments.');
    }
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
  }

  await pool.end();
  process.exit(0);
}

runMigration();
