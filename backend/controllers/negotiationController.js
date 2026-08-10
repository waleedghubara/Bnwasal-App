const { getPool } = require('../config/db');
const { sendNotification } = require('../utils/notificationDispatcher');
const {
  assertShipmentAccess,
  assertOrderAccess,
  assertNegotiationSubmitRole,
  assertCanRespondToOffer,
} = require('../utils/accessControl');

async function loadEntityForNegotiation(pool, { shipmentId, orderId }) {
  if (shipmentId) {
    const [rows] = await pool.query(
      'SELECT id, merchantId, captainId, shipmentNumber FROM shipments WHERE id = ?',
      [shipmentId]
    );
    if (rows.length === 0) return null;
    return { kind: 'shipment', entity: rows[0] };
  }
  const [rows] = await pool.query(
    'SELECT id, merchantId, captainId, orderNumber FROM orders WHERE id = ?',
    [orderId]
  );
  if (rows.length === 0) return null;
  return { kind: 'order', entity: rows[0] };
}

function assertEntityAccess(kind, entity, user) {
  if (kind === 'shipment') assertShipmentAccess(entity, user);
  else assertOrderAccess(entity, user);
}

// ─── HELPER ───────────────────────────────────────────────────────────────────
const resolveParties = async (pool, req, { shipmentId, orderId }) => {
  let merchantId = null;
  let targetRoom = '';
  let entityNum = '';

  if (shipmentId) {
    const [rows] = await pool.query(
      'SELECT merchantId, shipmentNumber FROM shipments WHERE id = ?',
      [shipmentId]
    );
    if (rows.length === 0) return null;
    merchantId = rows[0].merchantId;
    entityNum = rows[0].shipmentNumber;
    targetRoom = `shipment_${shipmentId}`;
  } else {
    const [rows] = await pool.query(
      'SELECT merchantId, orderNumber FROM orders WHERE id = ?',
      [orderId]
    );
    if (rows.length === 0) return null;
    merchantId = rows[0].merchantId;
    entityNum = rows[0].orderNumber;
    targetRoom = `order_${orderId}`;
  }

  let receiverId;
  if (req.user.role === 'admin' || req.user.role === 'employee') {
    receiverId = merchantId;
  } else {
    const [admins] = await pool.query(
      "SELECT id FROM users WHERE role IN ('admin','employee') ORDER BY id ASC LIMIT 1"
    );
    receiverId = admins.length > 0 ? admins[0].id : merchantId;
  }

  return { merchantId, targetRoom, receiverId, entityNum };
};

// ─── 1. SUBMIT A PRICE OFFER ─────────────────────────────────────────────────
const submitOffer = async (req, res, next) => {
  try {
    const pool = getPool();
    const senderId = req.user.id;
    const { shipmentId, orderId, price, note } = req.body;

    if (!price || parseFloat(price) <= 0) {
      return res.status(400).json({ status: 0, message: 'سعر العرض يجب أن يكون أكبر من الصفر' });
    }
    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }

    const loaded = await loadEntityForNegotiation(pool, { shipmentId, orderId });
    if (!loaded) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    assertEntityAccess(loaded.kind, loaded.entity, req.user);
    assertNegotiationSubmitRole(req.user);

    const parties = await resolveParties(pool, req, { shipmentId, orderId });
    if (!parties) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    const { targetRoom, receiverId, entityNum } = parties;

    // Sender details
    const [senderRows] = await pool.query(
      'SELECT firstName, lastName, role FROM users WHERE id = ?',
      [senderId]
    );
    const senderName = senderRows.length > 0
      ? `${senderRows[0].firstName} ${senderRows[0].lastName}`
      : 'الإدارة';
    const senderRole = senderRows.length > 0 ? senderRows[0].role : 'admin';

    const offerText = note?.trim()
      ? `عرض سعر: ${price} ج.م — ${note.trim()}`
      : `عرض سعر جديد بقيمة ${price} ج.م`;

    // Insert offer record
    const [result] = await pool.query(
      `INSERT INTO messages (shipmentId, orderId, senderId, receiverId, text, messageType, offerPrice, offerStatus, note)
       VALUES (?, ?, ?, ?, ?, 'offer', ?, 'pending', ?)`,
      [
        shipmentId ? parseInt(shipmentId) : null,
        orderId ? parseInt(orderId) : null,
        senderId,
        receiverId,
        offerText,
        parseFloat(price),
        note?.trim() || null
      ]
    );
    const adminMessageId = result.insertId;

    // Update entity status → Negotiation
    if (shipmentId) {
      await pool.query("UPDATE shipments SET status = 'Negotiation' WHERE id = ?", [shipmentId]);
    } else {
      await pool.query("UPDATE orders SET status = 'Negotiation' WHERE id = ?", [orderId]);
    }

    const formattedOffer = {
      id: adminMessageId.toString(),
      shipmentId: shipmentId ? shipmentId.toString() : null,
      orderId: orderId ? orderId.toString() : null,
      senderId: senderId.toString(),
      receiverId: receiverId.toString(),
      senderName,
      senderRole,
      text: offerText,
      messageType: 'offer',
      offerPrice: parseFloat(price),
      offerStatus: 'pending',
      note: note?.trim() || null,
      createdAt: new Date().toISOString()
    };

    // Real-time socket event
    const io = req.app.get('io');
    if (io) {
      io.to(targetRoom).emit('new_offer', formattedOffer);
      io.to(targetRoom).emit('statusUpdate', { status: 'Negotiation' });
    }

    // Notification
    const label = shipmentId ? `شحنة #${entityNum}` : `طلب #${entityNum}`;
    const isAdminSending = senderRole === 'admin' || senderRole === 'employee';
    const notifTitle = isAdminSending ? '💰 عرض سعر جديد من الإدارة' : '💰 عرض سعر من التاجر';
    const notifBody = isAdminSending
      ? `تم اقتراح سعر توصيل جديد لـ${label}: ${price} ج.م${note ? ` — ${note}` : ''}`
      : `أرسل التاجر عرض سعر جديد لـ${label}: ${price} ج.م`;

    await sendNotification(io, receiverId, notifTitle, notifBody, 'offer', {
      type: 'negotiation_offer',
      shipmentId: shipmentId ? shipmentId.toString() : '',
      orderId: orderId ? orderId.toString() : '',
      offerId: adminMessageId.toString(),
      price: price.toString(),
      note: note?.trim() || ''
    });

    res.status(201).json({ status: 1, message: 'تم إرسال عرض السعر بنجاح', data: formattedOffer });
  } catch (error) {
    next(error);
  }
};

// ─── 2. ACCEPT A PRICE OFFER ─────────────────────────────────────────────────
const acceptOffer = async (req, res, next) => {
  try {
    const pool = getPool();
    const { messageId } = req.body;

    if (!messageId) {
      return res.status(400).json({ status: 0, message: 'معرف العرض مطلوب' });
    }

    const [messages] = await pool.query('SELECT * FROM messages WHERE id = ?', [messageId]);
    if (messages.length === 0) {
      return res.status(404).json({ status: 0, message: 'العرض غير موجود' });
    }
    const msg = messages[0];

    if (msg.messageType !== 'offer' || msg.offerStatus !== 'pending') {
      return res.status(400).json({ status: 0, message: 'هذا العرض غير صالح أو تم معالجته مسبقاً' });
    }

    const { shipmentId, orderId } = msg;
    const loaded = await loadEntityForNegotiation(pool, { shipmentId, orderId });
    if (!loaded) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    assertEntityAccess(loaded.kind, loaded.entity, req.user);
    assertCanRespondToOffer(msg, loaded.entity, req.user);

    const finalPrice = parseFloat(msg.offerPrice);
    const platformShare = finalPrice * 0.20;
    const captainShare = finalPrice * 0.80;

    const nextStatus = 'Ready For Assignment';

    // Mark this offer accepted, all others rejected
    await pool.query("UPDATE messages SET offerStatus = 'accepted' WHERE id = ?", [messageId]);
    if (shipmentId) {
      await pool.query(
        "UPDATE messages SET offerStatus = 'rejected' WHERE shipmentId = ? AND id != ? AND messageType = 'offer' AND offerStatus = 'pending'",
        [shipmentId, messageId]
      );
      await pool.query(
        'UPDATE shipments SET price = ?, platformShare = ?, captainShare = ?, status = ? WHERE id = ?',
        [finalPrice, platformShare, captainShare, nextStatus, shipmentId]
      );
    } else {
      await pool.query(
        "UPDATE messages SET offerStatus = 'rejected' WHERE orderId = ? AND id != ? AND messageType = 'offer' AND offerStatus = 'pending'",
        [orderId, messageId]
      );
      await pool.query(
        'UPDATE orders SET deliveryFee = ?, platformShare = ?, captainShare = ?, status = ? WHERE id = ?',
        [finalPrice, platformShare, captainShare, nextStatus, orderId]
      );
    }

    if (nextStatus === 'Ready For Assignment') {
      const { triggerAutoAssignment } = require('../utils/autoAssignment');
      triggerAutoAssignment(shipmentId || null, orderId || null).catch(err =>
        console.error('Error triggering auto assignment after negotiation offer acceptance:', err.message)
      );
    }

    const targetRoom = shipmentId ? `shipment_${shipmentId}` : `order_${orderId}`;
    const io = req.app.get('io');
    if (io) {
      io.to(targetRoom).emit('statusUpdate', { status: nextStatus });
      io.to(targetRoom).emit('offer_accepted', { messageId: messageId.toString(), price: finalPrice });
    }

    // Notify the offer sender
    await sendNotification(
      io, msg.senderId,
      '✅ تم قبول عرض السعر',
      `تم قبول عرض السعر الخاص بك بقيمة ${finalPrice} ج.م. الحالة الجديدة: بانتظار تعيين مندوب`,
      'offer',
      {
        type: 'offer_accepted',
        shipmentId: shipmentId ? shipmentId.toString() : '',
        orderId: orderId ? orderId.toString() : '',
        price: finalPrice.toString(),
        status: nextStatus
      }
    );

    res.status(200).json({
      status: 1,
      message: 'تم قبول عرض السعر بنجاح',
      data: { status: nextStatus, price: finalPrice }
    });
  } catch (error) {
    next(error);
  }
};

// ─── 3. SUBMIT COUNTER OFFER ──────────────────────────────────────────────────
const submitCounterOffer = async (req, res, next) => {
  try {
    const pool = getPool();
    const senderId = req.user.id;
    const { messageId, shipmentId, orderId, price, note } = req.body;

    if (!messageId) {
      return res.status(400).json({ status: 0, message: 'معرف العرض الأصلي مطلوب' });
    }
    if (!price || parseFloat(price) <= 0) {
      return res.status(400).json({ status: 0, message: 'سعر العرض يجب أن يكون أكبر من الصفر' });
    }
    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }

    // Load original offer to verify it exists and is pending
    const [originalMessages] = await pool.query('SELECT * FROM messages WHERE id = ?', [messageId]);
    if (originalMessages.length === 0) {
      return res.status(404).json({ status: 0, message: 'العرض الأصلي غير موجود' });
    }
    const original = originalMessages[0];
    if (original.messageType !== 'offer' || original.offerStatus !== 'pending') {
      return res.status(400).json({ status: 0, message: 'لا يمكن تقديم عرض مضاد لهذا العرض (تم قبوله أو رفضه أو لم يكن صالحاً)' });
    }

    const loaded = await loadEntityForNegotiation(pool, { shipmentId, orderId });
    if (!loaded) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    assertEntityAccess(loaded.kind, loaded.entity, req.user);
    assertNegotiationSubmitRole(req.user);

    // Only the intended receiver can submit a counter-offer
    if (Number(original.receiverId) !== Number(senderId)) {
      return res.status(403).json({ status: 0, message: 'غير مصرح لك بتقديم عرض مضاد لهذا العرض' });
    }

    const parties = await resolveParties(pool, req, { shipmentId, orderId });
    if (!parties) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    const { targetRoom, receiverId, entityNum } = parties;

    // Sender details (original offer sender)
    const [senderRows] = await pool.query(
      'SELECT firstName, lastName, role FROM users WHERE id = ?',
      [senderId]
    );
    const senderName = senderRows.length > 0
      ? `${senderRows[0].firstName} ${senderRows[0].lastName}`
      : 'التاجر';
    const senderRole = senderRows.length > 0 ? senderRows[0].role : 'merchant';

    const counterOfferText = note?.trim()
      ? `عرض سعر (مضاد): ${price} ج.م — ${note.trim()}`
      : `عرض سعر مضاد بقيمة ${price} ج.م`;

    // Insert counter-offer record
    const [result] = await pool.query(
      `INSERT INTO messages (shipmentId, orderId, senderId, receiverId, text, messageType, offerPrice, offerStatus, note)
       VALUES (?, ?, ?, ?, ?, 'offer', ?, 'pending', ?)`,
      [
        shipmentId ? parseInt(shipmentId) : null,
        orderId ? parseInt(orderId) : null,
        senderId,
        receiverId,
        counterOfferText,
        parseFloat(price),
        note?.trim() || null
      ]
    );
    const counterOfferId = result.insertId;

    // Update original offer to rejected
    await pool.query("UPDATE messages SET offerStatus = 'rejected' WHERE id = ?", [original.id]);

    // Update entity status → Negotiation (same as when new offer is submitted)
    if (shipmentId) {
      await pool.query("UPDATE shipments SET status = 'Negotiation' WHERE id = ?", [shipmentId]);
    } else {
      await pool.query("UPDATE orders SET status = 'Negotiation' WHERE id = ?", [orderId]);
    }

    const formattedOffer = {
      id: counterOfferId.toString(),
      shipmentId: shipmentId ? shipmentId.toString() : null,
      orderId: orderId ? orderId.toString() : null,
      senderId: senderId.toString(),
      receiverId: receiverId.toString(),
      senderName,
      senderRole,
      text: counterOfferText,
      messageType: 'offer',
      offerPrice: parseFloat(price),
      offerStatus: 'pending',
      note: note?.trim() || null,
      createdAt: new Date().toISOString()
    };

    // Real-time socket event
    const io = req.app.get('io');
    if (io) {
      io.to(targetRoom).emit('new_offer', formattedOffer);
      io.to(targetRoom).emit('statusUpdate', { status: 'Negotiation' });
    }

    // Notification to the original offer sender (admin/employee)
    const label = shipmentId ? `شحنة #${entityNum}` : `طلب #${entityNum}`;
    const isAdminSending = senderRole === 'admin' || senderRole === 'employee';
    const notifTitle = isAdminSending
      ? `💰 عرض مضاد جديد من ${senderName}`
      : `💰 لديك عرض مضاد جديد من ${senderName}`;
    const notifBody = isAdminSending
      ? `التاجر ${senderName} قدم عرضاً مضاداً بقيمة ${price} ج.م لـ${label}${note ? ` — ${note}` : ''}`
      : `تم تقديم عرض مضاد جديد من قبلك بقيمة ${price} ج.م لـ${label}`;

    await sendNotification(io, receiverId, notifTitle, notifBody, 'counter_offer', {
      type: 'counter_offer_submitted',
      shipmentId: shipmentId ? shipmentId.toString() : '',
      orderId: orderId ? orderId.toString() : '',
      offerId: counterOfferId.toString(),
      price: price.toString(),
      note: note?.trim() || ''
    });

    res.status(201).json({ status: 1, message: '✅ تم إرسال العرض المضاد بنجاح', data: formattedOffer });
  } catch (error) {
    next(error);
  }
};

// ─── 4. REJECT A PRICE OFFER → returns to Pending Review ────────────────────
const rejectOffer = async (req, res, next) => {
  try {
    const pool = getPool();
    const { messageId } = req.body;

    if (!messageId) {
      return res.status(400).json({ status: 0, message: 'معرف العرض مطلوب' });
    }

    const [messages] = await pool.query('SELECT * FROM messages WHERE id = ?', [messageId]);
    if (messages.length === 0) {
      return res.status(404).json({ status: 0, message: 'العرض غير موجود' });
    }
    const msg = messages[0];

    if (msg.messageType !== 'offer' || msg.offerStatus !== 'pending') {
      return res.status(400).json({ status: 0, message: 'هذا العرض غير صالح أو تم معالجته مسبقاً' });
    }

    const { shipmentId, orderId } = msg;
    const loaded = await loadEntityForNegotiation(pool, { shipmentId, orderId });
    if (!loaded) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    assertEntityAccess(loaded.kind, loaded.entity, req.user);
    assertCanRespondToOffer(msg, loaded.entity, req.user);

    await pool.query("UPDATE messages SET offerStatus = 'rejected' WHERE id = ?", [messageId]);

    // Return entity to Pending Review so admin can re-evaluate
    if (shipmentId) {
      await pool.query("UPDATE shipments SET status = 'Pending Review' WHERE id = ?", [shipmentId]);
    } else {
      await pool.query("UPDATE orders SET status = 'Pending Review' WHERE id = ?", [orderId]);
    }

    const targetRoom = shipmentId ? `shipment_${shipmentId}` : `order_${orderId}`;
    const io = req.app.get('io');
    if (io) {
      io.to(targetRoom).emit('statusUpdate', { status: 'Pending Review' });
      io.to(targetRoom).emit('offer_rejected', { messageId: messageId.toString() });
    }

    // Notify the offer sender (admin/employee)
    await sendNotification(
      io, msg.senderId,
      '❌ تم رفض عرض السعر',
      `رفض التاجر عرض السعر بقيمة ${msg.offerPrice} ج.م. تم إعادة الطلب إلى قائمة المراجعة.`,
      'offer',
      {
        type: 'offer_rejected',
        shipmentId: shipmentId ? shipmentId.toString() : '',
        orderId: orderId ? orderId.toString() : '',
        offerId: messageId.toString()
      }
    );

    res.status(200).json({
      status: 1,
      message: 'تم رفض العرض وإعادة الطلب إلى قائمة المراجعة',
      data: { status: 'Pending Review' }
    });
  } catch (error) {
    next(error);
  }
};

// ─── 5. GET OFFER HISTORY (Timeline) ─────────────────────────────────────────
const getOffers = async (req, res, next) => {
  try {
    const pool = getPool();
    const { shipmentId, orderId } = req.query;

    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو الطلب' });
    }

    const loaded = await loadEntityForNegotiation(pool, { shipmentId, orderId });
    if (!loaded) {
      return res.status(404).json({ status: 0, message: 'الشحنة أو الطلب غير موجود' });
    }
    assertEntityAccess(loaded.kind, loaded.entity, req.user);

    let query = `
      SELECT m.id, m.shipmentId, m.orderId, m.senderId, m.receiverId,
             m.offerPrice, m.offerStatus, m.note, m.createdAt,
             CONCAT(u.firstName, ' ', u.lastName) AS senderName,
             u.role AS senderRole, u.profileImage AS senderAvatar
      FROM messages m
      LEFT JOIN users u ON m.senderId = u.id
      WHERE m.messageType = 'offer'
    `;
    const params = [];

    if (shipmentId) {
      query += ' AND m.shipmentId = ?';
      params.push(shipmentId);
    } else {
      query += ' AND m.orderId = ?';
      params.push(orderId);
    }
    query += ' ORDER BY m.createdAt ASC';

    const [rows] = await pool.query(query, params);

    const formatted = rows.map((m) => ({
      id: m.id.toString(),
      shipmentId: m.shipmentId ? m.shipmentId.toString() : null,
      orderId: m.orderId ? m.orderId.toString() : null,
      senderId: m.senderId.toString(),
      receiverId: m.receiverId.toString(),
      senderName: m.senderName,
      senderRole: m.senderRole,
      senderAvatar: m.senderAvatar || '',
      offerPrice: m.offerPrice ? parseFloat(m.offerPrice) : null,
      offerStatus: m.offerStatus,
      note: m.note || null,
      createdAt: m.createdAt instanceof Date ? m.createdAt.toISOString() : m.createdAt
    }));

    res.status(200).json({ status: 1, data: formatted });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  submitOffer,
  submitCounterOffer,
  acceptOffer,
  rejectOffer,
  getOffers
};
