const { getPool } = require('../config/db');
const { assertShipmentAccess } = require('../utils/accessControl');

// 1. SEND MESSAGE
const sendMessage = async (req, res, next) => {
  try {
    const pool = getPool();
    const { shipmentId } = req.params;
    const { text } = req.body;
    const senderId = req.user.id;

    if (!text || text.trim() === '') {
      return res.status(400).json({
        status: 0,
        message: 'نص الرسالة مطلوب'
      });
    }

    // Check if shipment exists and find the receiver
    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [shipmentId]);
    if (shipments.length === 0) {
      return res.status(404).json({
        status: 0,
        message: 'الشحنة غير موجودة'
      });
    }

    const shipment = shipments[0];
    try {
      assertShipmentAccess(shipment, req.user);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }

    // Check if shipment is completed
    if (shipment.status === 'منتهية') {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن إرسال رسائل لهذه الشحنة لأنها مكتملة وتم إغلاق الشات وحذف الرسائل'
      });
    }

    let receiverId = null;

    if (senderId === shipment.merchantId) {
      receiverId = shipment.captainId;
    } else if (senderId === shipment.captainId) {
      receiverId = shipment.merchantId;
    }

    if (!receiverId) {
      return res.status(400).json({
        status: 0,
        message: 'لا يمكن إرسال رسالة لعدم وجود طرف آخر مسند للشحنة حالياً'
      });
    }

    // Save message to database
    const [result] = await pool.query(
      'INSERT INTO messages (shipmentId, senderId, receiverId, text) VALUES (?, ?, ?, ?)',
      [shipmentId, senderId, receiverId, text]
    );

    const messageId = result.insertId;

    // Get sender info
    const [senderRows] = await pool.query('SELECT firstName, lastName, role, profileImage FROM users WHERE id = ?', [senderId]);
    const senderName = senderRows.length > 0 ? `${senderRows[0].firstName} ${senderRows[0].lastName}` : 'مستخدم';
    const senderAvatar = senderRows.length > 0 ? (senderRows[0].profileImage || '') : '';

    const formattedMessage = {
      id: messageId.toString(),
      shipmentId: shipmentId.toString(),
      senderId: senderId.toString(),
      receiverId: receiverId.toString(),
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: text,
      createdAt: new Date().toISOString()
    };

    // Broadcast message via Socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`shipment_${shipmentId}`).emit('new_message', formattedMessage);
      console.log(`📡 Broadcasted message ${messageId} to room shipment_${shipmentId}`);
    }

    // Check if receiver is in the Socket.io room
    let receiverInRoom = false;
    if (io) {
      const clients = io.sockets.adapter.rooms.get(`shipment_${shipmentId}`);
      if (clients) {
        for (const clientId of clients) {
          const clientSocket = io.sockets.sockets.get(clientId);
          if (clientSocket && clientSocket.userId === receiverId.toString()) {
            receiverInRoom = true;
            break;
          }
        }
      }
    }

    // If receiver is not actively inside the chat screen room, send notification via all channels
    if (!receiverInRoom) {
      const { sendNotification } = require('../utils/notificationDispatcher');
      sendNotification(io, receiverId, `رسالة جديدة من ${senderName}`, text, 'chat', {
        type: 'chat_message',
        shipmentId: shipmentId.toString(),
        senderName: senderName,
        senderAvatar: senderAvatar,
        text: text
      });
      console.log(`🔔 Sent notification (FCM + Web Push + Socket) to user ${receiverId}`);
    } else {
      console.log(`📱 User ${receiverId} is active in the room. Suppressed push notification.`);
    }

    res.status(201).json({
      status: 1,
      message: 'تم إرسال الرسالة بنجاح',
      data: formattedMessage
    });
  } catch (error) {
    next(error);
  }
};

// 2. GET MESSAGES
const getMessages = async (req, res, next) => {
  try {
    const pool = getPool();
    const { shipmentId } = req.params;

    // Check if shipment is completed
    const [shipments] = await pool.query('SELECT * FROM shipments WHERE id = ?', [shipmentId]);
    if (shipments.length === 0) {
      return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
    }
    try {
      assertShipmentAccess(shipments[0], req.user);
    } catch (e) {
      return res.status(e.status || 403).json({ status: 0, message: e.publicMessage || e.message });
    }
    if (shipments[0].status === 'منتهية') {
      return res.status(400).json({
        status: 0,
        message: 'CHAT_DELETED'
      });
    }

    const [messages] = await pool.query(
      `SELECT m.*, CONCAT(u.firstName, ' ', u.lastName) as senderName
       FROM messages m
       LEFT JOIN users u ON m.senderId = u.id
       WHERE m.shipmentId = ?
       ORDER BY m.createdAt ASC`,
      [shipmentId]
    );

    const formattedMessages = messages.map(m => ({
      id: m.id.toString(),
      shipmentId: m.shipmentId.toString(),
      senderId: m.senderId.toString(),
      receiverId: m.receiverId.toString(),
      senderName: m.senderName,
      text: m.text,
      createdAt: m.createdAt.toISOString()
    }));

    res.status(200).json({
      status: 1,
      data: formattedMessages
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  sendMessage,
  getMessages
};
