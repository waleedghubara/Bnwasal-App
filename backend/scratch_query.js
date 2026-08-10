const { getPool, initializeDatabase } = require('./config/db');
require('dotenv').config();

async function run() {
  const init = await initializeDatabase();
  if (!init.success) { console.error('DB init failed:', init.error); process.exit(1); }
  const pool = getPool();

  // توزيع الشحنات حسب status و isPaid
  const [s1] = await pool.query(`
    SELECT status, isPaid, COUNT(*) as cnt, SUM(platformShare) as tot
    FROM shipments GROUP BY status, isPaid ORDER BY cnt DESC
  `);
  console.log('\n--- SHIPMENTS by status + isPaid ---');
  s1.forEach(x => console.log(`  status="${x.status}" isPaid=${x.isPaid} cnt=${x.cnt} platformShare=${x.tot}`));

  // مجموع platformShare لكل الشحنات
  const [s2] = await pool.query(`SELECT SUM(platformShare) as total FROM shipments`);
  console.log('\nAll shipments platformShare SUM:', s2[0].total);

  // مجموع platformShare للشحنات المدفوعة فقط
  const [s3] = await pool.query(`SELECT SUM(platformShare) as total FROM shipments WHERE isPaid=1`);
  console.log('isPaid=1 platformShare SUM:', s3[0].total);

  // مجموع platformShare للشحنات المكتملة
  const [s4] = await pool.query(`
    SELECT SUM(platformShare) as total FROM shipments
    WHERE status IN ('Completed','Delivered','completed','delivered')
  `);
  console.log('status=completed platformShare SUM:', s4[0].total);

  // نفس الشيء للطلبات
  const [o1] = await pool.query(`
    SELECT status, isPaid, COUNT(*) as cnt, SUM(platformShare) as tot
    FROM orders GROUP BY status, isPaid ORDER BY cnt DESC
  `);
  console.log('\n--- ORDERS by status + isPaid ---');
  o1.forEach(x => console.log(`  status="${x.status}" isPaid=${x.isPaid} cnt=${x.cnt} platformShare=${x.tot}`));

  const [o2] = await pool.query(`SELECT SUM(platformShare) as total FROM orders WHERE isPaid=1`);
  console.log('\nOrders isPaid=1 platformShare SUM:', o2[0].total);

  process.exit(0);
}
run().catch(e => { console.error(e.message); process.exit(1); });
