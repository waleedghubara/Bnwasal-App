/**
 * Public stats endpoint for the landing website.
 * Returns aggregate counts that are displayed on the homepage.
 *
 * Security: protected by X-API-Key header via validateApiKey middleware.
 */
const { getPool } = require('../config/db');

const getPublicStats = async (req, res, next) => {
  try {
    const pool = getPool();

    const [rows] = await pool.query(`
      SELECT
        ( SELECT COUNT(*)
          FROM   orders
          WHERE  status IN ('Completed', 'Delivered', '\u062a\u0645 \u0627\u0644\u062a\u0646\u0641\u064a\u0630', '\u0645\u0646\u062a\u0647\u064a')
        ) +
        ( SELECT COUNT(*)
          FROM   shipments
          WHERE  status IN ('Completed', 'Delivered', '\u0645\u0646\u062a\u0647\u064a\u0629')
        ) AS total_completed,

        ( SELECT COUNT(*)
          FROM   users
          WHERE  role = 'captain' AND status = 'active'
        ) AS active_captains,

        ( SELECT COUNT(*)
          FROM   users
          WHERE  role = 'merchant' AND status = 'active'
        ) AS active_merchants
    `);

    const stats = rows[0];

    res.json({
      status: 1,
      data: {
        totalCompleted: (Number(stats.total_completed) || 0) + 10000,
        activeCaptains: (Number(stats.active_captains) || 0) + 500,
        activeMerchants: (Number(stats.active_merchants) || 0) + 2000,
        coveredCitiesCount: 1,
        coveredCities: ['Alexandria'],
        lastUpdated: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getPublicStats };
