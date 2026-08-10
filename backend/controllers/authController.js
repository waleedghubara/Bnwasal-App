const bcrypt = require('bcryptjs');
const { getPool } = require('../config/db');
const {
  generateAccessToken,
  generateRefreshToken,
  generateResetToken,
  verifyRefreshToken
} = require('../utils/tokenHelper');
const { validateRegisterInput, validatePassword } = require('../utils/validationHelper');
const { devOnlyResponse, isProduction } = require('../utils/securityConfig');
const { sendOtpWhatsapp, sendResetPasswordWhatsapp } = require('../utils/whatsappHelper');

const deleteFile = (relativePath) => {
  if (!relativePath) return;
  const path = require('path');
  const fs = require('fs');
  const absolutePath = path.join(__dirname, '..', relativePath);
  if (fs.existsSync(absolutePath)) {
    try {
      fs.unlinkSync(absolutePath);
    } catch (err) {
      console.error('Error deleting file:', err);
    }
  }
};

const getCompletenessForUser = (user, docsExist) => {
  const missingDetails = [];
  if (user.role === 'captain') {
    if (!docsExist) {
      missingDetails.push('documents');
    }
  }
  if (user.role === 'captain' && (!user.vehicleType || user.vehicleType.trim().length === 0)) {
    missingDetails.push('vehicle');
  }
  const isProfileComplete = missingDetails.length === 0;
  return { isProfileComplete, missingDetails };
};

// Helper to format date for MySQL in local timezone
const getFutureDateString = (minutes) => {
  const date = new Date(Date.now() + minutes * 60 * 1000);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutesStr = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutesStr}:${seconds}`;
};


// 1. REGISTER USER
const register = async (req, res, next) => {
  try {
    const pool = getPool();
    const error = validateRegisterInput(req.body);
    if (error) {
      if (req.file) deleteFile(`/uploads/${req.file.filename}`);
      return res.status(400).json({ status: 0, message: error });
    }

    const { firstName, lastName, email: rawEmail, phone, password, role, referredByCode } = req.body;
    // Normalize email: treat empty string as null
    const email = rawEmail && rawEmail.trim().length > 0 ? rawEmail.trim() : null;

    // Check if user already exists
    let existingUsers = [];
    if (email) {
      const [rows] = await pool.query(
        'SELECT id, email, phone FROM users WHERE email = ? OR phone = ?',
        [email, phone]
      );
      existingUsers = rows;
    } else {
      const [rows] = await pool.query(
        'SELECT id, phone FROM users WHERE phone = ?',
        [phone]
      );
      existingUsers = rows;
    }

    if (existingUsers.length > 0) {
      if (req.file) deleteFile(`/uploads/${req.file.filename}`);
      const isEmail = email && existingUsers.some(u => u.email === email);
      return res.status(400).json({
        status: 0,
        message: isEmail ? 'البريد الالكتروني مسجل بالفعل' : 'رقم الهاتف مسجل بالفعل'
      });
    }

    // Check if there is a valid referrer code
    let referrerId = null;
    if (referredByCode && referredByCode.trim().length > 0) {
      const [referrerRows] = await pool.query(
        'SELECT id FROM users WHERE referralCode = ?',
        [referredByCode.trim()]
      );
      if (referrerRows.length > 0) {
        referrerId = referrerRows[0].id;
      }
    }

    // Hash Password
    const salt = await bcrypt.genSalt(12);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Generate 6-digit OTP (in production, integrate SMS gateway)
    let otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    let otpExpiry = getFutureDateString(10); // 10 minutes expiry

    // Check for uploaded profile image
    let profileImagePath = null;
    if (req.file) {
      profileImagePath = `/uploads/${req.file.filename}`;
    }

    // Check if request is authenticated as admin or employee for auto-activation
    let status = 'pending_otp';
    let isAdminCreated = false;

    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (token) {
      const { verifyAccessToken } = require('../utils/tokenHelper');
      const decoded = verifyAccessToken(token);
      if (decoded) {
        const [tokenUsers] = await pool.query(
          'SELECT role, status FROM users WHERE id = ?',
          [decoded.id]
        );
        if (tokenUsers.length > 0 && (tokenUsers[0].role === 'admin' || tokenUsers[0].role === 'employee')) {
          status = 'active';
          otpCode = null;
          otpExpiry = null;
          isAdminCreated = true;
        }
      }
    }

    // Insert user into DB
    const [result] = await pool.query(
      `INSERT INTO users (firstName, lastName, email, phone, password, role, status, otp_code, otp_expiry, profileImage, walletBalance) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0.00)`,
      [firstName, lastName, email, phone, hashedPassword, role, status, otpCode, otpExpiry, profileImagePath]
    );

    const userId = result.insertId;

    // Generate unique referral code for this user
    const prefixName = firstName.toUpperCase().replace(/[^A-Z]/g, '').substring(0, 4) || 'USER';
    const referralCode = `WASAL-${prefixName}-${userId}`;

    // Save referralCode and referredBy relation
    await pool.query(
      'UPDATE users SET referralCode = ?, referredBy = ? WHERE id = ?',
      [referralCode, referrerId, userId]
    );

    // If there was a valid referrer, reward the referrer immediately with 15 points
    if (referrerId) {
      // 1. Increment referrer's points by 15
      await pool.query(
        'UPDATE users SET points = points + 15 WHERE id = ?',
        [referrerId]
      );

      // 2. Insert completed referral record
      await pool.query(
        `INSERT INTO referrals (referrerId, refereeId, status, rewardAmount) 
         VALUES (?, ?, 'completed', 15.00)`,
        [referrerId, userId]
      );

      // 3. Send notifications to referrer
      try {
        const { createDbNotification, sendPushNotification } = require('../utils/notificationHelper');
        const refereeName = `${firstName} ${lastName}`;
        
        await createDbNotification(
          referrerId,
          'مكافأة دعوة صديق! 🎉',
          `لقد سجل صديقك ${refereeName} باستخدام رابط الدعوة الخاص بك وحصلت على 15 نقطة جديدة (ما يعادل 15 ج.م)!`,
          'referral'
        );

        // Fetch referrer token to send push
        const [referrerRows] = await pool.query('SELECT fcmToken FROM users WHERE id = ?', [referrerId]);
        if (referrerRows.length > 0 && referrerRows[0].fcmToken) {
          sendPushNotification(
            referrerRows[0].fcmToken,
            'مكافأة دعوة صديق! 🎉',
            `لقد سجل صديقك ${refereeName} باستخدام رابط الدعوة الخاص بك وحصلت على 15 نقطة جديدة (ما يعادل 15 ج.م)!`,
            { type: 'referral_points', points: '15' }
          ).catch(err => console.error('Push error:', err));
        }
      } catch (notiErr) {
        console.error('Error sending referral notification during registration:', notiErr);
      }
    }

    // Print OTP in development console for easy testing
    if (!isAdminCreated && !isProduction()) {
      console.log(`\n\x1b[33m[WhatsApp Simulator] OTP for ${phone}: \x1b[1m\x1b[32m${otpCode}\x1b[0m\n`);
    }

    // Send OTP to WhatsApp in the background to prevent API blocking/timeout
    if (!isAdminCreated) {
      sendOtpWhatsapp(phone, otpCode, `${firstName} ${lastName}`).catch(err => console.error('Background WhatsApp Error:', err));
    }

    res.status(201).json({
      status: 1,
      message: isAdminCreated
        ? 'تم إنشاء الحساب وتفعيله بنجاح.'
        : 'تم إنشاء الحساب بنجاح. يرجى إدخال كود التحقق المرسل لرقم الواتساب الخاص بك.',
      data: {
        userId: userId,
        email,
      }
    });
  } catch (error) {
    if (req.file) deleteFile(`/uploads/${req.file.filename}`);
    next(error);
  }
};

// 2. VERIFY OTP
const verifyOtp = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, phone, otp_code } = req.body;
    const identifier = email || phone;

    if (!identifier || !otp_code) {
      return res.status(400).json({
        status: 0,
        message: 'البريد الإلكتروني أو رقم الهاتف وكود التحقق مطلوبان'
      });
    }

    // Find user with matching email or phone
    const [users] = await pool.query(
      'SELECT * FROM users WHERE email = ? OR phone = ?',
      [identifier, identifier]
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'المستخدم غير موجود'
      });
    }

    const user = users[0];

    if (user.status !== 'pending_otp') {
      return res.status(400).json({
        status: 0,
        message: 'تم التحقق من هذا الحساب بالفعل'
      });
    }

    // Validate OTP Code and Expiry
    if (user.otp_code !== otp_code) {
      return res.status(400).json({
        status: 0,
        message: 'كود التحقق غير صحيح'
      });
    }

    const now = new Date();
    const expiry = new Date(user.otp_expiry);
    if (now > expiry) {
      return res.status(400).json({
        status: 0,
        message: 'انتهت صلاحية كود التحقق. يرجى طلب كود جديد.'
      });
    }

    // Determine next status
    // Captains go to pending_verification (need documents & admin approval)
    // Merchants go directly to active!
    const nextStatus = user.role === 'merchant' ? 'active' : 'pending_verification';

    await pool.query(
      'UPDATE users SET status = ?, otp_code = NULL, otp_expiry = NULL WHERE id = ?',
      [nextStatus, user.id]
    );

    // Notify admins about new pending account
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      const io = req.app.get('io');
      const userName = user.storeName || `${user.firstName} ${user.lastName}`;
      const roleLabel = user.role === 'merchant' ? 'تاجر' : 'كابتن';
      await notifyAdmins(
        io,
        '📋 طلب تسجيل جديد',
        `قام ${userName} بالتسجيل كـ ${roleLabel} بانتظار الموافقة`,
        'pending_account',
        { type: 'pending_account', userId: user.id.toString() }
      );
    } catch (_) {}

    // Generate tokens with device binding
    const deviceId = req.headers['x-device-id'] || null;
    const accessToken = generateAccessToken(user, deviceId);
    const refreshToken = generateRefreshToken(user, deviceId);

    // Save refresh token to DB
    const expiresAt = getFutureDateString(30 * 24 * 60); // 30 days
    await pool.query(
      'INSERT INTO refresh_tokens (userId, token, expiresAt, deviceId) VALUES (?, ?, ?, ?)',
      [user.id, refreshToken, expiresAt, deviceId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تفعيل الحساب بنجاح',
      data: {
        token: accessToken,
        refresh_token: refreshToken,
        user: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          phone: user.phone,
          role: user.role,
          status: user.status,
          profileImage: user.profileImage,
          permissions: user.permissions || null
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. RESEND OTP
const resendOtp = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, phone } = req.body;
    const identifier = email || phone;

    if (!identifier) {
      return res.status(400).json({ status: 0, message: 'البريد الإلكتروني أو رقم الهاتف مطلوب' });
    }

    const [users] = await pool.query(
      'SELECT id, email, phone, status, firstName, lastName FROM users WHERE email = ? OR phone = ?',
      [identifier, identifier]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];
    if (user.status !== 'pending_otp') {
      return res.status(400).json({ status: 0, message: 'الحساب مفعل بالفعل' });
    }

    const newOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const newExpiry = getFutureDateString(10);

    await pool.query(
      'UPDATE users SET otp_code = ?, otp_expiry = ? WHERE id = ?',
      [newOtp, newExpiry, user.id]
    );

    if (!isProduction()) {
      console.log(`\n\x1b[33m[WhatsApp Simulator] New OTP for ${user.phone}: \x1b[1m\x1b[32m${newOtp}\x1b[0m\n`);
    }

    // Send OTP to WhatsApp in the background to prevent API blocking/timeout
    sendOtpWhatsapp(user.phone, newOtp, `${user.firstName} ${user.lastName}`).catch(err => console.error('Background WhatsApp Error:', err));

    res.status(200).json({
      status: 1,
      message: 'تم إعادة إرسال كود التحقق بنجاح',
      data: {},
    });
  } catch (error) {
    next(error);
  }
};

// 4. LOGIN
const login = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, password } = req.body; // email field can accept email or phone

    if (!email || !password) {
      return res.status(400).json({
        status: 0,
        message: 'البريد الالكتروني وكلمة المرور مطلوبان'
      });
    }

    // Search user by email or phone
    const [users] = await pool.query(
      'SELECT * FROM users WHERE email = ? OR phone = ?',
      [email, email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        status: 0,
        message: 'البريد الالكتروني أو كلمة المرور غير صحيحة'
      });
    }

    const user = users[0];

    // Block admin and employee roles from logging in via the customer/captain app
    if (user.role === 'admin' || user.role === 'employee') {
      return res.status(403).json({
        status: 0,
        message: 'عذراً، هذا الحساب غير مصرح له بالدخول من خلال تطبيق العملاء/الكباتن.'
      });
    }

    if (user.role === 'merchant' && user.status === 'pending_verification') {
      await pool.query('UPDATE users SET status = "active" WHERE id = ?', [user.id]);
      user.status = 'active';
    }

    if (user.status === 'banned') {
      return res.status(403).json({
        status: 0,
        message: 'هذا الحساب محظور من قبل الإدارة',
        is_banned: true
      });
    }

    // Check Password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        status: 0,
        message: 'البريد الالكتروني أو كلمة المرور غير صحيحة'
      });
    }

    // If OTP is not verified yet, block login and ask to verify
    if (user.status === 'pending_otp') {
      return res.status(400).json({
        status: 0,
        message: `يرجى إكمال التحقق من الهاتف أولاً قبل تسجيل الدخول (كود التحقق تم إرساله لرقم الواتساب ${user.phone})`,
        errorCode: 'PENDING_OTP',
        data: { phone: user.phone }
      });
    }

    // Fetch driver documents to determine verification and completeness (Check both driver_documents and users table)
    const [docs] = await pool.query(
      'SELECT id FROM driver_documents WHERE userId = ?',
      [user.id]
    );
    const docsExist = docs.length > 0 || !!(user.nationalIdFront && user.nationalIdBack);

    // If user is pending verification — block login until admin approves only if they have already uploaded documents
    if (user.status === 'pending_verification') {
      if (docsExist) {
        const isCaptainWithoutVehicle = user.role === 'captain' && (!user.vehicleType || user.vehicleType.trim().length === 0);
        if (!isCaptainWithoutVehicle) {
          const roleText = user.role === 'captain' ? 'ككابتن' : 'كتاجر';
          return res.status(403).json({
            status: 0,
            message: `حسابك قيد المراجعة من قبل الإدارة. يرجى الانتظار حتى يتم تفعيل حسابك ${roleText}.`,
            errorCode: 'PENDING_APPROVAL'
          });
        }
      }
    }

    // Generate Tokens with device binding
    const deviceId = req.headers['x-device-id'] || null;
    const accessToken = generateAccessToken(user, deviceId);
    const refreshToken = generateRefreshToken(user, deviceId);

    // Save refresh token to DB
    const expiresAt = getFutureDateString(30 * 24 * 60); // 30 days
    await pool.query(
      'INSERT INTO refresh_tokens (userId, token, expiresAt, deviceId) VALUES (?, ?, ?, ?)',
      [user.id, refreshToken, expiresAt, deviceId]
    );

    const { isProfileComplete, missingDetails } = getCompletenessForUser(user, docsExist);

    res.status(200).json({
      status: 1,
      message: 'تم تسجيل الدخول بنجاح',
      data: {
        token: accessToken,
        refresh_token: refreshToken,
        user: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          phone: user.phone,
          role: user.role,
          status: user.status,
          profileImage: user.profileImage,
          isProfileComplete,
          missingDetails
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 5. REFRESH TOKEN
const refreshToken = async (req, res, next) => {
  try {
    const pool = getPool();
    const { refresh_token } = req.body;

    if (!refresh_token) {
      return res.status(400).json({ status: 0, message: 'Refresh token is required' });
    }

    // Verify token structure and secret
    const decoded = verifyRefreshToken(refresh_token);
    if (!decoded) {
      return res.status(401).json({ status: 0, message: 'التوكن غير صالح أو منتهي الصلاحية' });
    }

    const deviceId = req.headers['x-device-id'];
    // Verify Device ID binding matches in the token payload
    if (decoded.deviceId && decoded.deviceId !== deviceId) {
      return res.status(401).json({
        status: 0,
        message: 'التوكن غير صالح أو منتهي الصلاحية (مخالفة لربط الجهاز)',
        errorCode: 'DEVICE_MISMATCH'
      });
    }

    // Check database (and ensure deviceId matches stored row if bound)
    const [dbTokens] = await pool.query(
      'SELECT * FROM refresh_tokens WHERE userId = ? AND token = ? AND expiresAt > NOW() AND (deviceId IS NULL OR deviceId = ?)',
      [decoded.id, refresh_token, deviceId || '']
    );

    if (dbTokens.length === 0) {
      // BREACH DETECTION: The refresh token is a valid signed token but NOT found in the database.
      // This indicates it has either expired or was already rotated (used).
      // If it was already rotated, this is a replay attack (token theft).
      // For maximum security, invalidate all active refresh tokens for this user.
      await pool.query(
        'DELETE FROM refresh_tokens WHERE userId = ?',
        [decoded.id]
      );
      return res.status(401).json({ status: 0, message: 'التوكن غير صالح أو منتهي الصلاحية' });
    }

    // Retrieve current user status
    const [users] = await pool.query(
      'SELECT id, email, role, status FROM users WHERE id = ?',
      [decoded.id]
    );

    if (users.length === 0 || users[0].status === 'banned') {
      return res.status(401).json({ status: 0, message: 'المستخدم غير صالح أو محظور' });
    }

    const user = users[0];

    // Delete the old used refresh token
    await pool.query(
      'DELETE FROM refresh_tokens WHERE userId = ? AND token = ?',
      [decoded.id, refresh_token]
    );

    // Issue a new access token and a rotated refresh token with the same device ID
    const newAccessToken = generateAccessToken(user, deviceId);
    const newRefreshToken = generateRefreshToken(user, deviceId);

    // Save the new rotated refresh token to DB
    const expiresAt = getFutureDateString(30 * 24 * 60); // 30 days
    await pool.query(
      'INSERT INTO refresh_tokens (userId, token, expiresAt, deviceId) VALUES (?, ?, ?, ?)',
      [user.id, newRefreshToken, expiresAt, deviceId]
    );

    res.status(200).json({
      status: 1,
      token: newAccessToken,
      refresh_token: newRefreshToken
    });
  } catch (error) {
    next(error);
  }
};

// 6. LOGOUT
const logout = async (req, res, next) => {
  try {
    const pool = getPool();
    const { refresh_token } = req.body;

    if (refresh_token) {
      // Invalidate specific token
      await pool.query(
        'DELETE FROM refresh_tokens WHERE userId = ? AND token = ?',
        [req.user.id, refresh_token]
      );
    } else {
      // Invalidate all tokens for user
      await pool.query(
        'DELETE FROM refresh_tokens WHERE userId = ?',
        [req.user.id]
      );
    }

    res.status(200).json({
      status: 1,
      message: 'تم تسجيل الخروج بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 7. GET PROFILE
const getProfile = async (req, res, next) => {
  try {
    const pool = getPool();
    const [users] = await pool.query(
      'SELECT id, firstName, lastName, email, phone, role, status, profileImage, storeName, city, latitude, longitude, createdAt, permissions, vehicleType, nationalId, nationalIdFront, nationalIdBack FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];

    if (user.role === 'merchant' && user.status === 'pending_verification') {
      await pool.query('UPDATE users SET status = "active" WHERE id = ?', [user.id]);
      user.status = 'active';
    }

    // Retrieve document status
    let documents = null;
    const [docs] = await pool.query(
      'SELECT nationalId, nationalIdFront, nationalIdBack FROM driver_documents WHERE userId = ?',
      [user.id]
    );
    const docsExist = docs.length > 0 || !!(user.nationalIdFront && user.nationalIdBack);
    if (docsExist) {
      documents = docs[0] || {
        nationalId: user.nationalId,
        nationalIdFront: user.nationalIdFront,
        nationalIdBack: user.nationalIdBack
      };
    }

    const { isProfileComplete, missingDetails } = getCompletenessForUser(user, docsExist);
    const userWithDetails = { ...user, isProfileComplete, missingDetails };

    res.status(200).json({
      status: 1,
      data: {
        user: userWithDetails,
        documents
      }
    });
  } catch (error) {
    next(error);
  }
};

// 8. UPLOAD DRIVER DOCUMENTS
const uploadDriverDocuments = async (req, res, next) => {
  try {
    const pool = getPool();
    const { nationalId } = req.body;

    const isDigits = /^\d{14}$/.test(nationalId);
    if (!nationalId || !isDigits) {
      if (req.files) {
        if (req.files.nationalIdFront) deleteFile(`/uploads/${req.files.nationalIdFront[0].filename}`);
        if (req.files.nationalIdBack) deleteFile(`/uploads/${req.files.nationalIdBack[0].filename}`);
      }
      return res.status(400).json({
        status: 0,
        message: 'الرقم القومي يجب أن يتكون من 14 رقماً عدديّاً'
      });
    }

    if (!req.files || !req.files.nationalIdFront || !req.files.nationalIdBack) {
      if (req.files) {
        if (req.files.nationalIdFront) deleteFile(`/uploads/${req.files.nationalIdFront[0].filename}`);
        if (req.files.nationalIdBack) deleteFile(`/uploads/${req.files.nationalIdBack[0].filename}`);
      }
      return res.status(400).json({
        status: 0,
        message: 'يجب رفع صورة وجه وظهر البطاقة الشخصية'
      });
    }

    const frontImage = `/uploads/${req.files.nationalIdFront[0].filename}`;
    const backImage = `/uploads/${req.files.nationalIdBack[0].filename}`;

    // Insert or update documents
    const [existing] = await pool.query(
      'SELECT id, nationalIdFront, nationalIdBack FROM driver_documents WHERE userId = ?',
      [req.user.id]
    );

    let oldFront = null;
    let oldBack = null;

    if (existing.length > 0) {
      oldFront = existing[0].nationalIdFront;
      oldBack = existing[0].nationalIdBack;
      await pool.query(
        'UPDATE driver_documents SET nationalId = ?, nationalIdFront = ?, nationalIdBack = ? WHERE userId = ?',
        [nationalId, frontImage, backImage, req.user.id]
      );
    } else {
      await pool.query(
        'INSERT INTO driver_documents (userId, nationalId, nationalIdFront, nationalIdBack) VALUES (?, ?, ?, ?)',
        [req.user.id, nationalId, frontImage, backImage]
      );
    }

    // Delete old files from disk on successful update
    if (oldFront) deleteFile(oldFront);
    if (oldBack) deleteFile(oldBack);

    // Keep user status as pending_verification (waiting for admin review)
    await pool.query(
      'UPDATE users SET status = "pending_verification" WHERE id = ?',
      [req.user.id]
    );

    // Notify admins about document upload for review
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      const io = req.app.get('io');
      // Fetch full user data from DB (JWT only has id, email, role, status)
      const [userRows] = await pool.query(
        'SELECT firstName, lastName, storeName, role FROM users WHERE id = ?',
        [req.user.id]
      );
      const dbUser = userRows[0];
      const userName = dbUser.storeName || `${dbUser.firstName} ${dbUser.lastName}`;
      const roleLabel = dbUser.role === 'merchant' ? 'تاجر' : 'كابتن';
      await notifyAdmins(
        io,
        '📄 مستندات جديدة للمراجعة',
        `قام ${userName} (${roleLabel}) برفع المستندات للمراجعة`,
        'pending_account',
        { type: 'pending_account', userId: req.user.id.toString() }
      );
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم رفع المستندات بنجاح وجاري مراجعة الحساب',
      data: {
        nationalId,
        nationalIdFront: frontImage,
        nationalIdBack: backImage,
        status: 'pending_verification'
      }
    });
  } catch (error) {
    if (req.files) {
      if (req.files.nationalIdFront) deleteFile(`/uploads/${req.files.nationalIdFront[0].filename}`);
      if (req.files.nationalIdBack) deleteFile(`/uploads/${req.files.nationalIdBack[0].filename}`);
    }
    next(error);
  }
};

// 9. FORGOT PASSWORD — Send OTP to WhatsApp
const forgotPassword = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, phone } = req.body; // email field can accept email or phone
    const identifier = email || phone;

    if (!identifier) {
      return res.status(400).json({ status: 0, message: 'البريد الإلكتروني أو رقم الهاتف مطلوب' });
    }

    const [users] = await pool.query(
      'SELECT id, email, phone, firstName, lastName, status FROM users WHERE email = ? OR phone = ?',
      [identifier, identifier]
    );

    const genericMessage =
      'إذا كان الحساب مسجلاً لدينا، ستصلك رسالة بكود إعادة تعيين كلمة المرور على الواتساب الخاص برقم الهاتف المرتبط بحسابك خلال دقائق';

    if (users.length === 0) {
      return res.status(200).json({
        status: 1,
        message: genericMessage,
        data: { email: identifier },
      });
    }

    const user = users[0];
    if (user.status === 'banned') {
      return res.status(200).json({
        status: 1,
        message: genericMessage,
        data: { email: identifier },
      });
    }

    const resetOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const resetExpiry = getFutureDateString(10); // 10 minutes

    await pool.query(
      'UPDATE users SET reset_otp = ?, reset_otp_expiry = ? WHERE id = ?',
      [resetOtp, resetExpiry, user.id]
    );

    if (!isProduction()) {
      printOtpInConsole = `\n\x1b[33m[WhatsApp Reset OTP] for ${user.phone}: \x1b[1m\x1b[32m${resetOtp}\x1b[0m\n`;
      console.log(printOtpInConsole);
    }

    sendResetPasswordWhatsapp(user.phone, resetOtp, `${user.firstName} ${user.lastName}`).catch(
      err => console.error('Background WhatsApp Error:', err)
    );

    res.status(200).json({
      status: 1,
      message: genericMessage,
      data: { email: identifier },
    });
  } catch (error) {
    next(error);
  }
};

// 10. VERIFY RESET OTP
const verifyResetOtp = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, phone, otp_code } = req.body; // email field can accept email or phone
    const identifier = email || phone;

    if (!identifier || !otp_code) {
      return res.status(400).json({ status: 0, message: 'البريد الإلكتروني أو رقم الهاتف والكود مطلوبان' });
    }

    const [users] = await pool.query(
      'SELECT id, reset_otp, reset_otp_expiry FROM users WHERE email = ? OR phone = ?',
      [identifier, identifier]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];

    if (!user.reset_otp || user.reset_otp !== otp_code) {
      return res.status(400).json({ status: 0, message: 'كود التحقق غير صحيح' });
    }

    const now = new Date();
    const expiry = new Date(user.reset_otp_expiry);
    if (now > expiry) {
      return res.status(400).json({ status: 0, message: 'انتهت صلاحية الكود. يرجى طلب كود جديد.' });
    }

    const resetToken = generateResetToken(user.id);

    // Clear the OTP after verification
    await pool.query(
      'UPDATE users SET reset_otp = NULL, reset_otp_expiry = NULL WHERE id = ?',
      [user.id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم التحقق بنجاح',
      data: { resetToken }
    });
  } catch (error) {
    next(error);
  }
};

// 11. RESET PASSWORD
const resetPassword = async (req, res, next) => {
  try {
    const pool = getPool();
    const { newPassword } = req.body;

    const pwdError = validatePassword(newPassword);
    if (pwdError) {
      return res.status(400).json({ status: 0, message: pwdError });
    }

    const salt = await bcrypt.genSalt(12);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await pool.query(
      'UPDATE users SET password = ? WHERE id = ?',
      [hashedPassword, req.user.id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحديث كلمة المرور بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 12. UPDATE PROFILE
const updateProfile = async (req, res, next) => {
  try {
    const pool = getPool();
    const { firstName, lastName, storeName, city, phone, latitude, longitude, vehicleType } = req.body;
    const userId = req.user.id;

    const updateFields = [];
    const updateValues = [];

    if (firstName !== undefined) { updateFields.push('firstName = ?'); updateValues.push(firstName); }
    if (lastName !== undefined) { updateFields.push('lastName = ?'); updateValues.push(lastName); }
    if (storeName !== undefined) { updateFields.push('storeName = ?'); updateValues.push(storeName); }
    if (city !== undefined) { updateFields.push('city = ?'); updateValues.push(city); }
    if (phone !== undefined) { updateFields.push('phone = ?'); updateValues.push(phone); }
    if (vehicleType !== undefined) { updateFields.push('vehicleType = ?'); updateValues.push(vehicleType); }
    if (latitude !== undefined) { 
      updateFields.push('latitude = ?'); 
      updateValues.push(latitude === '' || latitude === null ? null : parseFloat(latitude)); 
    }
    if (longitude !== undefined) { 
      updateFields.push('longitude = ?'); 
      updateValues.push(longitude === '' || longitude === null ? null : parseFloat(longitude)); 
    }

    let oldProfileImage = null;
    // Handle optional profile image upload
    if (req.file) {
      const imageUrl = `/uploads/${req.file.filename}`;
      updateFields.push('profileImage = ?');
      updateValues.push(imageUrl);

      const [rows] = await pool.query('SELECT profileImage FROM users WHERE id = ?', [userId]);
      if (rows.length > 0) {
        oldProfileImage = rows[0].profileImage;
      }
    }

    if (updateFields.length === 0) {
      if (req.file) deleteFile(`/uploads/${req.file.filename}`);
      return res.status(400).json({ status: 0, message: 'لا توجد بيانات للتحديث' });
    }

    updateValues.push(userId);
    await pool.query(
      `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`,
      updateValues
    );

    if (oldProfileImage) {
      deleteFile(oldProfileImage);
    }

    // Return updated profile
    const [users] = await pool.query(
      'SELECT id, firstName, lastName, email, phone, role, status, profileImage, storeName, city, latitude, longitude, createdAt, permissions, vehicleType, nationalId, nationalIdFront, nationalIdBack FROM users WHERE id = ?',
      [userId]
    );

    const [docs] = await pool.query(
      'SELECT id FROM driver_documents WHERE userId = ?',
      [userId]
    );
    const docsExist = docs.length > 0 || !!(users[0].nationalIdFront && users[0].nationalIdBack);
    const { isProfileComplete, missingDetails } = getCompletenessForUser(users[0], docsExist);
    const userWithDetails = { ...users[0], isProfileComplete, missingDetails };

    res.status(200).json({
      status: 1,
      message: 'تم تحديث البيانات بنجاح',
      data: { user: userWithDetails }
    });
  } catch (error) {
    if (req.file) deleteFile(`/uploads/${req.file.filename}`);
    next(error);
  }
};

// 13. CHANGE PASSWORD (Authenticated — requires old password verification)
const changePassword = async (req, res, next) => {
  try {
    const pool = getPool();
    const { currentPassword, newPassword } = req.body;

    // Validate inputs
    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        status: 0,
        message: 'كلمة المرور الحالية والجديدة مطلوبتان'
      });
    }

    const pwdError = validatePassword(newPassword);
    if (pwdError) {
      return res.status(400).json({ status: 0, message: pwdError });
    }

    // Fetch user's current hashed password from DB
    const [users] = await pool.query(
      'SELECT id, password FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ status: 0, message: 'المستخدم غير موجود' });
    }

    const user = users[0];

    // Verify current password matches
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(400).json({
        status: 0,
        message: 'كلمة المرور الحالية غير صحيحة'
      });
    }

    // Prevent setting the same password
    const isSame = await bcrypt.compare(newPassword, user.password);
    if (isSame) {
      return res.status(400).json({
        status: 0,
        message: 'كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية'
      });
    }

    // Hash new password and update
    const salt = await bcrypt.genSalt(12);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await pool.query(
      'UPDATE users SET password = ? WHERE id = ?',
      [hashedPassword, req.user.id]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تغيير كلمة المرور بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 14. UPDATE FCM TOKEN
const updateFcmToken = async (req, res, next) => {
  try {
    const pool = getPool();
    const { fcmToken } = req.body;
    const userId = req.user.id;

    await pool.query(
      'UPDATE users SET fcmToken = ? WHERE id = ?',
      [fcmToken || null, userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحديث رمز الإشعارات بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 15. WEB PUSH SUBSCRIPTION
const subscribeWebPush = async (req, res, next) => {
  try {
    const pool = getPool();
    const { subscription } = req.body;
    const userId = req.user.id;

    if (!subscription || !subscription.endpoint) {
      return res.status(400).json({ status: 0, message: 'بيانات الاشتراك غير صالحة' });
    }

    await pool.query(
      'UPDATE users SET webPushSubscription = ? WHERE id = ?',
      [JSON.stringify(subscription), userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم الاشتراك في الإشعارات بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 16. ADMIN LOGIN
const adminLogin = async (req, res, next) => {
  try {
    const pool = getPool();
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        status: 0,
        message: 'البريد الالكتروني وكلمة المرور مطلوبان'
      });
    }

    const [users] = await pool.query(
      "SELECT * FROM users WHERE (email = ? OR phone = ?) AND role IN ('admin', 'employee')",
      [email, email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        status: 0,
        message: 'بيانات الدخول غير صحيحة'
      });
    }

    const user = users[0];

    if (user.status === 'banned') {
      return res.status(403).json({
        status: 0,
        message: 'هذا الحساب محظور من قبل الإدارة'
      });
    }

    if (user.status !== 'active') {
      return res.status(403).json({
        status: 0,
        message: 'حسابك غير مفعل. يرجى التواصل مع الإدارة'
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        status: 0,
        message: 'بيانات الدخول غير صحيحة'
      });
    }

    const deviceId = req.headers['x-device-id'] || null;
    const accessToken = generateAccessToken(user, deviceId);
    const refreshToken = generateRefreshToken(user, deviceId);

    const expiresAt = getFutureDateString(30 * 24 * 60);
    await pool.query(
      'INSERT INTO refresh_tokens (userId, token, expiresAt, deviceId) VALUES (?, ?, ?, ?)',
      [user.id, refreshToken, expiresAt, deviceId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تسجيل الدخول بنجاح',
      data: {
        token: accessToken,
        refresh_token: refreshToken,
        user: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          phone: user.phone,
          role: user.role,
          status: user.status,
          profileImage: user.profileImage,
          permissions: user.permissions || ''
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  verifyOtp,
  resendOtp,
  login,
  refreshToken,
  logout,
  getProfile,
  uploadDriverDocuments,
  forgotPassword,
  verifyResetOtp,
  resetPassword,
  updateProfile,
  changePassword,
  updateFcmToken,
  subscribeWebPush,
  adminLogin
};
