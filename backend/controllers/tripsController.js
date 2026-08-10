const { getPool } = require('../config/db');
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
  // Build the datetime in Egypt timezone first, then convert to UTC
  const egyptMs = Date.UTC(dp.y, dp.m - 1, dp.d + extraDays, egyptH, min, 0, 0);
  return new Date(egyptMs - EGYPT_UTC_OFFSET_HOURS * 3600000);
}

function computeEffectiveStatus(trip) {
  const { status, date, departureTime, time, arrivalTime } = trip;
  // DB-finalized statuses are authoritative
  if (status === 'completed' || status === 'cancelled' || status === 'in_progress') return status;

  const dp = parseDatePart(date);
  if (!dp) return status;

  const now = new Date();
  const arr = parseArabicTime(arrivalTime);
  const dep = parseArabicTime(departureTime || time || '');

  // ── CASE A: arrival time exists → we can detect both expired & in_progress ──
  if (arr) {
    const arrMin = arr.h * 60 + arr.min;

    // Cross-midnight heuristics:
    let isCrossMidnight = false;
    if (dep) {
      const depMin = dep.h * 60 + dep.min;
      isCrossMidnight = arrMin <= depMin;
    } else {
      // No departure time — early arrival (before 7 AM Egypt) likely means
      // the trip started the previous day and crosses midnight
      isCrossMidnight = arr.h < 7;
    }

    const arrDt = makeDt(dp, arr.h, arr.min, isCrossMidnight ? 1 : 0);

    // 1. EXPIRED → current time past arrival
    if (now >= arrDt) {
      if (trip._log) console.log(`[tripsCtrl] trip #${trip.id} expired: now=${now.toISOString()} >= arrival=${arrDt.toISOString()}`);
      return 'expired';
    }

    // 2. IN_PROGRESS → departure time has passed (and arrival hasn't)
    if (dep) {
      const depDt = makeDt(dp, dep.h, dep.min);
      if (now >= depDt) {
        if (trip._log) console.log(`[tripsCtrl] trip #${trip.id} in_progress: now=${now.toISOString()} >= departure=${depDt.toISOString()}`);
        return 'in_progress';
      }
    }

    // 3. PENDING → departure or start hasn't arrived yet
    if (trip._log) console.log(`[tripsCtrl] trip #${trip.id} pending: now=${now.toISOString()} < departure/arrival`);
    return 'pending';
  }

  // ── CASE B: no arrival time — date-based fallback ──────────────────────────
  // If the trip's date ended before today started in Egypt time, it's expired
  const todayStart = new Date();
  const egyptNow = new Date(todayStart.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
  const egyptY = egyptNow.getUTCFullYear();
  const egyptM = egyptNow.getUTCMonth();
  const egyptD = egyptNow.getUTCDate();
  
  // start of today in Egypt time, converted to UTC Date:
  const egyptTodayStartMs = Date.UTC(egyptY, egyptM, egyptD, 0, 0, 0, 0) - EGYPT_UTC_OFFSET_HOURS * 3600000;
  const egyptTodayStart = new Date(egyptTodayStartMs);

  const dateEndMs = Date.UTC(dp.y, dp.m - 1, dp.d, 23, 59, 59, 999) - EGYPT_UTC_OFFSET_HOURS * 3600000;
  const dateEnd = new Date(dateEndMs);

  if (dateEnd < egyptTodayStart) {
    if (trip._log) console.log(`[tripsCtrl] trip #${trip.id} expired: date ${date} fully past`);
    return 'expired';
  }

  // Same day and departure time has passed → in_progress
  if (dep) {
    const depDt = makeDt(dp, dep.h, dep.min);
    if (now >= depDt) {
      if (trip._log) console.log(`[tripsCtrl] trip #${trip.id} in_progress (no arrival): now=${now.toISOString()} >= departure=${depDt.toISOString()}`);
      return 'in_progress';
    }
  }

  return status;
}

function addEffectiveStatus(trip, log = false) {
  if (log) trip._log = true;
  const es = computeEffectiveStatus(trip);
  delete trip._log;

  // Format date to local YYYY-MM-DD to avoid timezone shift issues during JSON serialization
  let dateVal = trip.date;
  if (dateVal instanceof Date) {
    const year = dateVal.getFullYear();
    const month = String(dateVal.getMonth() + 1).padStart(2, '0');
    const day = String(dateVal.getDate()).padStart(2, '0');
    dateVal = `${year}-${month}-${day}`;
  } else if (typeof dateVal === 'string' && dateVal.includes('T')) {
    dateVal = dateVal.split('T')[0];
  }

  return { ...trip, date: dateVal, effectiveStatus: es };
}

function addEffectiveStatusBulk(trips, log = false) {
  return trips.map(t => addEffectiveStatus(t, log));
}

const getAllTrips = async (req, res, next) => {
  try {
    const pool = getPool();
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';
    const date = req.query.date || '';
    const dateFrom = req.query.dateFrom || '';
    const dateTo = req.query.dateTo || '';
    const status = req.query.status || '';
    const log = req.query.debug === '1';
    let params = [];
    const conditions = [];
    if (search) {
      conditions.push("(CONCAT(u.firstName, ' ', u.lastName) LIKE ? OR u.phone LIKE ?)");
      const s = `%${search}%`;
      params.push(s, s);
    }
    if (date) {
      conditions.push('t.date = ?');
      params.push(date);
    } else {
      if (dateFrom) {
        conditions.push('t.date >= ?');
        params.push(dateFrom);
      }
      if (dateTo) {
        conditions.push('t.date <= ?');
        params.push(dateTo);
      }
    }
    if (status) {
      conditions.push('t.status = ?');
      params.push(status);
    }
    const where = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';
    const countQuery = search
      ? `SELECT COUNT(*) as total FROM trips t JOIN users u ON u.id = t.driverId ${where}`
      : `SELECT COUNT(*) as total FROM trips t ${where}`;
    const [countRows] = await pool.query(countQuery, params);
    const total = countRows[0].total;
    const [rows] = await pool.query(`
      SELECT
        t.id, t.driverId, t.fromAddress, t.toAddress, t.passingCities, t.date, t.time,
        t.status, t.price, t.distance, t.createdAt, t.updatedAt,
        t.departureTime, t.arrivalTime,
        CONCAT(u.firstName, ' ', u.lastName) as captainName,
        u.profileImage, u.phone as captainPhone,
        (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id) as ordersCount,
        (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id) as shipmentsCount
      FROM trips t
      JOIN users u ON u.id = t.driverId
      ${where}
      ORDER BY t.createdAt DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);
    const trips = addEffectiveStatusBulk(rows, log);
    if (log) console.log(`[tripsCtrl] getAllTrips: ${rows.length} raw, total=${total}`);
    res.status(200).json({ status: 1, data: { trips, total, page, limit } });
  } catch (error) {
    next(error);
  }
};

const getTodayTrips = async (req, res, next) => {
  try {
    const pool = getPool();
    const now = new Date();
    // Compute today's date in Egypt (UTC+3) regardless of server timezone
    const egyptNow = new Date(now.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
    const egyptDate = egyptNow.toISOString().slice(0, 10);
    const search = req.query.search || '';
    const log = req.query.debug === '1';
    let params = [egyptDate];
    let where = "WHERE t.status != 'completed' AND t.status != 'cancelled' AND (t.status = 'in_progress' OR DATE(t.date) >= ?)";
    if (search) {
      where += " AND (CONCAT(u.firstName, ' ', u.lastName) LIKE ? OR u.phone LIKE ?)";
      const s = `%${search}%`;
      params.push(s, s);
    }
    if (log) console.log(`[tripsCtrl] getTodayTrips: egyptDate=${egyptDate} (server=${now.toISOString().slice(0,10)})`);
    const [rows] = await pool.query(`
      SELECT
        t.id, t.driverId, t.fromAddress, t.toAddress, t.passingCities, t.date, t.time,
        t.status, t.price, t.distance, t.createdAt, t.updatedAt,
        t.departureTime, t.arrivalTime,
        CONCAT(u.firstName, ' ', u.lastName) as captainName,
        u.profileImage, u.phone as captainPhone,
        (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id) as ordersCount,
        (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id) as shipmentsCount
      FROM trips t
      JOIN users u ON u.id = t.driverId
      ${where}
      ORDER BY t.createdAt DESC
    `, params);
    const trips = addEffectiveStatusBulk(rows, log);
    if (log) {
      console.log(`[tripsCtrl] getTodayTrips: ${rows.length} raw`);
      trips.forEach(t => console.log(`  trip #${t.id}: status=${t.status} effectiveStatus=${t.effectiveStatus}`));
    }
    res.status(200).json({ status: 1, data: { trips } });
  } catch (error) {
    next(error);
  }
};

const getTripsByDate = async (req, res, next) => {
  try {
    const pool = getPool();
    const { date } = req.params;
    const search = req.query.search || '';
    const log = req.query.debug === '1';
    let params = [date];
    let where = 'WHERE t.date = ?';
    if (search) {
      where += " AND (CONCAT(u.firstName, ' ', u.lastName) LIKE ? OR u.phone LIKE ?)";
      const s = `%${search}%`;
      params.push(s, s);
    }
    const [rows] = await pool.query(`
      SELECT
        t.id, t.driverId, t.fromAddress, t.toAddress, t.passingCities, t.date, t.time,
        t.status, t.price, t.distance, t.createdAt, t.updatedAt,
        t.departureTime, t.arrivalTime,
        CONCAT(u.firstName, ' ', u.lastName) as captainName,
        u.profileImage, u.phone as captainPhone,
        (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id) as ordersCount,
        (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id) as shipmentsCount
      FROM trips t
      JOIN users u ON u.id = t.driverId
      ${where}
      ORDER BY t.createdAt DESC
    `, params);
    const trips = addEffectiveStatusBulk(rows, log);
    if (log) console.log(`[tripsCtrl] getTripsByDate(${date}): ${trips.length} trips`);
    res.status(200).json({ status: 1, data: { trips } });
  } catch (error) {
    next(error);
  }
};

const getTripsByCaptain = async (req, res, next) => {
  try {
    const pool = getPool();
    const { captainId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const status = req.query.status || '';
    const date = req.query.date || '';
    const log = req.query.debug === '1';
    let params = [captainId];
    let conditions = ['t.driverId = ?'];
    if (status) {
      conditions.push('t.status = ?');
      params.push(status);
    }
    if (date) {
      conditions.push('t.date = ?');
      params.push(date);
    }
    const where = 'WHERE ' + conditions.join(' AND ');
    const [countRows] = await pool.query(`SELECT COUNT(*) as total FROM trips t ${where}`, params);
    const total = countRows[0].total;
    const [rows] = await pool.query(`
      SELECT
        t.id, t.driverId, t.fromAddress, t.toAddress, t.passingCities, t.date, t.time,
        t.status, t.price, t.distance, t.createdAt, t.updatedAt,
        t.departureTime, t.arrivalTime,
        CONCAT(u.firstName, ' ', u.lastName) as captainName,
        u.profileImage, u.phone as captainPhone,
        (SELECT COUNT(*) FROM orders WHERE orders.trip_id = t.id) as ordersCount,
        (SELECT COUNT(*) FROM shipments WHERE shipments.trip_id = t.id) as shipmentsCount
      FROM trips t
      JOIN users u ON u.id = t.driverId
      ${where}
      ORDER BY t.createdAt DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);
    const trips = addEffectiveStatusBulk(rows, log);
    res.status(200).json({ status: 1, data: { trips, total, page, limit } });
  } catch (error) {
    next(error);
  }
};

const updateTripStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { status } = req.body;
    if (!['pending', 'in_progress', 'completed', 'cancelled'].includes(status)) {
      return res.status(400).json({ status: 0, message: 'حالة غير صالحة' });
    }
    const [trips] = await pool.query('SELECT id FROM trips WHERE id = ?', [id]);
    if (trips.length === 0) return res.status(404).json({ status: 0, message: 'الرحلة غير موجودة' });
    await pool.query('UPDATE trips SET status = ? WHERE id = ?', [status, id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    const labels = { pending: 'قيد الانتظار', in_progress: 'جاري التنفيذ', completed: 'منتهية', cancelled: 'ملغية' };
    res.status(200).json({ status: 1, message: `تم تحديث حالة الرحلة إلى ${labels[status] || status}` });
  } catch (error) {
    next(error);
  }
};

const createTrip = async (req, res, next) => {
  try {
    const pool = getPool();
    const { driverId, fromAddress, toAddress, date, time, price, distance } = req.body;
    if (!driverId || !fromAddress || !toAddress || !date || !time) {
      return res.status(400).json({ status: 0, message: 'جميع الحقول مطلوبة' });
    }
    const [users] = await pool.query('SELECT id FROM users WHERE id = ? AND role = ?', [driverId, 'captain']);
    if (users.length === 0) return res.status(404).json({ status: 0, message: 'الكابتن غير موجود' });
    const [result] = await pool.query(
      'INSERT INTO trips (driverId, fromAddress, toAddress, date, time, price, distance, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [driverId, fromAddress, toAddress, date, time, price || null, distance || null, 'pending']
    );
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    res.status(201).json({ status: 1, message: 'تم إضافة الرحلة', data: { id: result.insertId } });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAllTrips,
  getTodayTrips,
  getTripsByDate,
  getTripsByCaptain,
  updateTripStatus,
  createTrip,
  computeEffectiveStatus,
  addEffectiveStatus,
  addEffectiveStatusBulk
};
