const { getPool } = require('../config/db');
const { sendNotification } = require('../utils/notificationDispatcher');

const EGYPT_UTC_OFFSET_HOURS = 3;

function parseArabicTime(str) {
  if (!str || typeof str !== 'string') return null;
  const m = str.match(/(\d{1,2}):(\d{2})/);
  if (!m) return null;
  let h = parseInt(m[1], 10);
  const min = parseInt(m[2], 10);
  const normalized = str.toLowerCase();
  const isPM = normalized.includes('م') || normalized.includes('pm');
  const isAM = normalized.includes('ص') || normalized.includes('am');
  if (isPM && h !== 12) h += 12;
  if (isAM && h === 12) h = 0;
  return { h, min };
}

function parseDatePart(dateStr) {
  if (!dateStr) return null;
  let y, m, d;
  if (dateStr instanceof Date) {
    if (isNaN(dateStr.getTime())) return null;
    y = dateStr.getFullYear();
    m = dateStr.getMonth() + 1;
    d = dateStr.getDate();
  } else {
    const str = String(dateStr);
    const cleaned = str.split('T')[0];
    const parts = cleaned.split('-');
    if (parts.length !== 3) return null;
    y = parseInt(parts[0], 10);
    m = parseInt(parts[1], 10);
    d = parseInt(parts[2], 10);
  }
  return { y, m, d };
}

function makeDt(dp, egyptH, min, extraDays = 0) {
  const egyptMs = Date.UTC(dp.y, dp.m - 1, dp.d + extraDays, egyptH, min, 0, 0);
  return new Date(egyptMs - EGYPT_UTC_OFFSET_HOURS * 3600000);
}

function computeEffectiveStatus(trip) {
  const { status, date, departureTime, time, arrivalTime } = trip;
  if (status === 'completed' || status === 'cancelled' || status === 'in_progress') return status;

  const dp = parseDatePart(date);
  if (!dp) return status;

  const now = new Date();
  const arr = parseArabicTime(arrivalTime);
  const dep = parseArabicTime(departureTime || time || '');

  if (arr) {
    const arrMin = arr.h * 60 + arr.min;
    let isCrossMidnight = false;
    if (dep) {
      isCrossMidnight = arrMin <= (dep.h * 60 + dep.min);
    } else {
      isCrossMidnight = arr.h < 7;
    }
    const arrDt = makeDt(dp, arr.h, arr.min, isCrossMidnight ? 1 : 0);
    if (now >= arrDt) return 'expired';
    if (dep) {
      const depDt = makeDt(dp, dep.h, dep.min);
      if (now >= depDt) return 'in_progress';
    }
    return 'pending';
  }

  const todayStart = new Date();
  const egyptNow = new Date(todayStart.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
  const egyptY = egyptNow.getUTCFullYear();
  const egyptM = egyptNow.getUTCMonth();
  const egyptD = egyptNow.getUTCDate();

  const egyptTodayStartMs = Date.UTC(egyptY, egyptM, egyptD, 0, 0, 0, 0) - EGYPT_UTC_OFFSET_HOURS * 3600000;
  const egyptTodayStart = new Date(egyptTodayStartMs);

  const dateEndMs = Date.UTC(dp.y, dp.m - 1, dp.d, 23, 59, 59, 999) - EGYPT_UTC_OFFSET_HOURS * 3600000;
  const dateEnd = new Date(dateEndMs);

  if (dateEnd < egyptTodayStart) return 'expired';

  if (dep) {
    const depDt = makeDt(dp, dep.h, dep.min);
    if (now >= depDt) return 'in_progress';
  }

  return status;
}

// 1. GET AVAILABLE CAPTAINS FOR ASSIGNMENT
const getAvailableCaptains = async (req, res, next) => {
  try {
    const pool = getPool();
    const { shipmentId, orderId } = req.query;

    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }

    let fromAddress = '';
    let toAddress = '';
    let fromGov = '';
    let toGov = '';

    if (shipmentId) {
      const [shipments] = await pool.query('SELECT fromGovernorate, fromArea, toGovernorate, toArea, fromAddress, toAddress FROM shipments WHERE id = ?', [shipmentId]);
      if (shipments.length > 0) {
        fromGov = shipments[0].fromGovernorate || '';
        fromAddress = shipments[0].fromAddress || shipments[0].fromArea || '';
        toGov = shipments[0].toGovernorate || '';
        toAddress = shipments[0].toAddress || shipments[0].toArea || '';
      }
    } else {
      const [orders] = await pool.query(
        `SELECT o.deliveryAddress, m.storeName, m.city, m.latitude, m.longitude
         FROM orders o LEFT JOIN users m ON o.merchantId = m.id
         WHERE o.id = ?`,
        [orderId]
      );
      if (orders.length > 0) {
        fromAddress = orders[0].storeName || orders[0].city || '';
        toAddress = orders[0].deliveryAddress || '';
      }
    }

    // Fetch active captains
    const [captains] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, profileImage, latitude, longitude, walletBalance, vehicleType,
              COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = users.id), 1), 0.0) as avgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = users.id) as reviewCount
       FROM users WHERE role = 'captain' AND status = 'active'`
    );

    const result = [];

    // Compute today's date in Egypt (UTC+3)
    const now = new Date();
    const egyptNow = new Date(now.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
    const egyptDate = egyptNow.toISOString().slice(0, 10);

    for (const captain of captains) {
      // Fetch overall active orders and shipments for the captain
      const [[overallStats]] = await pool.query(
        `SELECT
           (SELECT COUNT(*) FROM orders 
            WHERE captainId = ? 
              AND LOWER(status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeOrdersCount,
           (SELECT COUNT(*) FROM shipments 
            WHERE captainId = ? 
              AND LOWER(status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeShipmentsCount`,
        [captain.id, captain.id]
      );

      // Fetch today's trips (Egypt date) with orders/shipments counts
      const [trips] = await pool.query(
        `SELECT t.*,
                (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id) as ordersCount,
                (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id) as shipmentsCount,
                (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id AND LOWER(orders.status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeOrdersCount,
                (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id AND LOWER(shipments.status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeShipmentsCount
         FROM trips t
         WHERE t.driverId = ? AND t.date = ?`,
        [captain.id, egyptDate]
      );

      let isRecommended = false;
      let recommendationReason = '';
      let bestTripId = null;

      // Check if driver has a trip that covers the route
      for (const trip of trips) {
        // Skip completed/cancelled trips for recommendation
        if (trip.status === 'completed' || trip.status === 'cancelled') continue;

        const tFrom = (trip.fromAddress || '').toLowerCase();
        const tTo = (trip.toAddress || '').toLowerCase();

        // Use both governorate and address for matching
        const sFromRaw = (fromAddress || '').toLowerCase();
        const sToRaw = (toAddress || '').toLowerCase();
        const sFromGov = (fromGov || '').toLowerCase();
        const sToGov = (toGov || '').toLowerCase();

        // Check both directions:
        //   sFromRaw includes tFrom (e.g., shipment "شارع 15, مدينة نصر" contains trip "مدينة نصر")
        //   tFrom includes sFromRaw (e.g., trip "شارع 15, مدينة نصر, القاهرة" contains shipment "مدينة نصر")
        const matchesOrigin = sFromRaw && (sFromRaw.includes(tFrom) || tFrom.includes(sFromRaw) || (sFromGov && tFrom.includes(sFromGov)));
        const matchesDest = sToRaw && (sToRaw.includes(tTo) || tTo.includes(sToRaw) || (sToGov && tTo.includes(sToGov)));

        if (matchesOrigin && matchesDest) {
          isRecommended = true;
          bestTripId = trip.id;
          recommendationReason = 'لديه رحلة تطابق مسار الشحنة بالكامل اليوم';
          break;
        } else if (matchesOrigin || matchesDest) {
          isRecommended = true;
          bestTripId = trip.id;
          recommendationReason = matchesOrigin ? 'يمر بنقطة الاستلام اليوم' : 'يمر بنقطة التسليم اليوم';
        }
      }

      // If not yet recommended but has a today trip, pick the first one as best
      if (!bestTripId && trips.length > 0) {
        bestTripId = trips[0].id;
      }

      result.push({
        id: captain.id.toString(),
        name: `${captain.firstName} ${captain.lastName}`,
        phone: captain.phone,
        avatar: captain.profileImage || null,
        latitude: captain.latitude ? parseFloat(captain.latitude) : null,
        longitude: captain.longitude ? parseFloat(captain.longitude) : null,
        walletBalance: parseFloat(captain.walletBalance),
        avgRating: parseFloat(captain.avgRating || 0.0),
        reviewCount: parseInt(captain.reviewCount || 0),
        bestTripId: bestTripId ? bestTripId.toString() : null,
        activeOrdersCount: parseInt(overallStats.activeOrdersCount || 0),
        activeShipmentsCount: parseInt(overallStats.activeShipmentsCount || 0),
        trips: trips.map(t => {
          const effStatus = computeEffectiveStatus(t);
          return {
            id: t.id.toString(),
            from: t.fromAddress,
            to: t.toAddress,
            time: t.time,
            departureTime: t.departureTime || '',
            arrivalTime: t.arrivalTime || '',
            status: t.status,
            effectiveStatus: effStatus,
            ordersCount: parseInt(t.ordersCount || 0),
            shipmentsCount: parseInt(t.shipmentsCount || 0),
            activeOrdersCount: parseInt(t.activeOrdersCount || 0),
            activeShipmentsCount: parseInt(t.activeShipmentsCount || 0),
          };
        }),
        isRecommended,
        recommendationReason
      });
    }

    // Sort by recommendation first, then by whether they have any trip today
    result.sort((a, b) => {
      if (a.isRecommended !== b.isRecommended) return a.isRecommended ? -1 : 1;
      return (b.trips.length || 0) - (a.trips.length || 0);
    });

    res.status(200).json({ status: 1, data: result });
  } catch (error) {
    next(error);
  }
};

// 2. ASSIGN CAPTAIN TO SHIPMENT/ORDER
const assignCaptain = async (req, res, next) => {
  try {
    const pool = getPool();
    const { shipmentId, orderId, captainId } = req.body;

    if (!captainId) {
      return res.status(400).json({ status: 0, message: 'معرف الكابتن مطلوب' });
    }

    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }

    // Check if captain exists and is active
    const [captains] = await pool.query('SELECT firstName, lastName, fcmToken FROM users WHERE id = ? AND role = ? AND status = ?', [captainId, 'captain', 'active']);
    if (captains.length === 0) {
      return res.status(404).json({ status: 0, message: 'الكابتن غير موجود أو غير نشط حالياً' });
    }

    const captainName = `${captains[0].firstName} ${captains[0].lastName}`;

    // Get current fee collection mode setting
    const [settings] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'fee_collection_mode'");
    const mode = settings.length > 0 ? settings[0].value : 'after_agreement';

    let shipmentNum = '';
    let oldStatus = '';
    let isPaid = 0;
    let fromAddress = '';
    let toAddress = '';

    if (shipmentId) {
      const [shipments] = await pool.query('SELECT status, shipmentNumber, isPaid, fromAddress, toAddress FROM shipments WHERE id = ?', [shipmentId]);
      if (shipments.length === 0) return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
      oldStatus = shipments[0].status;
      shipmentNum = shipments[0].shipmentNumber;
      isPaid = shipments[0].isPaid || 0;
      fromAddress = shipments[0].fromAddress || '';
      toAddress = shipments[0].toAddress || '';
    } else {
      const [orders] = await pool.query('SELECT status, orderNumber, isPaid, deliveryAddress FROM orders WHERE id = ?', [orderId]);
      if (orders.length === 0) return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
      oldStatus = orders[0].status;
      shipmentNum = orders[0].orderNumber;
      isPaid = orders[0].isPaid || 0;
      toAddress = orders[0].deliveryAddress || '';
    }

    // Find the captain's best matching trip today (Egypt date) to link via trip_id
    let tripId = null;
    const now = new Date();
    const egyptNow = new Date(now.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
    const egyptDate = egyptNow.toISOString().slice(0, 10);
    const [captainTrips] = await pool.query(
      `SELECT id, fromAddress, toAddress FROM trips WHERE driverId = ? AND date = ?`,
      [captainId, egyptDate]
    );
    for (const t of captainTrips) {
      const tFrom = (t.fromAddress || '').toLowerCase();
      const tTo = (t.toAddress || '').toLowerCase();
      const sFrom = (fromAddress || '').toLowerCase();
      const sTo = (toAddress || '').toLowerCase();
      if (sFrom && (sFrom.includes(tFrom) || tFrom.includes(sFrom)) && sTo && (sTo.includes(tTo) || tTo.includes(sTo))) {
        tripId = t.id;
        break;
      }
    }
    // Fallback: use the captain's first today trip if no perfect match
    if (!tripId && captainTrips.length > 0) {
      tripId = captainTrips[0].id;
    }

    // Logic:
    // If mode is 'after_agreement', payment was done (status was 'Ready For Assignment').
    // So transition to 'Assigned To Captain'.
    // If mode is 'after_assignment', payment was NOT done yet.
    // So transition to 'Awaiting Payment'. Once paid, it will move to 'Assigned To Captain'.
    let nextStatus = 'Assigned To Captain';

    if (shipmentId) {
      await pool.query(
        `UPDATE shipments SET captainId = ?, status = ?, captainApprovalStatus = ?, trip_id = COALESCE(?, trip_id) WHERE id = ?`,
        [captainId, nextStatus, 'pending', tripId, shipmentId]
      );
    } else {
      await pool.query(
        `UPDATE orders SET captainId = ?, status = ?, captainApprovalStatus = ?, trip_id = COALESCE(?, trip_id) WHERE id = ?`,
        [captainId, nextStatus, 'pending', tripId, orderId]
      );
    }

    // Socket notification
    const targetRoom = shipmentId ? `shipment_${shipmentId}` : `order_${orderId}`;
    const io = req.app.get('io');
    if (io) {
      io.to(targetRoom).emit('statusUpdate', { status: nextStatus });
      io.to(targetRoom).emit('captain_assigned', { captainId: captainId.toString(), captainName });
      io.to('admins').emit('dashboard_update');
    }

    // Notify Captain
    sendNotification(io, captainId, 'شحنة جديدة مسندة 🚚', `تم إسناد الشحنة رقم #${shipmentNum} إليك من الإدارة.`, 'order', {
      type: 'shipment_assigned',
      shipmentId: shipmentId ? shipmentId.toString() : '',
      orderId: orderId ? orderId.toString() : '',
      status: nextStatus
    });

    res.status(200).json({
      status: 1,
      message: 'تم تعيين الكابتن وتحديث حالة الشحنة/الطلب بنجاح',
      data: { status: nextStatus, captainId, captainName }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAvailableCaptains,
  assignCaptain
};
