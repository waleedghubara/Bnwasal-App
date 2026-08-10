const { getPool } = require('../config/db');

function forbidden(message = 'غير مصرح') {
  const err = new Error(message);
  err.status = 403;
  err.publicMessage = message;
  return err;
}

function assertShipmentAccess(shipment, user) {
  if (!user?.id) throw forbidden();
  const role = user.role;
  const uid = Number(user.id);

  if (role === 'admin' || role === 'employee') return;

  if (role === 'merchant' && Number(shipment.merchantId) === uid) return;

  if (role === 'captain' && shipment.captainId != null && Number(shipment.captainId) === uid) {
    return;
  }

  throw forbidden('غير مصرح لك بالوصول إلى هذه الشحنة');
}

function assertOrderAccess(order, user) {
  if (!user?.id) throw forbidden();
  const role = user.role;
  const uid = Number(user.id);

  if (role === 'admin' || role === 'employee') return;

  if (role === 'merchant' && Number(order.merchantId) === uid) return;

  if (role === 'captain' && order.captainId != null && Number(order.captainId) === uid) {
    return;
  }

  throw forbidden('غير مصرح لك بالوصول إلى هذا الطلب');
}

/** Merchant, admin, or employee may submit negotiation offers (not captain). */
function assertNegotiationSubmitRole(user) {
  const role = user?.role;
  if (role === 'merchant' || role === 'admin' || role === 'employee') return;
  throw forbidden('غير مصرح بإرسال عروض التفاوض');
}

/**
 * Accept/reject: intended receiver, or any staff when the merchant sent the offer.
 */
function assertCanRespondToOffer(msg, entity, user) {
  const uid = Number(user.id);
  if (Number(msg.receiverId) === uid) return;
  if (user.role === 'admin' || user.role === 'employee') {
    if (Number(entity.merchantId) === Number(msg.senderId)) return;
  }
  throw forbidden('غير مصرح بالرد على هذا العرض');
}

async function canJoinShipmentRoom(userId, role, shipmentId) {
  const pool = getPool();
  const [rows] = await pool.query(
    'SELECT merchantId, captainId FROM shipments WHERE id = ?',
    [shipmentId]
  );
  if (rows.length === 0) return false;
  const s = rows[0];
  if (role === 'admin' || role === 'employee') return true;
  if (role === 'merchant' && Number(s.merchantId) === Number(userId)) return true;
  if (role === 'captain' && s.captainId != null && Number(s.captainId) === Number(userId)) {
    return true;
  }
  return false;
}

async function canJoinOrderRoom(userId, role, orderId) {
  const pool = getPool();
  const [rows] = await pool.query(
    'SELECT merchantId, captainId FROM orders WHERE id = ?',
    [orderId]
  );
  if (rows.length === 0) return false;
  const o = rows[0];
  if (role === 'admin' || role === 'employee') return true;
  if (role === 'merchant' && Number(o.merchantId) === Number(userId)) return true;
  if (role === 'captain' && o.captainId != null && Number(o.captainId) === Number(userId)) {
    return true;
  }
  return false;
}

async function canJoinSupportRoom(userId, role, targetUserId) {
  if (role === 'admin' || role === 'employee') return true;
  return Number(userId) === Number(targetUserId);
}

async function assertCaptainForShipmentLocation(socketUserId, shipmentId) {
  const pool = getPool();
  const [rows] = await pool.query(
    'SELECT captainId, status FROM shipments WHERE id = ?',
    [shipmentId]
  );
  if (rows.length === 0) return false;
  const s = rows[0];
  if (Number(s.captainId) !== Number(socketUserId)) return false;
  const allowed = [
    'Assigned To Captain',
    'Captain Arrived',
    'Picked Up',
    'In Transit',
    'Delivered',
    // حالات قديمة للتوافق مع البيانات السابقة
    'تم قبول العرض',
    'جاري التنفيذ',
  ];
  return allowed.includes(s.status);
}

async function assertCaptainForOrderLocation(socketUserId, orderId) {
  const pool = getPool();
  const [rows] = await pool.query(
    'SELECT captainId, status FROM orders WHERE id = ?',
    [orderId]
  );
  if (rows.length === 0) return false;
  const o = rows[0];
  if (Number(o.captainId) !== Number(socketUserId)) return false;
  const allowed = [
    'Assigned To Captain',
    'Captain Arrived',
    'Picked Up',
    'In Transit',
    'Delivered',
  ];
  return allowed.includes(o.status);
}

module.exports = {
  forbidden,
  assertShipmentAccess,
  assertOrderAccess,
  assertNegotiationSubmitRole,
  assertCanRespondToOffer,
  canJoinShipmentRoom,
  canJoinOrderRoom,
  canJoinSupportRoom,
  assertCaptainForShipmentLocation,
  assertCaptainForOrderLocation,
};
