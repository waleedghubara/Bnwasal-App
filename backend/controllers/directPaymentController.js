const { getPool } = require('../config/db');
const path = require('path');
const fs = require('fs');

// ─── GET PAYMENT METHODS (public) ─────────────────────────────────────────────
const getPaymentMethods = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'payment_methods'");
    let methods = [];
    if (rows.length > 0 && rows[0].value) {
      try { methods = JSON.parse(rows[0].value); } catch (_) {}
    }
    res.status(200).json({ status: 1, data: { methods } });
  } catch (error) {
    next(error);
  }
};

// ─── UPDATE PAYMENT METHODS (admin only) ──────────────────────────────────────
const updatePaymentMethods = async (req, res, next) => {
  try {
    const pool = getPool();
    const { methods } = req.body;
    if (!Array.isArray(methods)) {
      return res.status(400).json({ status: 0, message: 'methods يجب أن يكون مصفوفة' });
    }
    const value = JSON.stringify(methods);
    await pool.query(
      "INSERT INTO app_settings (`key`, `value`) VALUES ('payment_methods', ?) ON DUPLICATE KEY UPDATE `value` = ?",
      [value, value]
    );
    res.status(200).json({ status: 1, message: 'تم تحديث طرق الدفع بنجاح' });
  } catch (error) {
    next(error);
  }
};

// ─── SUBMIT DIRECT PAYMENT RECEIPT (merchant) ─────────────────────────────────
const submitDirectPayment = async (req, res, next) => {
  try {
    const pool = getPool();
    const merchantId = req.user.id;
    const { orderId, shipmentId, paymentMethod, fromPhone, fromName } = req.body;

    if (!orderId && !shipmentId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }
    if (!paymentMethod || !fromPhone || !fromName) {
      return res.status(400).json({ status: 0, message: 'جميع الحقول مطلوبة' });
    }
    if (!req.file) {
      return res.status(400).json({ status: 0, message: 'صورة الإيصال مطلوبة' });
    }

    // Validate the order/shipment belongs to this merchant and is in payable status
    let fee = 0;
    let itemNumber = '';
    if (orderId) {
      const [orders] = await pool.query(
        'SELECT deliveryFee, status, orderNumber, merchantId FROM orders WHERE id = ?',
        [orderId]
      );
      if (orders.length === 0) return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
      if (String(orders[0].merchantId) !== String(merchantId)) {
        return res.status(403).json({ status: 0, message: 'غير مصرح لك بدفع رسوم هذا الطلب' });
      }
      fee = parseFloat(orders[0].deliveryFee);
      itemNumber = orders[0].orderNumber;
    } else {
      const [shipments] = await pool.query(
        'SELECT price, status, shipmentNumber, merchantId FROM shipments WHERE id = ?',
        [shipmentId]
      );
      if (shipments.length === 0) return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
      if (String(shipments[0].merchantId) !== String(merchantId)) {
        return res.status(403).json({ status: 0, message: 'غير مصرح لك بدفع رسوم هذه الشحنة' });
      }
      fee = parseFloat(shipments[0].price);
      itemNumber = shipments[0].shipmentNumber;
    }

    // Check if there's already a pending payment for this order/shipment
    const pendingCheck = orderId
      ? await pool.query("SELECT id FROM direct_payments WHERE orderId = ? AND status = 'pending'", [orderId])
      : await pool.query("SELECT id FROM direct_payments WHERE shipmentId = ? AND status = 'pending'", [shipmentId]);
    if (pendingCheck[0].length > 0) {
      return res.status(400).json({
        status: 0,
        message: 'يوجد طلب دفع معلق بالفعل لهذا الطلب، يرجى انتظار مراجعة الإدارة'
      });
    }

    const paymentRef = `PAY-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`;
    const receiptImage = req.file.filename;

    await pool.query(
      `INSERT INTO direct_payments (paymentRef, merchantId, orderId, shipmentId, amount, paymentMethod, fromPhone, fromName, receiptImage)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        paymentRef,
        merchantId,
        orderId || null,
        shipmentId || null,
        fee,
        paymentMethod,
        fromPhone,
        fromName,
        receiptImage,
      ]
    );

    // Notify admin via socket
    const io = req.app.get('io');
    if (io) {
      io.to('admins').emit('new_direct_payment', {
        paymentRef,
        amount: fee,
        itemNumber,
        paymentMethod,
      });
      const roomName = shipmentId ? `shipment_${shipmentId}` : `order_${orderId}`;
      io.to(roomName).emit('payment_submitted', { paymentRef });
    }

    // Notify admins via push/db/socket
    try {
      const [merchantRows] = await pool.query('SELECT storeName, firstName, lastName FROM users WHERE id = ?', [merchantId]);
      const merchant = merchantRows[0];
      const merchantName = merchant ? (merchant.storeName || `${merchant.firstName} ${merchant.lastName}`) : 'تاجر';
      
      const { notifyAdmins } = require('../utils/adminNotifier');
      const itemType = shipmentId ? 'شحنة' : 'طلب';
      await notifyAdmins(
        io,
        `🧾 إيصال دفع مباشر جديد`,
        `قام التاجر ${merchantName} برفع إيصال دفع مباشر بقيمة ${fee} ج.م للـ ${itemType} رقم #${itemNumber} (${paymentMethod}).`,
        'payment',
        {
          type: 'direct_payment_submitted',
          shipmentId: shipmentId ? shipmentId.toString() : '',
          orderId: orderId ? orderId.toString() : '',
          itemNumber: itemNumber.toString(),
          amount: fee.toString(),
          paymentRef,
          merchantId: merchantId.toString()
        }
      );
    } catch (err) {
      console.error('Error sending direct payment submission notification to admins:', err);
    }

    res.status(201).json({
      status: 1,
      message: 'تم إرسال إيصال الدفع بنجاح، يرجى انتظار موافقة الإدارة',
      data: { paymentRef },
    });
  } catch (error) {
    next(error);
  }
};

// ─── CHECK PAYMENT STATUS (merchant, polling) ──────────────────────────────────
const checkPaymentStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { paymentRef } = req.params;
    const merchantId = req.user.id;

    const [rows] = await pool.query(
      'SELECT status, adminNote FROM direct_payments WHERE paymentRef = ? AND merchantId = ?',
      [paymentRef, merchantId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ status: 0, message: 'طلب الدفع غير موجود' });
    }

    res.status(200).json({ status: 1, data: rows[0] });
  } catch (error) {
    next(error);
  }
};

// ─── LIST ALL DIRECT PAYMENTS (admin) ─────────────────────────────────────────
const listDirectPayments = async (req, res, next) => {
  try {
    const pool = getPool();
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let whereClause = '';
    const params = [];
    if (status) {
      whereClause = 'WHERE dp.status = ?';
      params.push(status);
    }

    const [rows] = await pool.query(
      `SELECT 
        dp.*,
        u.firstName, u.lastName, u.phone, u.email, u.profileImage,
        u.storeName,
        o.orderNumber, o.details as orderDetails,
        s.shipmentNumber, s.title as shipmentTitle
       FROM direct_payments dp
       JOIN users u ON u.id = dp.merchantId
       LEFT JOIN orders o ON o.id = dp.orderId
       LEFT JOIN shipments s ON s.id = dp.shipmentId
       ${whereClause}
       ORDER BY dp.createdAt DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    const [countRows] = await pool.query(
      `SELECT COUNT(*) as total FROM direct_payments dp ${whereClause}`,
      params
    );

    const total = countRows[0].total;

    res.status(200).json({
      status: 1,
      data: {
        payments: rows,
        total,
        page: parseInt(page),
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── APPROVE / REJECT DIRECT PAYMENT (admin) ──────────────────────────────────
const reviewDirectPayment = async (req, res, next) => {
  try {
    const pool = getPool();
    const { id } = req.params;
    const { action, adminNote } = req.body; // action: 'approve' | 'reject'

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ status: 0, message: 'الإجراء يجب أن يكون approve أو reject' });
    }

    const [payments] = await pool.query(
      'SELECT * FROM direct_payments WHERE id = ?',
      [id]
    );
    if (payments.length === 0) {
      return res.status(404).json({ status: 0, message: 'طلب الدفع غير موجود' });
    }

    const payment = payments[0];
    if (payment.status !== 'pending') {
      return res.status(400).json({ status: 0, message: 'تم البت في هذا الطلب مسبقاً' });
    }

    let itemNumber = '';
    let itemType = '';
    if (payment.orderId) {
      const [orderRows] = await pool.query('SELECT orderNumber FROM orders WHERE id = ?', [payment.orderId]);
      if (orderRows.length > 0) {
        itemNumber = orderRows[0].orderNumber;
        itemType = 'طلب';
      }
    } else if (payment.shipmentId) {
      const [shipmentRows] = await pool.query('SELECT shipmentNumber FROM shipments WHERE id = ?', [payment.shipmentId]);
      if (shipmentRows.length > 0) {
        itemNumber = shipmentRows[0].shipmentNumber;
        itemType = 'شحنة';
      }
    }

    const newStatus = action === 'approve' ? 'approved' : 'rejected';

    let captainId = null;
    let nextStatus = 'Ready For Assignment';

    if (action === 'approve') {
      // Use a transaction to approve payment and update order/shipment status
      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();

        await conn.query(
          'UPDATE direct_payments SET status = ?, adminNote = ? WHERE id = ?',
          [newStatus, adminNote || null, id]
        );

        // Determine next status for order/shipment
        const [settings] = await conn.query("SELECT `value` FROM app_settings WHERE `key` = 'fee_collection_mode'");
        const mode = settings.length > 0 ? settings[0].value : 'after_agreement';

        if (payment.orderId) {
          const [orderRows] = await conn.query('SELECT captainId FROM orders WHERE id = ?', [payment.orderId]);
          if (orderRows.length > 0 && orderRows[0].captainId) {
            captainId = orderRows[0].captainId;
            nextStatus = 'Assigned To Captain';
          }
          await conn.query('UPDATE orders SET status = ?, isPaid = 1 WHERE id = ?', [nextStatus, payment.orderId]);
        } else if (payment.shipmentId) {
          const [shipRows] = await conn.query('SELECT captainId FROM shipments WHERE id = ?', [payment.shipmentId]);
          if (shipRows.length > 0 && shipRows[0].captainId) {
            captainId = shipRows[0].captainId;
            nextStatus = 'Assigned To Captain';
          }
          await conn.query('UPDATE shipments SET status = ?, isPaid = 1 WHERE id = ?', [nextStatus, payment.shipmentId]);
        }

        await conn.commit();

        if (nextStatus === 'Ready For Assignment') {
          const { triggerAutoAssignment } = require('../utils/autoAssignment');
          triggerAutoAssignment(payment.shipmentId || null, payment.orderId || null).catch(err => 
            console.error('Error triggering auto assignment after direct payment approval:', err.message)
          );
        }

        // Notify the merchant via socket
        const io = req.app.get('io');
        if (io) {
          const merchantRoom = `user_${payment.merchantId}`;
          io.to(merchantRoom).emit('direct_payment_approved', {
            paymentRef: payment.paymentRef,
            orderId: payment.orderId,
            shipmentId: payment.shipmentId,
          });
          if (payment.orderId) {
            io.to(`order_${payment.orderId}`).emit('payment_received', { fee: payment.amount });
            io.to(`order_${payment.orderId}`).emit('statusUpdate', { status: nextStatus });
          } else {
            io.to(`shipment_${payment.shipmentId}`).emit('payment_received', { fee: payment.amount });
            io.to(`shipment_${payment.shipmentId}`).emit('statusUpdate', { status: nextStatus });
          }
          io.to('admins').emit('dashboard_update');
        }

        const { sendNotification } = require('../utils/notificationDispatcher');

        // Notify merchant via push/db/socket
        try {
          await sendNotification(
            io,
            payment.merchantId,
            `✅ تم قبول إيصال الدفع`,
            `تمت الموافقة على إيصال الدفع الخاص بالـ ${itemType} رقم #${itemNumber} بقيمة ${payment.amount} ج.م.`,
            'payment',
            {
              type: 'direct_payment_approved',
              shipmentId: payment.shipmentId ? payment.shipmentId.toString() : '',
              orderId: payment.orderId ? payment.orderId.toString() : '',
              itemNumber: itemNumber.toString(),
              amount: payment.amount.toString(),
              paymentRef: payment.paymentRef,
              nextStatus
            }
          );
        } catch (err) {
          console.error('Error sending direct payment approval notification to merchant:', err);
        }

        // Notify captain if assigned
        if (captainId) {
          try {
            await sendNotification(
              io,
              captainId,
              `📋 تم تعيينك لتوصيل شحنة`,
              `تم دفع الرسوم وتعيينك لتوصيل الـ ${itemType} رقم #${itemNumber}.`,
              'shipment_assigned',
              {
                type: 'shipment_assigned',
                shipmentId: payment.shipmentId ? payment.shipmentId.toString() : '',
                orderId: payment.orderId ? payment.orderId.toString() : '',
                itemNumber: itemNumber.toString(),
                amount: payment.amount.toString(),
                paymentRef: payment.paymentRef,
              }
            );
          } catch (err) {
            console.error('Error sending direct payment assignment notification to captain:', err);
          }
        }
      } catch (err) {
        await conn.rollback();
        throw err;
      } finally {
        conn.release();
      }
    } else {
      // Reject only
      await pool.query(
        'UPDATE direct_payments SET status = ?, adminNote = ? WHERE id = ?',
        [newStatus, adminNote || null, id]
      );

      const io = req.app.get('io');
      if (io) {
        const merchantRoom = `user_${payment.merchantId}`;
        io.to(merchantRoom).emit('direct_payment_rejected', {
          paymentRef: payment.paymentRef,
          adminNote,
        });
      }

      // Notify merchant via push/db/socket
      try {
        const { sendNotification } = require('../utils/notificationDispatcher');
        const reasonText = adminNote ? ` السبب: ${adminNote}` : '';
        await sendNotification(
          io,
          payment.merchantId,
          `❌ تم رفض إيصال الدفع`,
          `تم رفض إيصال الدفع الخاص بالـ ${itemType} رقم #${itemNumber} بقيمة ${payment.amount} ج.م.${reasonText}`,
          'payment',
          {
            type: 'direct_payment_rejected',
            shipmentId: payment.shipmentId ? payment.shipmentId.toString() : '',
            orderId: payment.orderId ? payment.orderId.toString() : '',
            itemNumber: itemNumber.toString(),
            amount: payment.amount.toString(),
            paymentRef: payment.paymentRef,
            adminNote: adminNote || ''
          }
        );
      } catch (err) {
        console.error('Error sending direct payment rejection notification to merchant:', err);
      }
    }

    res.status(200).json({
      status: 1,
      message: action === 'approve' ? '✅ تم قبول الدفع وتحديث حالة الطلب' : '❌ تم رفض الدفع',
    });
  } catch (error) {
    next(error);
  }
};

// ─── UPLOAD PAYMENT METHOD ICON (admin only) ─────────────────────────────────
const uploadMethodIcon = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ status: 0, message: 'لم يتم رفع أي صورة' });
    }
    // Return a publicly accessible URL for the uploaded icon
    const imageUrl = `/uploads/payment-icons/${req.file.filename}`;
    res.status(200).json({
      status: 1,
      message: 'تم رفع الأيقونة بنجاح',
      data: { imageUrl },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getPaymentMethods,
  updatePaymentMethods,
  uploadMethodIcon,
  submitDirectPayment,
  checkPaymentStatus,
  listDirectPayments,
  reviewDirectPayment,
};
