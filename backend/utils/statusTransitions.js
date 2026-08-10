const { forbidden } = require('./accessControl');

/** Normalize status for comparison (lowercase trim). */
function norm(s) {
  return (s || '').toString().trim().toLowerCase();
}

// ─── شحنات: ما يمكن للتاجر تغييره ──────────────────────────────────────────
const MERCHANT_SHIPMENT_TO = new Set(
  [
    'تم قبول العرض',
    'assigned to captain',
    'جديدة',
    'pending review',
    'بانتظار القبول',
    'cancelled',
    'ملغي',
    'ملغية',
  ].map(norm)
);

// ─── شحنات: ما يمكن للكابتن تغييره ─────────────────────────────────────────
const CAPTAIN_SHIPMENT_TO = new Set(
  [
    'في انتظار القبول',
    'جاري التنفيذ',
    'تم القبول',
    'assigned to captain',
    'ready for assignment',
    'pending review',
    'picked up',
    'in transit',
    'delivered',
    'completed',
    'منتهية',
    'captain arrived',
    'ongoing',
    'rejected',
    'مرفوض',
    'timeout',
    'cancelled',
    'ملغي',
    'ملغية',
  ].map(norm)
);

// ─── طلبات: ما يمكن للتاجر تغييره (الإلغاء فقط) ────────────────────────────
const MERCHANT_ORDER_TO = new Set(
  [
    'cancelled',
    'ملغي',
    'ملغية',
  ].map(norm)
);

/**
 * الانتقالات المسموح بها للكابتن على الطلبات بالترتيب الصحيح.
 */
const CAPTAIN_ORDER_VALID_TRANSITIONS = {
  'assigned to captain': ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'وصل المندوب للتاجر', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'ready for assignment': ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'في انتظار القبول':     ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'بانتظار القبول':       ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'pending':            ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'new':                ['جاري التنفيذ', 'تم القبول', 'captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'rejected', 'مرفوض', 'timeout', 'cancelled', 'ملغي', 'ملغية'],
  'captain arrived':     ['picked up', 'Picked Up', 'in transit', 'In Transit', 'cancelled', 'ملغي', 'ملغية'],
  'picked up':           ['in transit', 'In Transit', 'delivered', 'Delivered', 'cancelled', 'ملغي', 'ملغية'],
  'in transit':          ['delivered', 'Delivered', 'cancelled', 'ملغي', 'ملغية'],
  'جاري التنفيذ':         ['captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'in transit', 'In Transit', 'cancelled', 'ملغي', 'ملغية'],
  'تم القبول':           ['captain arrived', 'Captain Arrived', 'picked up', 'Picked Up', 'in transit', 'In Transit', 'cancelled', 'ملغي', 'ملغية'],
};

function assertShipmentStatusTransition(role, shipment, toStatus, userId) {
  if (role === 'admin' || role === 'employee') return;

  const to = norm(toStatus);
  if (!to) throw forbidden('حالة غير صالحة');

  if (role === 'merchant') {
    if (Number(shipment.merchantId) !== Number(userId)) {
      throw forbidden('غير مصرح بتحديث حالة هذه الشحنة');
    }
    if (!MERCHANT_SHIPMENT_TO.has(to)) {
      throw forbidden('انتقال حالة غير مسموح للتاجر');
    }
    return;
  }

  if (role === 'captain') {
    const assigned =
      shipment.captainId != null && Number(shipment.captainId) === Number(userId);
    const isBid = CAPTAIN_SHIPMENT_TO.has(to) && (to === norm('في انتظار القبول') || to === norm('pending review'));
    if (!assigned && !isBid) {
      throw forbidden('غير مصرح بتحديث حالة شحنة غير معيّنة لك');
    }
    if (!CAPTAIN_SHIPMENT_TO.has(to)) {
      throw forbidden('انتقال حالة غير مسموح للكابتن');
    }
    return;
  }

  throw forbidden('غير مصرح بتحديث الحالة');
}

function assertOrderStatusTransition(role, order, toStatus, userId) {
  if (role === 'admin' || role === 'employee') return;

  const to = norm(toStatus);
  if (!to) throw forbidden('حالة غير صالحة');

  if (role === 'merchant') {
    if (Number(order.merchantId) !== Number(userId)) {
      throw forbidden('غير مصرح بتحديث حالة هذا الطلب');
    }
    if (!MERCHANT_ORDER_TO.has(to)) {
      throw forbidden('انتقال حالة غير مسموح للتاجر - يمكن للتاجر الإلغاء فقط');
    }
    return;
  }

  if (role === 'captain') {
    const assigned =
      order.captainId != null && Number(order.captainId) === Number(userId);

    if (!assigned) {
      throw forbidden('غير مصرح بتحديث حالة طلب غير معيّن لك');
    }

    // التحقق من الانتقال التسلسلي الصحيح
    const from = norm(order.status);
    const allowedNext = CAPTAIN_ORDER_VALID_TRANSITIONS[from] || [];

    if (!allowedNext.map(norm).includes(to)) {
      throw forbidden(
        `لا يمكن الانتقال من "${order.status}" إلى "${toStatus}". ` +
        `الانتقالات المسموح بها: ${allowedNext.join(', ')}`
      );
    }
    return;
  }

  throw forbidden('غير مصرح بتحديث الحالة');
}

module.exports = {
  assertShipmentStatusTransition,
  assertOrderStatusTransition,
  norm,
};
