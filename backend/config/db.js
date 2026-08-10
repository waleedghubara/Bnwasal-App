const mysql = require('mysql2/promise');
const { setupDatabaseSchema } = require('./dbSchema');

const poolConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
};

let pool;

const initializeDatabase = async () => {
  try {
    // 1. Connect without database to create it if it doesn't exist
    const connection = await mysql.createConnection(poolConfig);
    const dbName = process.env.DB_NAME || 'we_deliver_db';
    await connection.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\`;`);
    await connection.end();

    // 2. Create connection pool for the application
    pool = mysql.createPool({
      ...poolConfig,
      database: dbName,
      waitForConnections: true,
      connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT, 10) || 50,
      queueLimit: 0,
      connectTimeout: 10000
    });

    // Test pool connection
    const testConn = await pool.getConnection();
    testConn.release();

    // 3. Setup database tables if they do not exist
    const schemaSetup = await setupDatabaseSchema(pool);
    if (!schemaSetup.success) {
      return { success: false, error: schemaSetup.error };
    }

    return { success: true, dbName };
  } catch (error) {
    return { success: false, error: error.message };
  }
};

module.exports = {
  getPool: () => {
    if (!pool) {
      const error = new Error('Database pool not initialized');
      error.status = 503;
      throw error;
    }
    return pool;
  },
  initializeDatabase
};
