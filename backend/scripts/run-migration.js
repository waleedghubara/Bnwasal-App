/**
 * One-time migration script to add deviceId column to refresh_tokens table.
 * Compatible with MySQL 5.7+ (no IF NOT EXISTS in ALTER TABLE).
 * Run with: node scripts/run-migration.js
 */
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

  console.log('🔄 Running migration: add deviceId to refresh_tokens...');

  try {
    // Check if column already exists (MySQL 5.7 compatible)
    const [rows] = await pool.query(
      `SELECT COUNT(*) as cnt
       FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'refresh_tokens' AND COLUMN_NAME = 'deviceId'`,
      [dbName]
    );

    if (rows[0].cnt > 0) {
      console.log('ℹ️  Column deviceId already exists in refresh_tokens — skipping.');
    } else {
      await pool.query('ALTER TABLE refresh_tokens ADD COLUMN deviceId VARCHAR(255) NULL');
      console.log('✅ Migration succeeded: deviceId column added to refresh_tokens.');
    }
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
  }

  await pool.end();
  process.exit(0);
}

runMigration();
