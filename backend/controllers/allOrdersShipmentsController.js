const { getPool } = require('../config/db');

/**
 * GET /api/admin/all-orders-shipments
 * Query params:
 *   page        - page number (default 1)
 *   limit       - items per page (default 30)
 *   search      - search by number, client name, merchant name
 *   status      - filter by status string (exact match)
 *   type        - 'order' | 'shipment' | '' (both)
 *   dateFrom    - YYYY-MM-DD start date filter on createdAt
 *   dateTo      - YYYY-MM-DD end date filter on createdAt
 *   sortBy      - 'newest' (default) | 'oldest'
 */
const getAllOrdersShipments = async (req, res, next) => {
  try {
    const pool = getPool();
    const page     = Math.max(1, parseInt(req.query.page)  || 1);
    const limit    = Math.min(100, parseInt(req.query.limit) || 30);
    const offset   = (page - 1) * limit;
    const search   = (req.query.search   || '').trim();
    const status   = (req.query.status   || '').trim();
    const type     = (req.query.type     || '').trim();   // 'order' | 'shipment' | ''
    const dateFrom = (req.query.dateFrom || '').trim();
    const dateTo   = (req.query.dateTo   || '').trim();
    const sortDir  = req.query.sortBy === 'oldest' ? 'ASC' : 'DESC';

    // ─── Build conditions ─────────────────────────────────────────────────────
    const buildConditions = (tableAlias, numberCol, nameCol, isOrder) => {
      const conds = [];
      const params = [];

      if (search) {
        conds.push(`(${tableAlias}.${numberCol} LIKE ? OR u.storeName LIKE ? OR CONCAT(u.firstName,' ',u.lastName) LIKE ? OR ${tableAlias}.${nameCol} LIKE ?)`);
        const s = `%${search}%`;
        params.push(s, s, s, s);
      }
      if (status) {
        conds.push(`${tableAlias}.status = ?`);
        params.push(status);
      }
      if (dateFrom) {
        conds.push(`DATE(${tableAlias}.createdAt) >= ?`);
        params.push(dateFrom);
      }
      if (dateTo) {
        conds.push(`DATE(${tableAlias}.createdAt) <= ?`);
        params.push(dateTo);
      }

      const where = conds.length ? 'WHERE ' + conds.join(' AND ') : '';
      return { where, params };
    };

    // ─── Orders query ─────────────────────────────────────────────────────────
    let orderRows = [];
    if (!type || type === 'order') {
      const { where: oWhere, params: oParams } = buildConditions('o', 'orderNumber', 'clientName', true);
      const [rows] = await pool.query(`
        SELECT
          'order' AS itemType,
          o.id, o.orderNumber AS number, o.details AS description,
          o.clientName, o.phone, o.deliveryAddress AS address,
          NULL AS fromAddress, NULL AS toAddress,
          NULL AS weight,
          o.orderPrice AS price, o.deliveryFee,
          o.status, o.createdAt,
          COALESCE(u.storeName, CONCAT(u.firstName,' ',u.lastName)) AS merchantName,
          CONCAT(c.firstName,' ',c.lastName) AS captainName,
          o.assignedAdminId,
          CONCAT(a.firstName,' ',a.lastName) AS assignedAdminName
        FROM orders o
        LEFT JOIN users u ON u.id = o.merchantId
        LEFT JOIN users c ON c.id = o.captainId
        LEFT JOIN users a ON a.id = o.assignedAdminId
        ${oWhere}
        ORDER BY o.createdAt ${sortDir}
      `, oParams);
      orderRows = rows;
    }

    // ─── Shipments query ──────────────────────────────────────────────────────
    let shipmentRows = [];
    if (!type || type === 'shipment') {
      const { where: sWhere, params: sParams } = buildConditions('s', 'shipmentNumber', 'title', false);
      const [rows] = await pool.query(`
        SELECT
          'shipment' AS itemType,
          s.id, s.shipmentNumber AS number, s.title AS description,
          NULL AS clientName, NULL AS phone, s.fromAddress AS address,
          s.fromAddress AS fromAddress, s.toAddress AS toAddress,
          s.weight AS weight,
          s.price, NULL AS deliveryFee,
          s.status, s.createdAt,
          COALESCE(u.storeName, CONCAT(u.firstName,' ',u.lastName)) AS merchantName,
          CONCAT(c.firstName,' ',c.lastName) AS captainName,
          s.assignedAdminId,
          CONCAT(a.firstName,' ',a.lastName) AS assignedAdminName
        FROM shipments s
        LEFT JOIN users u ON u.id = s.merchantId
        LEFT JOIN users c ON c.id = s.captainId
        LEFT JOIN users a ON a.id = s.assignedAdminId
        ${sWhere}
        ORDER BY s.createdAt ${sortDir}
      `, sParams);
      shipmentRows = rows;
    }

    // ─── Merge & sort & paginate ──────────────────────────────────────────────
    const all = [...orderRows, ...shipmentRows];
    all.sort((a, b) => {
      const ta = new Date(a.createdAt).getTime();
      const tb = new Date(b.createdAt).getTime();
      return sortDir === 'DESC' ? tb - ta : ta - tb;
    });

    const total = all.length;
    const items = all.slice(offset, offset + limit);

    // ─── Summary stats ────────────────────────────────────────────────────────
    const totalOrders    = orderRows.length;
    const totalShipments = shipmentRows.length;

    res.status(200).json({
      status: 1,
      data: {
        items,
        total,
        totalOrders,
        totalShipments,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getAllOrdersShipments };
