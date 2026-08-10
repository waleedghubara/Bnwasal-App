const { getPool } = require('../config/db');

// 1. GET ALL TRIPS FOR LOGGED IN DRIVER
const getTrips = async (req, res, next) => {
  try {
    const pool = getPool();
    const driverId = req.user.id;

    const [rows] = await pool.query(
      `SELECT id, fromAddress, toAddress, fromCity, toCity, passingCities, departureTime, arrivalTime, date, time, status, price, distance, createdAt
       FROM trips
       WHERE driverId = ?
       ORDER BY date DESC, time DESC`,
      [driverId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحميل مسارات الرحلات بنجاح',
      data: rows.map(row => {
        // Format date to local YYYY-MM-DD to avoid timezone shift issues
        let dateVal = row.date;
        if (dateVal instanceof Date) {
          const year = dateVal.getFullYear();
          const month = String(dateVal.getMonth() + 1).padStart(2, '0');
          const day = String(dateVal.getDate()).padStart(2, '0');
          dateVal = `${year}-${month}-${day}`;
        }
        return {
          id: row.id.toString(),
          from: row.fromAddress,
          to: row.toAddress,
          fromCity: row.fromCity,
          toCity: row.toCity,
          passingCities: row.passingCities,
          departureTime: row.departureTime,
          arrivalTime: row.arrivalTime,
          date: dateVal,
          time: row.time,
          status: row.status,
          price: row.price ? parseFloat(row.price) : null,
          distance: row.distance ? parseFloat(row.distance) : null
        };
      })
    });
  } catch (error) {
    next(error);
  }
};

// 2. CREATE A NEW TRIP
const createTrip = async (req, res, next) => {
  try {
    const pool = getPool();
    const driverId = req.user.id;
    const { from, to, fromCity, toCity, passingCities, departureTime, arrivalTime, date, time, price, distance } = req.body;

    if (!from || !to || !date || !time || !passingCities || !passingCities.trim()) {
      return res.status(400).json({
        status: 0,
        message: 'جميع الحقول الأساسية مطلوبة (من، إلى، التاريخ، الوقت، خط السير)'
      });
    }

    // Format date string to YYYY-MM-DD
    let formattedDate = date;
    if (date.includes('T')) {
      formattedDate = date.split('T')[0];
    }

    const [result] = await pool.query(
      `INSERT INTO trips (driverId, fromAddress, toAddress, fromCity, toCity, passingCities, departureTime, arrivalTime, date, time, price, distance, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [driverId, from, to, fromCity || null, toCity || null, passingCities || null, departureTime || null, arrivalTime || null, formattedDate, time, price || null, distance || null]
    );

    const newTripId = result.insertId;

    // Fetch driver's name
    const [driverRows] = await pool.query(
      "SELECT CONCAT(firstName, ' ', lastName) as name FROM users WHERE id = ?",
      [driverId]
    );
    const driverName = driverRows.length > 0 ? driverRows[0].name.trim() : 'كابتن';

    const io = req.app.get('io');
    const notificationTitle = 'رحلة جديدة لمندوب 🚚';
    const notificationBody = `قام المندوب ${driverName} بإنشاء رحلة من ${from} إلى ${to}، وقت بداية الرحلة: ${departureTime || time}، وقت انتهاء الرحلة: ${arrivalTime || 'غير محدد'}.`;

    const { notifyAdmins } = require('../utils/adminNotifier');
    await notifyAdmins(io, notificationTitle, notificationBody, 'trip', {
      tripId: newTripId.toString(),
      from,
      to,
      departureTime: departureTime || time,
      arrivalTime: arrivalTime || ''
    });

    if (io) {
      io.to('admins').emit('dashboard_update');
    }

    res.status(201).json({
      status: 1,
      message: 'تم إضافة مسار الرحلة بنجاح',
      data: {
        id: newTripId.toString(),
        from,
        to,
        fromCity,
        toCity,
        passingCities,
        departureTime,
        arrivalTime,
        date: formattedDate,
        time,
        status: 'pending',
        price: price ? parseFloat(price) : null,
        distance: distance ? parseFloat(distance) : null
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. UPDATE AN EXISTING TRIP
const updateTrip = async (req, res, next) => {
  try {
    const pool = getPool();
    const driverId = req.user.id;
    const { id } = req.params;
    const { from, to, fromCity, toCity, passingCities, departureTime, arrivalTime, date, time, status, price, distance } = req.body;

    if (passingCities !== undefined && (!passingCities || !passingCities.trim())) {
      return res.status(400).json({
        status: 0,
        message: 'خط السير / نقاط المرور مطلوب إجباري'
      });
    }

    // Check if trip exists and belongs to the user
    const [trips] = await pool.query(
      'SELECT id, driverId FROM trips WHERE id = ?',
      [id]
    );

    if (trips.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'مسار الرحلة غير موجود'
      });
    }

    if (trips[0].driverId !== driverId) {
      return res.status(403).json({
        status: 0,
        message: 'غير مصرح لك بتعديل هذا المسار'
      });
    }

    let formattedDate = date;
    if (date && date.includes('T')) {
      formattedDate = date.split('T')[0];
    }

    await pool.query(
      `UPDATE trips
       SET fromAddress = COALESCE(?, fromAddress),
           toAddress = COALESCE(?, toAddress),
           fromCity = COALESCE(?, fromCity),
           toCity = COALESCE(?, toCity),
           passingCities = COALESCE(?, passingCities),
           departureTime = COALESCE(?, departureTime),
           arrivalTime = COALESCE(?, arrivalTime),
           date = COALESCE(?, date),
           time = COALESCE(?, time),
           status = COALESCE(?, status),
           price = ?,
           distance = ?
       WHERE id = ?`,
      [from, to, fromCity, toCity, passingCities, departureTime, arrivalTime, formattedDate, time, status, price || null, distance || null, id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تعديل مسار الرحلة بنجاح',
      data: {
        id: id.toString(),
        from: from || trips[0].fromAddress,
        to: to || trips[0].toAddress,
        date: formattedDate || trips[0].date,
        time: time || trips[0].time,
        status: status || trips[0].status,
        price: price ? parseFloat(price) : null,
        distance: distance ? parseFloat(distance) : null
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. DELETE A TRIP
const deleteTrip = async (req, res, next) => {
  try {
    const pool = getPool();
    const driverId = req.user.id;
    const { id } = req.params;

    // Check if trip exists and belongs to the user
    const [trips] = await pool.query(
      'SELECT id, driverId FROM trips WHERE id = ?',
      [id]
    );

    if (trips.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'مسار الرحلة غير موجود'
      });
    }

    if (trips[0].driverId !== driverId) {
      return res.status(403).json({
        status: 0,
        message: 'غير مصرح لك بحذف هذا المسار'
      });
    }

    await pool.query('DELETE FROM trips WHERE id = ?', [id]);

    res.status(200).json({
      status: 1,
      message: 'تم حذف مسار الرحلة بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTrips,
  createTrip,
  updateTrip,
  deleteTrip
};
