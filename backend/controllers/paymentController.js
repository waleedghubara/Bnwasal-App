const { getPool } = require('../config/db');

const payDeliveryFee = async (req, res, next) => {
  try {
    const pool = getPool();
    const merchantId = req.user.id;
    const { shipmentId, orderId } = req.body;

    if (!shipmentId && !orderId) {
      return res.status(400).json({ status: 0, message: 'يجب تحديد معرف الشحنة أو معرف الطلب' });
    }

    let fee = 0;
    let currentStatus = '';
    let itemNumber = '';

    if (shipmentId) {
      const [shipments] = await pool.query('SELECT price, status, shipmentNumber, merchantId FROM shipments WHERE id = ?', [shipmentId]);
      if (shipments.length === 0) return res.status(404).json({ status: 0, message: 'الشحنة غير موجودة' });
      if (shipments[0].merchantId !== merchantId) return res.status(403).json({ status: 0, message: 'غير مصرح لك بدفع رسوم هذه الشحنة' });
      fee = parseFloat(shipments[0].price);
      currentStatus = shipments[0].status;
      itemNumber = shipments[0].shipmentNumber;
    } else {
      const [orders] = await pool.query('SELECT deliveryFee, status, orderNumber, merchantId FROM orders WHERE id = ?', [orderId]);
      if (orders.length === 0) return res.status(404).json({ status: 0, message: 'الطلب غير موجود' });
      if (orders[0].merchantId !== merchantId) return res.status(403).json({ status: 0, message: 'غير مصرح لك بدفع رسوم هذا الطلب' });
      fee = parseFloat(orders[0].deliveryFee);
      currentStatus = orders[0].status;
      itemNumber = orders[0].orderNumber;
    }

    // Accept payment from 'Awaiting Payment' (after_assignment mode) OR
    // 'Ready For Assignment' (after_agreement mode where payment button was shown early)
    const payableStatuses = ['Ready For Assignment'];
    if (!payableStatuses.includes(currentStatus)) {
      return res.status(400).json({
        status: 0,
        message: `لا يمكن الدفع في الحالة الحالية للطلب (${currentStatus}). يجب أن يكون الطلب في حالة "في انتظار الدفع"`
      });
    }

    // Fetch merchant wallet balance and store info
    const [merchants] = await pool.query('SELECT walletBalance, storeName, firstName, lastName FROM users WHERE id = ?', [merchantId]);
    const merchant = merchants[0];
    const balance = parseFloat(merchant?.walletBalance || 0);
    const merchantName = merchant ? (merchant.storeName || `${merchant.firstName} ${merchant.lastName}`) : 'تاجر';

    if (balance < fee) {
      return res.status(400).json({ status: 0, message: 'رصيد المحفظة غير كافٍ. تحتاج إلى شحن محفظتك أولاً' });
    }

    // Start database transaction
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // Deduct from merchant balance
      await conn.query('UPDATE users SET walletBalance = walletBalance - ? WHERE id = ?', [fee, merchantId]);

      // Record transaction
      const txTitle = shipmentId ? `دفع رسوم شحن الشحنة #${itemNumber}` : `دفع رسوم توصيل الطلب #${itemNumber}`;
      await conn.query(
        "INSERT INTO wallet_transactions (userId, title, amount, type, status) VALUES (?, ?, ?, 'withdraw', 'success')",
        [merchantId, txTitle, fee]
      );

      // Determine next status
      const [settings] = await conn.query("SELECT `value` FROM app_settings WHERE `key` = 'fee_collection_mode'");
      const mode = settings.length > 0 ? settings[0].value : 'after_agreement';

      let hasCaptain = false;
      if (shipmentId) {
        const [shipmentRows] = await conn.query('SELECT captainId FROM shipments WHERE id = ?', [shipmentId]);
        if (shipmentRows.length > 0 && shipmentRows[0].captainId) hasCaptain = true;
      } else {
        const [orderRows] = await conn.query('SELECT captainId FROM orders WHERE id = ?', [orderId]);
        if (orderRows.length > 0 && orderRows[0].captainId) hasCaptain = true;
      }

      let nextStatus = '';
      if (hasCaptain) {
        // Captain already assigned (after_assignment flow) → activate them
        nextStatus = 'Assigned To Captain';
      } else {
        // No captain yet → payment unlocks the order for captain assignment
        nextStatus = 'Ready For Assignment';
      }

      if (shipmentId) {
        await conn.query('UPDATE shipments SET status = ?, isPaid = 1 WHERE id = ?', [nextStatus, shipmentId]);
      } else {
        await conn.query('UPDATE orders SET status = ?, isPaid = 1 WHERE id = ?', [nextStatus, orderId]);
      }

      await conn.commit();

      if (nextStatus === 'Ready For Assignment') {
        const { triggerAutoAssignment } = require('../utils/autoAssignment');
        triggerAutoAssignment(shipmentId || null, orderId || null).catch(err =>
          console.error('Error triggering auto assignment after payment:', err.message)
        );
      }

      // Socket update
      const targetRoom = shipmentId ? `shipment_${shipmentId}` : `order_${orderId}`;
      const io = req.app.get('io');
      if (io) {
        io.to(targetRoom).emit('statusUpdate', { status: nextStatus });
        io.to(targetRoom).emit('payment_received', { fee });
        io.to('admins').emit('dashboard_update');
      }

      // Send notification to admins
      try {
        const { notifyAdmins } = require('../utils/adminNotifier');
        const itemType = shipmentId ? 'شحنة' : 'طلب';
        await notifyAdmins(
          io,
          `💰 تم سداد الرسوم (محفظة)`,
          `قام التاجر ${merchantName} بسداد رسوم توصيل ${itemType} رقم #${itemNumber} بقيمة ${fee} ج.م من المحفظة.`,
          'payment',
          {
            type: 'wallet_payment',
            shipmentId: shipmentId ? shipmentId.toString() : '',
            orderId: orderId ? orderId.toString() : '',
            itemNumber: itemNumber.toString(),
            amount: fee.toString(),
            merchantId: merchantId.toString()
          }
        );
      } catch (err) {
        console.error('Error sending wallet fee payment notification to admins:', err);
      }

      res.status(200).json({
        status: 1,
        message: 'تم خصم رسوم التوصيل من المحفظة وتحديث حالة الشحنة بنجاح',
        data: { nextStatus, deducted: fee }
      });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (error) {
    next(error);
  }
};

module.exports = {
  payDeliveryFee
};
