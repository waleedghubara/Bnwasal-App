const { getPool } = require('../config/db');

// 1. Submit Contact/Feedback Form
exports.submitContactMessage = async (req, res, next) => {
  try {
    const { name, email, subject, message, source } = req.body;
    const userId = req.user ? req.user.id : null;

    if (!name || !email || !subject || !message) {
      return res.status(400).json({
        status: 0,
        message: 'جميع الحقول مطلوبة'
      });
    }

    const pool = getPool();
    const msgSource = source === 'website' ? 'website' : 'app';
    await pool.query(
      'INSERT INTO contact_messages (userId, name, email, subject, message, source) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, name, email, subject, message, msgSource]
    );

    // Notify admins about new contact message
    try {
      const { notifyAdmins } = require('../utils/adminNotifier');
      const io = req.app.get('io');
      await notifyAdmins(
        io,
        '💬 رسالة دعم جديدة',
        `من ${name}: ${subject} - ${message.substring(0, 100)}${message.length > 100 ? '...' : ''}`,
        'support',
        { type: 'support_contact', name, email, subject }
      );
    } catch (_) {}

    res.status(200).json({
      status: 1,
      message: 'تم إرسال رسالتك بنجاح وسيتواصل معك الدعم قريباً.'
    });
  } catch (err) {
    next(err);
  }
};

// 2. Get Support Conversation Messages
exports.getSupportMessages = async (req, res, next) => {
  try {
    const pool = getPool();
    let threadUserId = req.user.id;

    // If admin or employee is requesting a specific user's support thread
    if ((req.user.role === 'admin' || req.user.role === 'employee') && req.query.userId) {
      threadUserId = parseInt(req.query.userId);
    }

    // Update unread messages sent by the other party to 'read'
    await pool.query(
      "UPDATE support_messages SET status = 'read' WHERE userId = ? AND senderId != ? AND status != 'read'",
      [threadUserId, req.user.id]
    );

    const afterId = req.query.afterId ? parseInt(req.query.afterId) : null;
    let query = `
      SELECT sm.id, sm.userId, sm.senderId, sm.text, sm.image, sm.status, sm.createdAt,
             u.firstName, u.lastName, u.storeName, u.profileImage as senderAvatar, u.role as senderRole
      FROM support_messages sm
      JOIN users u ON sm.senderId = u.id
      WHERE sm.userId = ?
    `;
    const queryParams = [threadUserId];

    if (afterId) {
      query += ` AND sm.id > ?`;
      queryParams.push(afterId);
    }

    query += ` ORDER BY sm.createdAt ASC`;

    // Fetch messages with sender details
    const [messages] = await pool.query(query, queryParams);

    // Format messages for frontend
    const formattedMessages = messages.map(msg => ({
      id: msg.id.toString(),
      text: msg.text,
      imagePath: msg.image ? msg.image : null,
      isUser: msg.senderId === req.user.id,
      status: msg.status,
      timestamp: msg.createdAt,
      senderName: msg.senderRole === 'admin' ? 'الدعم الفني بنوصل' : (msg.storeName || `${msg.firstName} ${msg.lastName}`),
      senderAvatar: msg.senderAvatar,
      senderRole: msg.senderRole
    }));

    res.status(200).json({
      status: 1,
      message: 'تم تحميل رسائل الدعم بنجاح',
      data: formattedMessages
    });
  } catch (err) {
    next(err);
  }
};

// 3. Send Support Message (User to Support, or Admin to User)
exports.sendSupportMessage = async (req, res, next) => {
  try {
    const pool = getPool();
    let threadUserId = req.user.id;

    // If admin is replying to a user's support thread
    if (req.user.role === 'admin') {
      if (!req.body.userId) {
        return res.status(400).json({
          status: 0,
          message: 'يجب تحديد معرف المستخدم (userId)'
        });
      }
      threadUserId = parseInt(req.body.userId);
    }

    const { text } = req.body;
    let imagePath = null;

    if (req.file) {
      imagePath = `/uploads/${req.file.filename}`;
    }

    if (!text && !imagePath) {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن إرسال رسالة فارغة'
      });
    }

    // Insert message
    const [result] = await pool.query(
      'INSERT INTO support_messages (userId, senderId, text, image, status) VALUES (?, ?, ?, ?, ?)',
      [threadUserId, req.user.id, text || '', imagePath, 'sent']
    );

    const messageId = result.insertId;

    // Notify admins if a user (non-admin) sent a support message
    if (req.user.role !== 'admin' && req.user.role !== 'employee') {
      try {
        const { notifyAdmins } = require('../utils/adminNotifier');
        const io = req.app.get('io');
        const [senderRows] = await pool.query(
          'SELECT firstName, lastName, storeName, profileImage FROM users WHERE id = ?',
          [req.user.id]
        );
        const sender = senderRows[0] || {};
        const senderName = sender.storeName || `${sender.firstName || ''} ${sender.lastName || ''}`.trim();
        const senderAvatar = sender.profileImage || null;
        await notifyAdmins(
          io,
          '💬 رسالة دعم جديدة',
          `${senderName || 'مستخدم'}: ${(text || '').substring(0, 100)}${(text || '').length > 100 ? '...' : ''}`,
          'support',
          { type: 'support_message', userId: threadUserId.toString(), text: text || '', senderName, senderAvatar }
        );
      } catch (_) {}
    }

    // Fetch the saved message with sender details
    const [msgRows] = await pool.query(
      `SELECT sm.id, sm.userId, sm.senderId, sm.text, sm.image, sm.status, sm.createdAt,
              u.firstName, u.lastName, u.storeName, u.profileImage as senderAvatar, u.role as senderRole
       FROM support_messages sm
       JOIN users u ON sm.senderId = u.id
       WHERE sm.id = ?`,
      [messageId]
    );

    if (msgRows.length === 0) {
      throw new Error('فشل إرسال الرسالة');
    }

    const msg = msgRows[0];
    const formattedMessage = {
      id: msg.id.toString(),
      text: msg.text,
      imagePath: msg.image ? msg.image : null,
      isUser: false, // Will be overridden on socket emit / response
      status: msg.status,
      timestamp: msg.createdAt,
      senderName: msg.senderRole === 'admin' ? 'الدعم الفني بنوصل' : (msg.storeName || `${msg.firstName} ${msg.lastName}`),
      senderAvatar: msg.senderAvatar,
      senderRole: msg.senderRole
    };

    // Emit socket event to room support_${threadUserId}
    const io = req.app.get('io');
    if (io) {
      io.to(`support_${threadUserId}`).emit('supportMessage', {
        ...formattedMessage,
        userId: threadUserId,
        isUser: false // When received by other party, it's not their user
      });
    }

    // Send push notification if client is not in room
    try {
      if ((req.user.role === 'admin' || req.user.role === 'employee') && io) {
        let receiverInRoom = false;
        const clients = io.sockets.adapter.rooms.get(`support_${threadUserId}`);
        if (clients) {
          for (const clientId of clients) {
            const clientSocket = io.sockets.sockets.get(clientId);
            if (clientSocket && clientSocket.userId === threadUserId.toString()) {
              receiverInRoom = true;
              break;
            }
          }
        }

        if (!receiverInRoom) {
          const { sendNotification } = require('../utils/notificationDispatcher');
          sendNotification(io, threadUserId, 'رسالة جديدة من الدعم الفني 💬', text || 'أرسل صورة 📷', 'support', {
            type: 'support_message',
            userId: threadUserId.toString(),
            senderName: 'الدعم الفني بنوصل',
            text: text || ''
          });
          console.log(`🔔 Sent support notification (FCM + Web Push + Socket) to client ${threadUserId}`);
        }
      }
    } catch (e) {
      console.error('❌ Error sending support push notification:', e);
    }

    res.status(201).json({
      status: 1,
      message: 'تم إرسال الرسالة بنجاح',
      data: {
        ...formattedMessage,
        isUser: true // For the sender, this is their message
      }
    });
  } catch (err) {
    next(err);
  }
};

// 4. Get List of Support Threads (Admin Console)
exports.getSupportThreads = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'employee') {
      return res.status(403).json({ status: 0, message: 'غير مصرح بالدخول' });
    }

    const pool = getPool();
    // Fetch unique users who have support messages
    const [threads] = await pool.query(
      `SELECT DISTINCT sm.userId, u.firstName, u.lastName, u.storeName, u.profileImage, u.phone, u.email, u.role,
              (SELECT text FROM support_messages WHERE userId = sm.userId ORDER BY createdAt DESC LIMIT 1) as lastMessage,
              (SELECT createdAt FROM support_messages WHERE userId = sm.userId ORDER BY createdAt DESC LIMIT 1) as lastMessageTime,
              (SELECT COUNT(*) FROM support_messages WHERE userId = sm.userId AND senderId != ? AND status != 'read') as unreadCount
       FROM support_messages sm
       JOIN users u ON sm.userId = u.id
       ORDER BY lastMessageTime DESC`,
      [req.user.id]
    );

    const formattedThreads = threads.map(t => ({
      userId: t.userId,
      name: t.storeName || `${t.firstName} ${t.lastName}`,
      avatar: t.profileImage,
      phone: t.phone,
      email: t.email,
      role: t.role,
      lastMessage: t.lastMessage,
      lastMessageTime: t.lastMessageTime,
      unreadCount: t.unreadCount
    }));

    res.status(200).json({
      status: 1,
      message: 'تم تحميل المحادثات بنجاح',
      data: formattedThreads
    });
  } catch (err) {
    next(err);
  }
};

// 5. Lookup user, order, or shipment by email/phone/orderNumber/shipmentNumber
exports.lookupEntity = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'employee') {
      return res.status(403).json({ status: 0, message: 'غير مصرح بالدخول' });
    }

    const { q } = req.query;
    if (!q || q.trim().length < 2) {
      return res.status(400).json({ status: 0, message: 'يجب إدخال على الأقل حرفين للبحث' });
    }

    const query = q.trim();
    const pool = getPool();
    const result = { users: [], orders: [], shipments: [] };

    // 1. Search users by email or phone
    const [userRows] = await pool.query(
      `SELECT id, firstName, lastName, email, phone, role, status, profileImage, storeName, city, walletBalance, createdAt 
       FROM users 
       WHERE email LIKE ? OR phone LIKE ?
       LIMIT 10`,
      [`%${query}%`, `%${query}%`]
    );
    if (userRows.length > 0) {
      result.users = userRows.map(u => ({
        id: u.id,
        name: u.storeName || `${u.firstName} ${u.lastName}`,
        email: u.email,
        phone: u.phone,
        role: u.role,
        status: u.status,
        profileImage: u.profileImage,
        storeName: u.storeName,
        city: u.city,
        walletBalance: u.walletBalance,
        createdAt: u.createdAt,
      }));
    }

    // 2. Search orders by order number
    const [orderRows] = await pool.query(
      `SELECT o.id, o.orderNumber, o.status, o.orderPrice, o.deliveryFee, o.clientName, o.phone, o.details, o.deliveryAddress, o.createdAt, 
              u.firstName as merchantFirstName, u.lastName as merchantLastName, u.storeName as merchantStore
       FROM orders o
       JOIN users u ON o.merchantId = u.id
       WHERE o.orderNumber LIKE ?
       LIMIT 10`,
      [`%${query}%`]
    );
    if (orderRows.length > 0) {
      result.orders = orderRows.map(o => ({
        id: o.id,
        orderNumber: o.orderNumber,
        status: o.status,
        orderPrice: o.orderPrice,
        deliveryFee: o.deliveryFee,
        clientName: o.clientName,
        phone: o.phone,
        details: o.details,
        deliveryAddress: o.deliveryAddress,
        createdAt: o.createdAt,
        merchant: o.merchantStore || `${o.merchantFirstName} ${o.merchantLastName}`,
      }));
    }

    // 3. Search shipments by shipment number
    const [shipmentRows] = await pool.query(
      `SELECT s.id, s.shipmentNumber, s.status, s.price, s.weight, s.fromAddress, s.toAddress, s.fromGovernorate, s.toGovernorate, s.title, s.createdAt,
              u.firstName as merchantFirstName, u.lastName as merchantLastName, u.storeName as merchantStore
       FROM shipments s
       JOIN users u ON s.merchantId = u.id
       WHERE s.shipmentNumber LIKE ?
       LIMIT 10`,
      [`%${query}%`]
    );
    if (shipmentRows.length > 0) {
      result.shipments = shipmentRows.map(s => ({
        id: s.id,
        shipmentNumber: s.shipmentNumber,
        status: s.status,
        price: s.price,
        weight: s.weight,
        fromAddress: s.fromAddress,
        toAddress: s.toAddress,
        fromGovernorate: s.fromGovernorate,
        toGovernorate: s.toGovernorate,
        title: s.title,
        createdAt: s.createdAt,
        merchant: s.merchantStore || `${s.merchantFirstName} ${s.merchantLastName}`,
      }));
    }

    res.status(200).json({
      status: 1,
      message: 'نتائج البحث',
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// 6. Create / Update Test Support Admin User (Returns JWT token) — dev/bootstrap only
exports.createTestAdmin = async (req, res, next) => {
  try {
    const { isProduction } = require('../utils/securityConfig');
    if (isProduction()) {
      return res.status(404).json({ status: 0, message: 'Not found' });
    }
    const bootstrapSecret = process.env.DEV_BOOTSTRAP_SECRET;
    if (bootstrapSecret) {
      const provided = req.headers['x-bootstrap-secret'];
      if (provided !== bootstrapSecret) {
        return res.status(403).json({ status: 0, message: 'غير مصرح' });
      }
    }

    const bcrypt = require('bcryptjs');
    const { generateAccessToken } = require('../utils/tokenHelper');
    const { name, phone, email, password, presetAvatarUrl } = req.body;

    if (!name || !phone || !email || !password) {
      return res.status(400).json({ status: 0, message: 'جميع الحقول مطلوبة' });
    }

    const pool = getPool();
    const nameParts = name.trim().split(' ');
    const firstName = nameParts[0];
    const lastName = nameParts.slice(1).join(' ') || 'الدعم';

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    let profileImagePath = '/uploads/default-admin.png';
    if (req.file) {
      profileImagePath = `/uploads/${req.file.filename}`;
    } else if (presetAvatarUrl) {
      profileImagePath = presetAvatarUrl;
    }

    // Check if email or phone already exists
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ? OR phone = ?', [email, phone]);
    let userId;

    if (existing.length > 0) {
      userId = existing[0].id;
      await pool.query(
        'UPDATE users SET firstName = ?, lastName = ?, phone = ?, password = ?, role = "admin", status = "active", profileImage = ? WHERE id = ?',
        [firstName, lastName, phone, hashedPassword, profileImagePath, userId]
      );
    } else {
      const [result] = await pool.query(
        `INSERT INTO users (firstName, lastName, email, phone, password, role, status, profileImage, walletBalance) 
         VALUES (?, ?, ?, ?, ?, 'admin', 'active', ?, 0.00)`,
        [firstName, lastName, email, phone, hashedPassword, profileImagePath]
      );
      userId = result.insertId;

      const referralCode = `WASAL-ADM-${userId}`;
      await pool.query('UPDATE users SET referralCode = ? WHERE id = ?', [referralCode, userId]);
    }

    const token = generateAccessToken({ id: userId, email, role: 'admin' }, req.headers['x-device-id'] || 'admin-bootstrap');

    res.status(200).json({
      status: 1,
      message: 'تم إنشاء وتفعيل حساب الدعم بنجاح',
      data: {
        token,
        user: {
          id: userId,
          name: `${firstName} ${lastName}`,
          phone,
          email,
          profileImage: profileImagePath
        }
      }
    });
  } catch (err) {
    next(err);
  }
};

// 7. Get List of Contact/Feedback Messages (Admin Console)
exports.getContactMessages = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'employee') {
      return res.status(403).json({ status: 0, message: 'غير مصرح بالدخول' });
    }

    const pool = getPool();
    const [messages] = await pool.query(
      `SELECT cm.id, cm.userId, cm.name, cm.email, cm.subject, cm.message, cm.createdAt,
              u.firstName, u.lastName, u.storeName, u.profileImage, u.phone as userPhone, u.email as userEmail, u.role as userRole
       FROM contact_messages cm
       LEFT JOIN users u ON cm.userId = u.id
       ORDER BY cm.createdAt DESC`
    );

    const formattedMessages = messages.map(m => ({
      id: m.id,
      userId: m.userId,
      name: m.name,
      email: m.email,
      subject: m.subject,
      message: m.message,
      createdAt: m.createdAt,
      user: m.userId ? {
        id: m.userId,
        name: m.storeName || `${m.firstName} ${m.lastName}`,
        email: m.userEmail,
        phone: m.userPhone,
        profileImage: m.profileImage,
        role: m.userRole
      } : null
    }));

    res.status(200).json({
      status: 1,
      message: 'تم تحميل رسائل المستخدمين بنجاح',
      data: formattedMessages
    });
  } catch (err) {
    next(err);
  }
};

// 8. Delete a Contact/Feedback Message (Admin Console)
exports.deleteContactMessage = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ status: 0, message: 'غير مصرح بالدخول' });
    }
    const { id } = req.params;
    const pool = getPool();
    await pool.query('DELETE FROM contact_messages WHERE id = ?', [id]);
    res.status(200).json({ status: 1, message: 'تم حذف الرسالة بنجاح' });
  } catch (err) {
    next(err);
  }
};


