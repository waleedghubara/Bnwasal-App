const mysql = require('mysql2/promise');
require('dotenv').config({ path: 'e:/We deliver/backend/.env' });

async function check() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'we_deliver_db'
  });

  try {
    const [users] = await connection.query(
      `SELECT id, firstName, lastName, role, status, nationalId, nationalIdFront, nationalIdBack FROM users`
    );
    console.log('--- USERS IN DB ---');
    console.log(JSON.stringify(users, null, 2));

    const [driverDocs] = await connection.query(
      `SELECT * FROM driver_documents`
    );
    console.log('--- DRIVER DOCUMENTS IN DB ---');
    console.log(JSON.stringify(driverDocs, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await connection.end();
  }
}

check();
