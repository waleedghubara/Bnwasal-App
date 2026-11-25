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
    const { orderId, shipmentId, paymentMethod, fromPhone, fromName, amount } = req.body;
    const isWalletDeposit = (!orderId && !shipmentId) || req.body.type === 'deposit' || req.body.isWalletDeposit === true || req.body.isWalletDeposit === 'true';

    if (!isWalletDeposit && !orderId && !shipmentId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب أو تحديد مبلغ الإيداع' });
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
    if (isWalletDeposit) {
      const userRole = (req.user.role || '').toLowerCase();
      if (userRole !== 'client' && userRole !== 'merchant') {
        return res.status(403).json({ status: 0, message: 'خاصية الإيداع متاحة للعملاء والتجار فقط.' });
      }
      const parsedAmount = parseFloat(amount);
      if (!parsedAmount || isNaN(parsedAmount) || parsedAmount < 1) {
        return res.status(400).json({ status: 0, message: 'يرجى إدخال مبلغ صحيح للإيداع (الحد الأدنى 1 ج.م)' });
      }
      fee = parsedAmount;
      itemNumber = `DEP-${Date.now()}`;
    } else if (orderId) {
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
    if (!isWalletDeposit) {
      const pendingCheck = orderId
        ? await pool.query("SELECT id FROM direct_payments WHERE orderId = ? AND status = 'pending'", [orderId])
        : await pool.query("SELECT id FROM direct_payments WHERE shipmentId = ? AND status = 'pending'", [shipmentId]);
      if (pendingCheck[0].length > 0) {
        return res.status(400).json({
          status: 0,
          message: 'يوجد طلب دفع معلق بالفعل لهذا الطلب، يرجى انتظار مراجعة الإدارة'
        });
      }
    }

    const paymentRef = isWalletDeposit
      ? `DEP-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`
      : `PAY-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`;
    const receiptImage = req.file.filename;

    await pool.query(
      `INSERT INTO direct_payments (paymentRef, merchantId, clientId, orderId, shipmentId, amount, paymentMethod, fromPhone, fromName, receiptImage)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        paymentRef,
        merchantId,
        isWalletDeposit ? merchantId : null,
        isWalletDeposit ? null : (orderId || null),
        isWalletDeposit ? null : (shipmentId || null),
        fee,
        paymentMethod,
        fromPhone,
        fromName,
        receiptImage,
      ]
    );

    if (isWalletDeposit) {
      await pool.query(
        `INSERT INTO wallet_transactions (userId, title, amount, type, status, reference, category, paymentMethod, accountDetails)
         VALUES (?, ?, ?, 'deposit', 'pending', ?, 'deposits', ?, ?)`,
        [
          merchantId,
          `طلب إيداع عبر ${paymentMethod}`,
          fee,
          paymentRef,
          paymentMethod,
          JSON.stringify({ fromPhone, fromName, receiptImage })
        ]
      );
    }

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

// ─── CHECK PAYMENT STATUS (merchant & client, polling) ─────────────────────────
const checkPaymentStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const { paymentRef } = req.params;
    const userId = req.user.id;

    const [rows] = await pool.query(
      `SELECT dp.status, dp.adminNote, dp.orderId, dp.shipmentId, dp.amount, dp.paymentMethod,
              o.orderNumber, o.status as orderStatus
       FROM direct_payments dp
       LEFT JOIN orders o ON o.id = dp.orderId
       WHERE dp.paymentRef = ? AND (dp.merchantId = ? OR dp.clientId = ?)`,
      [paymentRef, userId, userId]
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
        CASE WHEN dp.clientId IS NOT NULL THEN c.firstName ELSE u.firstName END as firstName,
        CASE WHEN dp.clientId IS NOT NULL THEN c.lastName ELSE u.lastName END as lastName,
        CASE WHEN dp.clientId IS NOT NULL THEN c.phone ELSE u.phone END as phone,
        CASE WHEN dp.clientId IS NOT NULL THEN c.email ELSE u.email END as email,
        CASE WHEN dp.clientId IS NOT NULL THEN c.profileImage ELSE u.profileImage END as profileImage,
        CONCAT(c.firstName, ' ', c.lastName) as clientName,
        c.phone as clientPhone,
        COALESCE(NULLIF(u.storeName, ''), CONCAT(u.firstName, ' ', u.lastName), 'متجر') as storeName,
        u.phone as storePhone,
        o.orderNumber, o.details as orderDetails, o.status as orderStatus, o.deliveryAddress,
        s.shipmentNumber, s.title as shipmentTitle
       FROM direct_payments dp
       LEFT JOIN users u ON u.id = dp.merchantId
       LEFT JOIN users c ON c.id = dp.clientId
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

        if (!payment.orderId && !payment.shipmentId) {
          // DIRECT WALLET DEPOSIT APPROVAL
          const depositAmount = parseFloat(payment.amount);
          const targetUserId = payment.clientId || payment.merchantId;

          await conn.query(
            'UPDATE users SET walletBalance = walletBalance + ? WHERE id = ?',
            [depositAmount, targetUserId]
          );

          await conn.query(
            `UPDATE wallet_transactions 
             SET status = 'success' 
             WHERE reference = ? OR (userId = ? AND amount = ? AND type = 'deposit' AND status = 'pending' ORDER BY id DESC LIMIT 1)`,
            [payment.paymentRef, targetUserId, depositAmount]
          );

          await conn.commit();

          const io = req.app.get('io') || global.io;
          if (io) {
            const [balRows] = await pool.query('SELECT walletBalance FROM users WHERE id = ?', [targetUserId]);
            const newBal = balRows.length > 0 ? parseFloat(balRows[0].walletBalance) : 0;
            io.to(`user_${targetUserId}`).emit('wallet_updated', {
              newBalance: newBal,
              depositAmount,
              message: `تم إضافة ${depositAmount} جنيه لمحفظتك بنجاح 🎉`,
            });
            io.to(`user_${targetUserId}`).emit('direct_payment_approved', {
              paymentRef: payment.paymentRef,
              amount: depositAmount,
              type: 'wallet_deposit',
            });
            io.to('admins').emit('dashboard_update');
          }

          const { sendNotification } = require('../utils/notificationDispatcher');
          try {
            await sendNotification(
              io,
              targetUserId,
              'إيداع ناجح بنجاح 🎉',
              `تم شحن رصيد محفظتك بمبلغ ${depositAmount} جنيه عبر ${payment.paymentMethod} بنجاح.`,
              'wallet',
              { type: 'deposit_success', amount: depositAmount.toString() }
            );
          } catch (e) {
            console.error('Notification error:', e);
          }

          return res.status(200).json({
            status: 1,
            message: `✅ تم قبول الإيداع وإضافة ${depositAmount} جنيه لمحفظة المستخدم بنجاح`,
          });
        }

        if (payment.orderId) {
          const [orderRows] = await conn.query('SELECT * FROM orders WHERE id = ?', [payment.orderId]);
          if (orderRows.length > 0) {
            const o = orderRows[0];
            const isStoreOrder = o.orderType === 'store' || o.storeId != null;

            const discountApplied = parseFloat(o.discountApplied || 0);
            const serviceFee = parseFloat(o.serviceFee || 0);
            const orderPrice = parseFloat(o.orderPrice || 0);
            const deliveryFee = parseFloat(o.deliveryFee || 0);
            const tip = parseFloat(o.tip || 0);
            const totalAmount = Math.max(0, parseFloat((orderPrice + deliveryFee + serviceFee + tip - discountApplied).toFixed(2)));

            if (isStoreOrder) {
              nextStatus = 'قيد المراجعة';
              await conn.query(
                `UPDATE orders 
                 SET status = 'قيد المراجعة', 
                     isPaid = 1, 
                     paymentStatus = 'paid', 
                     storeOrderStatus = 'under_review', 
                     captainTripStatus = 'PENDING_ASSIGNMENT' 
                 WHERE id = ?`,
                [payment.orderId]
              );

              // Notify Admin: payment approved, now under review to confirm with merchant & send
              const io = req.app.get('io');
              if (io) {
                const orderEventPayload = {
                  orderId: o.id.toString(),
                  id: o.id.toString(),
                  orderNumber: o.orderNumber,
                  shipmentId: null,
                  shiftId: o.shift_id ? o.shift_id.toString() : null,
                  captainId: null,
                  orderType: 'store',
                  status: 'قيد المراجعة',
                  storeOrderStatus: 'under_review',
                  merchantId: (o.merchantId || o.storeId || '').toString(),
                  storeName: o.storeDescription || 'متجر',
                  clientName: o.clientName,
                  phone: o.phone,
                  deliveryAddress: o.deliveryAddress,
                  orderPrice,
                  deliveryFee,
                  serviceFee,
                  tip,
                  discountApplied,
                  couponCode: o.couponCode || null,
                  totalAmount,
                  scheduleType: o.scheduleType,
                  scheduledAt: o.scheduledAt,
                  createdAt: new Date().toISOString()
                };

                io.to('admins').emit('ORDER_CREATED', orderEventPayload);
                io.to('admins').emit('order_created', orderEventPayload);
                io.to('admins').emit('new_store_order', orderEventPayload);
                io.to('admins').emit('store_order_created', orderEventPayload);
                io.to('admins').emit('dashboard_update');

                try {
                  const { notifyAdmins } = require('../utils/adminNotifier');
                  await notifyAdmins(
                    io,
                    'تم اعتماد الدفع لطلب متجر (قيد المراجعة) 🔔',
                    `تم اعتماد إيصال الدفع للطلب رقم #${o.orderNumber}. يرجى تأكيد الطلب مع المتجر والضغط على "إرسال الطلب للمتجر".`,
                    'order',
                    {
                      type: 'new_store_order',
                      orderId: o.id.toString(),
                      orderNumber: o.orderNumber,
                      storeOrderStatus: 'under_review',
                      needsReview: true
                    }
                  );
                } catch (adminErr) {
                  console.error('Failed to notify admins of approved store order payment:', adminErr);
                }
              }
            } else {
              if (o.captainId) {
                captainId = o.captainId;
                nextStatus = 'Assigned To Captain';
              } else {
                nextStatus = 'جديد';
              }
              await conn.query(
                `UPDATE orders 
                 SET status = ?, 
                     isPaid = 1, 
                     paymentStatus = 'paid', 
                     storeOrderStatus = 'NEW', 
                     captainTripStatus = 'PENDING_ASSIGNMENT' 
                 WHERE id = ?`,
                [nextStatus, payment.orderId]
              );

              // Notify merchant of normal order
              const io = req.app.get('io');
              if (io) {
                io.to(`merchant_${o.merchantId}`).emit('newStoreOrder', {
                  orderId: o.id,
                  orderNumber: o.orderNumber,
                  isPaid: true,
                  paymentMethod: o.paymentMethod,
                  totalAmount,
                  discountApplied,
                  couponCode: o.couponCode || null,
                  clientName: o.clientName,
                  phone: o.phone,
                  detailsText: o.details,
                  createdAt: new Date().toISOString(),
                });
                io.to(`merchant_${o.merchantId}`).emit('order_created', {
                  id: o.id.toString(),
                  orderNumber: o.orderNumber,
                  merchantId: o.merchantId.toString(),
                  clientName: o.clientName,
                  phone: o.phone,
                  deliveryAddress: o.deliveryAddress,
                  orderPrice,
                  deliveryFee,
                  serviceFee,
                  tip,
                  discountApplied,
                  couponCode: o.couponCode || null,
                  totalAmount,
                  scheduleType: o.scheduleType,
                  scheduledAt: o.scheduledAt,
                  status: 'جديد',
                  createdAt: new Date().toISOString()
                });

                const orderEventPayload = {
                  orderId: o.id.toString(),
                  id: o.id.toString(),
                  orderNumber: o.orderNumber,
                  shipmentId: null,
                  shiftId: o.shift_id ? o.shift_id.toString() : null,
                  captainId: null,
                  orderType: 'normal',
                  status: 'جديد',
                  merchantId: o.merchantId.toString(),
                  storeName: o.storeDescription || 'متجر',
                  clientName: o.clientName,
                  phone: o.phone,
                  deliveryAddress: o.deliveryAddress,
                  orderPrice,
                  deliveryFee,
                  serviceFee,
                  tip,
                  discountApplied,
                  couponCode: o.couponCode || null,
                  totalAmount,
                  scheduleType: o.scheduleType,
                  scheduledAt: o.scheduledAt,
                  createdAt: new Date().toISOString()
                };
                io.to('admins').emit('ORDER_CREATED', orderEventPayload);
                io.to('admins').emit('order_created', orderEventPayload);

                if (o.shift_id) {
                  io.to(`shift_${o.shift_id}`).emit('ORDER_CREATED', orderEventPayload);
                  io.to(`shift:${o.shift_id}`).emit('ORDER_CREATED', orderEventPayload);
                }
              }
            }
          }
        } else if (payment.shipmentId) {
          const [shipRows] = await conn.query('SELECT captainId FROM shipments WHERE id = ?', [payment.shipmentId]);
          if (shipRows.length > 0 && shipRows[0].captainId) {
            captainId = shipRows[0].captainId;
            nextStatus = 'Assigned To Captain';
          }
          await conn.query('UPDATE shipments SET status = ?, isPaid = 1 WHERE id = ?', [nextStatus, payment.shipmentId]);
        }

        await conn.commit();

        if (payment.orderId) {
          const [checkOrder] = await pool.query('SELECT orderType, storeId FROM orders WHERE id = ?', [payment.orderId]);
          const isStore = checkOrder.length > 0 && (checkOrder[0].orderType === 'store' || checkOrder[0].storeId != null);
          if (!isStore && (nextStatus === 'Ready For Assignment' || nextStatus === 'جديد')) {
            const { triggerAutoAssignment } = require('../utils/autoAssignment');
            triggerAutoAssignment(null, payment.orderId).catch(err => 
              console.error('Auto assignment trigger error after payment approval:', err)
            );
          }
        } else if (payment.shipmentId) {
          if (nextStatus === 'Ready For Assignment' || nextStatus === 'جديد') {
            const { triggerAutoAssignment } = require('../utils/autoAssignment');
            triggerAutoAssignment(payment.shipmentId, null).catch(err => 
              console.error('Auto assignment trigger error after payment approval:', err)
            );
          }
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

        if (!payment.orderId && !payment.shipmentId) {
        const targetUserId = payment.clientId || payment.merchantId;
        await pool.query(
          `UPDATE wallet_transactions SET status = 'failed' WHERE reference = ? OR (userId = ? AND amount = ? AND type = 'deposit' AND status = 'pending' ORDER BY id DESC LIMIT 1)`,
          [payment.paymentRef, targetUserId, payment.amount]
        );
      }

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

        if (payment.clientId) {
          try {
            await sendNotification(
              io,
              payment.clientId,
              `✅ تم قبول إيصال الدفع للطلب #${itemNumber}`,
              `تمت الموافقة على إيصال الدفع بقيمة ${payment.amount} ج.م وجارٍ متابعة طلبك.`,
              'order',
              {
                type: 'direct_payment_approved',
                orderId: payment.orderId ? payment.orderId.toString() : '',
                itemNumber: itemNumber.toString(),
                amount: payment.amount.toString(),
                paymentRef: payment.paymentRef,
              }
            );

            // Also emit direct event to client
            if (io) {
              io.to(`user_${payment.clientId}`).emit('direct_payment_approved', {
                paymentRef: payment.paymentRef,
                orderId: payment.orderId,
                itemNumber: itemNumber.toString(),
                status: 'approved',
              });
            }
          } catch (err) {
            console.error('Error sending direct payment approval notification to client:', err);
          }
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

      if (payment.orderId) {
        await pool.query(
          "UPDATE orders SET status = 'ملغي', paymentStatus = 'failed', storeOrderStatus = 'CANCELLED' WHERE id = ?",
          [payment.orderId]
        );
      }

      const io = req.app.get('io');
      if (io) {
        const merchantRoom = `user_${payment.merchantId}`;
        io.to(merchantRoom).emit('direct_payment_rejected', {
          paymentRef: payment.paymentRef,
          adminNote,
        });

        if (payment.clientId) {
          io.to(`user_${payment.clientId}`).emit('direct_payment_rejected', {
            paymentRef: payment.paymentRef,
            orderId: payment.orderId,
            itemNumber,
            adminNote: adminNote || '',
            reason: adminNote || 'تعذر التحقق من صحة إيصال التحويل',
          });
        }
      }

      if (!payment.orderId && !payment.shipmentId) {
        const targetUserId = payment.clientId || payment.merchantId;
        await pool.query(
          `UPDATE wallet_transactions SET status = 'failed' WHERE reference = ? OR (userId = ? AND amount = ? AND type = 'deposit' AND status = 'pending' ORDER BY id DESC LIMIT 1)`,
          [payment.paymentRef, targetUserId, payment.amount]
        );
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

      if (payment.clientId) {
        try {
          const { sendNotification } = require('../utils/notificationDispatcher');
          const reasonText = adminNote ? ` السبب: ${adminNote}` : '';
          await sendNotification(
            io,
            payment.clientId,
            `❌ تم رفض إيصال الدفع للطلب #${itemNumber}`,
            `تم رفض إيصال الدفع الخاص بالطلب رقم #${itemNumber}.${reasonText}`,
            'order',
            {
              type: 'direct_payment_rejected',
              orderId: payment.orderId ? payment.orderId.toString() : '',
              itemNumber: itemNumber.toString(),
              adminNote: adminNote || '',
            }
          );
        } catch (err) {
          console.error('Error sending direct payment rejection notification to client:', err);
        }
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
