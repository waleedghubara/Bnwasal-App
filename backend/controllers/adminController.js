const { getPool } = require('../config/db');

const getPendingAccounts = async (req, res, next) => {
  try {
    const pool = getPool();
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const role = req.query.role || '';

    let where = "WHERE u.role IN ('merchant', 'captain') AND u.status IN ('pending_verification', 'pending_otp')";
    const params = [];
    if (role && ['merchant', 'captain'].includes(role)) {
      where += ' AND u.role = ?';
      params.push(role);
    }

    const [countRows] = await pool.query(
      `SELECT COUNT(*) as total FROM users u ${where}`, params
    );
    const total = countRows[0].total;

    const [rows] = await pool.query(
      `SELECT u.id, u.firstName, u.lastName, u.email, u.phone, u.role, u.status,
              u.storeName, u.city, u.profileImage, u.createdAt, u.vehicleType,
              (SELECT COUNT(*) FROM orders WHERE merchantId = u.id) as totalOrders,
              (SELECT COUNT(*) FROM shipments WHERE merchantId = u.id) as totalShipments,
              (SELECT COUNT(*) FROM trips WHERE driverId = u.id) as totalTrips
       FROM users u ${where}
       ORDER BY u.createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    res.status(200).json({
      status: 1,
      data: { accounts: rows, total, page, limit },
    });
  } catch (error) {
    next(error);
  }
};

const getPendingAccountDetail = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, role, status,
              storeName, city, profileImage, walletBalance,
              nationalId, nationalIdFront, nationalIdBack, vehicleType,
              createdAt, updatedAt
       FROM users WHERE id = ? AND role IN ('merchant', 'captain') AND status IN ('pending_verification', 'pending_otp')`,
      [id]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'الحساب غير موجود' });
    }

    const account = users[0];

    let stats = {};
    if (account.role === 'merchant') {
      const [orderStats] = await pool.query(
        `SELECT COUNT(*) as totalOrders,
                SUM(CASE WHEN status = 'تم التسليم' THEN 1 ELSE 0 END) as completedOrders
         FROM orders WHERE merchantId = ?`,
        [id]
      );
      const [shipmentStats] = await pool.query(
        `SELECT COUNT(*) as totalShipments,
                SUM(CASE WHEN status = 'تم التسليم' THEN 1 ELSE 0 END) as completedShipments
         FROM shipments WHERE merchantId = ?`,
        [id]
      );
      stats = { orders: orderStats[0], shipments: shipmentStats[0] };
    } else if (account.role === 'captain') {
      const [tripStats] = await pool.query(
        `SELECT COUNT(*) as totalTrips,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedTrips
         FROM trips WHERE driverId = ?`,
        [id]
      );
      stats = { trips: tripStats[0] };
    }

    // Driver documents - fetch from driver_documents (where app uploads are saved)
    let driverDocuments = null;
    const [docs] = await pool.query(
      'SELECT * FROM driver_documents WHERE userId = ?',
      [id]
    );
    if (docs.length > 0) {
      driverDocuments = docs[0];
    }

    const documents = {
      nationalId: account.nationalId || (driverDocuments?.nationalId) || null,
      nationalIdFront: account.nationalIdFront || (driverDocuments?.nationalIdFront) || null,
      nationalIdBack: account.nationalIdBack || (driverDocuments?.nationalIdBack) || null,
    };
    delete account.nationalId;
    delete account.nationalIdFront;
    delete account.nationalIdBack;

    res.status(200).json({
      status: 1,
      data: {
        account: { ...account },
        stats,
        documents,
        driverDocuments,
      },
    });
  } catch (error) {
    next(error);
  }
};

const approvePendingAccount = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND role IN (?, ?) AND status IN (?, ?)',
      [id, 'merchant', 'captain', 'pending_verification', 'pending_otp']
    );
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'الحساب غير موجود' });
    }

    await pool.query('UPDATE users SET status = ? WHERE id = ?', ['active', id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        '✅ تم قبول حساب',
        `تم قبول حساب ${users[0].role === 'merchant' ? 'التاجر' : 'الكابتن'} رقم ${id}`,
        'account_approved',
        { type: 'account_approved', userId: id.toString() },
        req.user.id
      );
    } catch (_) {}
    try {
      const { sendNotification } = require('../utils/notificationDispatcher');
      const roleText = users[0].role === 'merchant' ? 'التاجر' : 'الكابتن';
      await sendNotification(
        io,
        id,
        '✅ تم تفعيل حسابك بنجاح!',
        `أهلاً بك! لقد تم تفعيل حساب ${roleText} الخاص بك من قِبل الإدارة. يمكنك الآن استخدام التطبيق بشكل كامل.`,
        'system',
        { type: 'account_approved', status: 'active' }
      );
    } catch (err) {
      console.error('Error sending account approved notification to user:', err);
    }
    res.status(200).json({ status: 1, message: 'تم قبول الحساب بنجاح' });
  } catch (error) {
    next(error);
  }
};

const rejectPendingAccount = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;

    const [users] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND role IN (?, ?) AND status IN (?, ?)',
      [id, 'merchant', 'captain', 'pending_verification', 'pending_otp']
    );
    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'الحساب غير موجود' });
    }

    await pool.query('UPDATE users SET status = ? WHERE id = ?', ['banned', id]);
    const io = req.app.get('io');
    if (io) io.to('admins').emit('dashboard_update');
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      await notifyAdmins(
        io,
        '❌ تم رفض حساب',
        `تم رفض حساب ${users[0].role === 'merchant' ? 'التاجر' : 'الكابتن'} رقم ${id}`,
        'account_rejected',
        { type: 'account_rejected', userId: id.toString() },
        req.user.id
      );
    } catch (_) {}
    try {
      const { sendNotification } = require('../utils/notificationDispatcher');
      const roleText = users[0].role === 'merchant' ? 'التاجر' : 'الكابتن';
      await sendNotification(
        io,
        id,
        '❌ تم رفض تفعيل حسابك',
        `تم رفض طلب تفعيل حساب ${roleText} الخاص بك. يرجى التواصل مع الدعم الفني للمزيد من التفاصيل.`,
        'system',
        { type: 'account_rejected', status: 'banned' }
      );
    } catch (err) {
      console.error('Error sending account rejected notification to user:', err);
    }
    res.status(200).json({ status: 1, message: 'تم رفض الحساب' });
  } catch (error) {
    next(error);
  }
};

// ─── Employee Management ──────────────────────────────────────

const getEmployees = async (req, res, next) => {
  try {
    const pool = getPool();
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';

    let where = "WHERE role = 'employee'";
    const params = [];
    if (search) {
      where += " AND (CONCAT(firstName, ' ', lastName) LIKE ? OR email LIKE ? OR phone LIKE ?)";
      const s = `%${search}%`;
      params.push(s, s, s);
    }

    const [countRows] = await pool.query(`SELECT COUNT(*) as total FROM users ${where}`, params);
    const total = countRows[0].total;

    const [rows] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, role, status, profileImage, permissions, city, nationalId, createdAt, updatedAt
       FROM users ${where}
       ORDER BY createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    res.status(200).json({ status: 1, data: { employees: rows, total, page, limit } });
  } catch (error) {
    next(error);
  }
};

const getEmployee = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, role, status, profileImage, permissions, city, nationalId, createdAt, updatedAt
       FROM users WHERE id = ? AND role = 'employee'`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ status: 0, message: 'الموظف غير موجود' });
    res.status(200).json({ status: 1, data: { employee: rows[0] } });
  } catch (error) {
    next(error);
  }
};

const createEmployee = async (req, res, next) => {
  try {
    const pool = getPool();
    const { firstName, lastName, email, phone, password, city, permissions, nationalId } = req.body;

    if (!firstName || !lastName || !email || !phone || !password) {
      return res.status(400).json({ status: 0, message: 'جميع الحقول مطلوبة' });
    }

    if (nationalId && (nationalId.length !== 14 || isNaN(nationalId))) {
      return res.status(400).json({ status: 0, message: 'الرقم القومي يجب أن يكون 14 رقماً' });
    }

    const [existing] = await pool.query('SELECT id FROM users WHERE email = ? OR phone = ?', [email, phone]);
    if (existing.length > 0) {
      return res.status(409).json({ status: 0, message: 'البريد الإلكتروني أو رقم الهاتف موجود مسبقاً' });
    }

    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash(password, 10);
    const permStr = Array.isArray(permissions) ? permissions.join(',') : (permissions || '');

    const [result] = await pool.query(
      `INSERT INTO users (firstName, lastName, email, phone, password, role, status, city, permissions, nationalId)
       VALUES (?, ?, ?, ?, ?, 'employee', 'active', ?, ?, ?)`,
      [firstName, lastName, email, phone, hashedPassword, city || null, permStr, nationalId || null]
    );

    res.status(201).json({
      status: 1,
      message: 'تم إضافة الموظف بنجاح',
      data: { id: result.insertId }
    });
  } catch (error) {
    next(error);
  }
};

const updateEmployee = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { firstName, lastName, email, phone, password, city, permissions, status, nationalId } = req.body;

    if (nationalId && (nationalId.length !== 14 || isNaN(nationalId))) {
      return res.status(400).json({ status: 0, message: 'الرقم القومي يجب أن يكون 14 رقماً' });
    }

    const [existing] = await pool.query("SELECT id FROM users WHERE id = ? AND role = 'employee'", [id]);
    if (existing.length === 0) return res.status(404).json({ status: 0, message: 'الموظف غير موجود' });

    const updates = [];
    const values = [];
    if (firstName !== undefined) { updates.push('firstName = ?'); values.push(firstName); }
    if (lastName !== undefined) { updates.push('lastName = ?'); values.push(lastName); }
    if (email !== undefined) { updates.push('email = ?'); values.push(email); }
    if (phone !== undefined) { updates.push('phone = ?'); values.push(phone); }
    if (city !== undefined) { updates.push('city = ?'); values.push(city); }
    if (status !== undefined) { updates.push('status = ?'); values.push(status); }
    if (nationalId !== undefined) { updates.push('nationalId = ?'); values.push(nationalId || null); }
    if (permissions !== undefined) {
      const permStr = Array.isArray(permissions) ? permissions.join(',') : permissions;
      updates.push('permissions = ?');
      values.push(permStr);
    }
    if (password) {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash(password, 10);
      updates.push('password = ?');
      values.push(hashedPassword);
    }

    if (updates.length === 0) return res.status(400).json({ status: 0, message: 'لا توجد بيانات للتحديث' });

    values.push(id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, values);

    res.status(200).json({ status: 1, message: 'تم تحديث بيانات الموظف' });
  } catch (error) {
    next(error);
  }
};

const deleteEmployee = async (req, res, next) => {
  try {
    const pool = getPool();
    const [result] = await pool.query("DELETE FROM users WHERE id = ? AND role = 'employee'", [req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ status: 0, message: 'الموظف غير موجود' });
    res.status(200).json({ status: 1, message: 'تم حذف الموظف' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getPendingAccounts, getPendingAccountDetail, approvePendingAccount, rejectPendingAccount,
  getEmployees, getEmployee, createEmployee, updateEmployee, deleteEmployee
};
