const { getPool } = require('../config/db');

/**
 * Inserts a status transition record into order_status_logs table.
 */
async function logStatusChange(poolOrConn, {
  orderId = null,
  shipmentId = null,
  userId = null,
  userName = null,
  userRole = 'system',
  previousStatus = null,
  newStatus,
  latitude = null,
  longitude = null
}) {
  try {
    const conn = poolOrConn || getPool();
    await conn.query(
      `INSERT INTO order_status_logs (
        orderId, shipmentId, userId, userName, userRole, previousStatus, newStatus, latitude, longitude
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderId ? parseInt(orderId, 10) : null,
        shipmentId ? parseInt(shipmentId, 10) : null,
        userId ? parseInt(userId, 10) : null,
        userName || null,
        userRole || 'system',
        previousStatus || null,
        newStatus,
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null
      ]
    );
  } catch (err) {
    console.error('Error logging status change:', err.message);
  }
}

/**
 * Retrieves status transition history logs for an order or shipment.
 */
async function getStatusLogs(pool, { orderId = null, shipmentId = null }) {
  try {
    let query = '';
    let params = [];
    if (orderId) {
      query = `SELECT * FROM order_status_logs WHERE orderId = ? ORDER BY createdAt ASC`;
      params = [parseInt(orderId, 10)];
    } else if (shipmentId) {
      query = `SELECT * FROM order_status_logs WHERE shipmentId = ? ORDER BY createdAt ASC`;
      params = [parseInt(shipmentId, 10)];
    } else {
      return [];
    }

    const [rows] = await pool.query(query, params);
    return rows.map(r => ({
      id: r.id.toString(),
      orderId: r.orderId ? r.orderId.toString() : null,
      shipmentId: r.shipmentId ? r.shipmentId.toString() : null,
      userId: r.userId ? r.userId.toString() : null,
      userName: r.userName || 'النظام',
      userRole: r.userRole || 'system',
      previousStatus: r.previousStatus,
      newStatus: r.newStatus,
      latitude: r.latitude ? parseFloat(r.latitude) : null,
      longitude: r.longitude ? parseFloat(r.longitude) : null,
      createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : null
    }));
  } catch (err) {
    console.error('Error getting status logs:', err.message);
    return [];
  }
}

module.exports = {
  logStatusChange,
  getStatusLogs
};
