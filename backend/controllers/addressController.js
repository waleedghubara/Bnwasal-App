const { getPool } = require('../config/db');

// 1. GET ALL ADDRESSES
const getAddresses = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const [rows] = await pool.query(
      'SELECT * FROM addresses WHERE userId = ? ORDER BY createdAt DESC',
      [userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحميل العناوين بنجاح',
      data: rows.map(row => ({
        id: row.id.toString(),
        userId: row.userId.toString(),
        label: row.label || '',
        phone: row.phone || '',
        governorate: row.governorate || '',
        city: row.city || '',
        detail: row.detail || '',
        locationText: row.locationText || '',
        latitude: row.latitude ? parseFloat(row.latitude) : null,
        longitude: row.longitude ? parseFloat(row.longitude) : null,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
      }))
    });
  } catch (error) {
    next(error);
  }
};

// 2. CREATE ADDRESS
const createAddress = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const { label, phone, governorate, city, detail, locationText, latitude, longitude } = req.body;

    if (!label) {
      return res.status(400).json({
        status: 0,
        message: 'اسم المكان مطلوب'
      });
    }

    const [result] = await pool.query(
      `INSERT INTO addresses (userId, label, phone, governorate, city, detail, locationText, latitude, longitude)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        label,
        phone || null,
        governorate || null,
        city || null,
        detail || null,
        locationText || null,
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null
      ]
    );

    const addressId = result.insertId;

    res.status(201).json({
      status: 1,
      message: 'تم حفظ العنوان بنجاح',
      data: {
        id: addressId.toString(),
        userId: userId.toString(),
        label,
        phone: phone || '',
        governorate: governorate || '',
        city: city || '',
        detail: detail || '',
        locationText: locationText || '',
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. UPDATE ADDRESS
const updateAddress = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const addressId = req.params.id;
    const { label, phone, governorate, city, detail, locationText, latitude, longitude } = req.body;

    if (!label) {
      return res.status(400).json({
        status: 0,
        message: 'اسم المكان مطلوب'
      });
    }

    const [check] = await pool.query(
      'SELECT * FROM addresses WHERE id = ? AND userId = ?',
      [addressId, userId]
    );

    if (check.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'العنوان غير موجود'
      });
    }

    await pool.query(
      `UPDATE addresses 
       SET label = ?, phone = ?, governorate = ?, city = ?, detail = ?, locationText = ?, latitude = ?, longitude = ?
       WHERE id = ? AND userId = ?`,
      [
        label,
        phone || null,
        governorate || null,
        city || null,
        detail || null,
        locationText || null,
        latitude ? parseFloat(latitude) : null,
        longitude ? parseFloat(longitude) : null,
        addressId,
        userId
      ]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحديث العنوان بنجاح',
      data: {
        id: addressId.toString(),
        userId: userId.toString(),
        label,
        phone: phone || '',
        governorate: governorate || '',
        city: city || '',
        detail: detail || '',
        locationText: locationText || '',
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. DELETE ADDRESS
const deleteAddress = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;
    const addressId = req.params.id;

    const [check] = await pool.query(
      'SELECT * FROM addresses WHERE id = ? AND userId = ?',
      [addressId, userId]
    );

    if (check.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'العنوان غير موجود'
      });
    }

    await pool.query(
      'DELETE FROM addresses WHERE id = ? AND userId = ?',
      [addressId, userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم حذف العنوان بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAddresses,
  createAddress,
  updateAddress,
  deleteAddress
};
