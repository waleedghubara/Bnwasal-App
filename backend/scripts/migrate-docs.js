// One-time migration: copy driver_documents data into users.nationalId* columns
const mysql = require('mysql2/promise');
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

(async () => {
  try {
    const conn = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT, 10) || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'we_deliver_db',
    });

    // Add columns if missing (safe to run even if already exist)
    for (const col of [
      'ALTER TABLE users ADD COLUMN nationalId VARCHAR(14) NULL',
      'ALTER TABLE users ADD COLUMN nationalIdFront VARCHAR(255) NULL',
      'ALTER TABLE users ADD COLUMN nationalIdBack VARCHAR(255) NULL',
    ]) {
      try { await conn.query(col); } catch (_) {}
    }

    // Copy data from driver_documents → users
    const [docs] = await conn.query('SELECT * FROM driver_documents');
    let migrated = 0;
    for (const d of docs) {
      await conn.query(
        'UPDATE users SET nationalId = ?, nationalIdFront = ?, nationalIdBack = ? WHERE id = ?',
        [d.nationalId, d.nationalIdFront, d.nationalIdBack, d.userId]
      );
      migrated++;
    }

    console.log(`✅ Migrated ${migrated} document records to users table`);
    conn.end();
  } catch (e) {
    console.error('Migration error:', e.message);
  }
})();
