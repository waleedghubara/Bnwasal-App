const { getPool } = require('../config/db');
const { sendNotification } = require('./notificationDispatcher');
const { notifyAdmins } = require('./adminNotifier');
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');

const EGYPT_UTC_OFFSET_HOURS = 3;

// File logging helper
const logToFile = (message) => {
  try {
    const logDir = path.join(__dirname, '../logs');
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    const logPath = path.join(logDir, 'auto_assignment.log');
    const timestamp = new Date().toISOString();
    fs.appendFileSync(logPath, `[${timestamp}] ${message}\n`);
  } catch (err) {
    console.error('❌ Error writing to auto_assignment.log:', err.message);
  }
};

// Calculate distance in kilometers using Haversine formula
const getDistance = (lat1, lon1, lat2, lon2) => {
  if (lat1 === null || lon1 === null || lat2 === null || lon2 === null || lat1 === undefined || lon1 === undefined || lat2 === undefined || lon2 === undefined) return Infinity;
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

// Send email notification to support email
const sendManualInterventionEmail = async (pool, shipmentNum, isShipment, id) => {
  try {
    const [settings] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'support_email'");
    const supportEmail = settings.length > 0 ? settings[0].value : 'contact@bnwasal.com';

    const host = process.env.EMAIL_HOST;
    const port = parseInt(process.env.EMAIL_PORT, 10) || 587;
    const user = process.env.EMAIL_USER;
    const pass = process.env.EMAIL_PASS;
    const from = process.env.EMAIL_FROM || '"بنوصل" <contact@bnwasal.com>';

    if (!host || !user || !pass) {
      logToFile(`[Email Simulator] SMTP not configured. Cannot send email for #${shipmentNum}`);
      return;
    }

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      tls: { rejectUnauthorized: false }
    });

    const typeStr = isShipment ? 'شحنة' : 'طلب';

    const mailOptions = {
      from,
      to: supportEmail,
      subject: `🚨 تدخل يدوي مطلوب للـ ${typeStr} #${shipmentNum}`,
      html: `
        <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px; line-height: 1.6; text-align: right;">
          <h2 style="color: #dc2626;">🚨 تنبيه إسناد تلقائي غير مكتمل</h2>
          <p>مرحباً إداري بنوصل،</p>
          <p>نود إعلامكم بأن نظام الإسناد التلقائي لم يتمكن من العثور على كابتن مناسب، أو تم رفض الـ ${typeStr} من جميع الكباتن المؤهلين.</p>
          <div style="background-color: #fef2f2; border: 1px solid #fee2e2; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <strong>تفاصيل الـ ${typeStr}:</strong>
            <ul>
              <li>رقم الـ ${typeStr}: <strong>#${shipmentNum}</strong></li>
              <li>معرف الـ ${typeStr}: <strong>${id}</strong></li>
              <li>السبب: <strong>لا يوجد كباتن متاحين للمسار أو تم استنفاذ جميع الكباتن المؤهلين.</strong></li>
            </ul>
          </div>
          <p><strong>نص الإشعار:</strong></p>
          <blockquote style="border-right: 4px solid #dc2626; padding-right: 15px; margin: 20px 0; color: #4b5563; font-style: italic;">
            لا يوجد أي كابتن متاح حالياً لهذا المسار، أو تم رفض الشحنة من جميع الكباتن. يرجى التدخل اليدوي لإسناد الشحنة.
          </blockquote>
          <p>يرجى الدخول إلى لوحة التحكم فوراً لاتخاذ الإجراء المناسب وإسناد الـ ${typeStr} يدوياً.</p>
          <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
          <p style="font-size: 12px; color: #9ca3af;">تم إرسال هذا البريد تلقائياً من نظام بنوصل اللوجستي.</p>
        </div>
      `
    };

    await transporter.sendMail(mailOptions);
    logToFile(`✉️ Manual intervention email sent to ${supportEmail} for shipment/order #${shipmentNum}`);
  } catch (error) {
    console.error(`❌ Error sending manual intervention email:`, error.message);
    logToFile(`❌ Error sending manual intervention email: ${error.message}`);
  }
};

const cleanAr = (str) => {
  if (!str) return '';
  return str
    .toLowerCase()
    .trim()
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\bال/g, '');
};

// Route matching logic
const routeMatches = (trip, { fromAddress, toAddress, fromGov, toGov, fromArea, toArea }, rule = 'flexible') => {
  if (trip.status === 'completed' || trip.status === 'cancelled') return false;

  const tFromAddr = cleanAr(trip.fromAddress);
  const tToAddr = cleanAr(trip.toAddress);
  const tFromCity = cleanAr(trip.fromCity);
  const tToCity = cleanAr(trip.toCity);
  const tPassing = cleanAr(trip.passingCities);

  const sFromAddr = cleanAr(fromAddress);
  const sToAddr = cleanAr(toAddress);
  const sFromGov = cleanAr(fromGov);
  const sToGov = cleanAr(toGov);
  const sFromArea = cleanAr(fromArea);
  const sToArea = cleanAr(toArea);

  const checkOverlap = (tripStr, itemStr) => {
    if (!tripStr || !itemStr) return false;
    return tripStr.includes(itemStr) || itemStr.includes(tripStr);
  };

  const sourceMatches =
    checkOverlap(tFromAddr, sFromAddr) ||
    checkOverlap(tFromCity, sFromGov) ||
    checkOverlap(tFromAddr, sFromGov) ||
    checkOverlap(tFromAddr, sFromArea) ||
    checkOverlap(tFromCity, sFromArea) ||
    checkOverlap(tPassing, sFromAddr) ||
    checkOverlap(tPassing, sFromGov) ||
    checkOverlap(tPassing, sFromArea);

  const destMatches =
    checkOverlap(tToAddr, sToAddr) ||
    checkOverlap(tToCity, sToGov) ||
    checkOverlap(tToAddr, sToGov) ||
    checkOverlap(tToAddr, sToArea) ||
    checkOverlap(tToCity, sToArea) ||
    checkOverlap(tPassing, sToAddr) ||
    checkOverlap(tPassing, sToGov) ||
    checkOverlap(tPassing, sToArea);

  return sourceMatches && destMatches;
};

// Resolve a pending assignment attempt
const resolveAttempt = async (pool, { shipmentId, orderId, captainId, status, reason }) => {
  try {
    await pool.query(
      `UPDATE auto_assignment_attempts 
       SET status = ?, resolvedAt = NOW(), reason = ? 
       WHERE ${shipmentId ? 'shipmentId = ?' : 'orderId = ?'} AND captainId = ? AND status = 'pending'`,
      [status, reason || null, shipmentId || orderId, captainId]
    );
    logToFile(`Resolved attempt for ${shipmentId ? 'shipment' : 'order'} ID ${shipmentId || orderId} with captain ID ${captainId}. Status: ${status}, Reason: ${reason}`);
  } catch (err) {
    console.error('❌ Error resolving auto assignment attempt:', err.message);
  }
};

// Main assignment function
const assignNextCaptain = async (pool, io, activeUsers, { shipmentId, orderId }) => {
  const isShipment = !!shipmentId;
  const id = shipmentId || orderId;
  const typeStr = isShipment ? 'shipment' : 'order';
  const typeStrAr = isShipment ? 'شحنة' : 'طلب';

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // 1. Fetch shipment or order details and LOCK the row
    let entity = null;
    let fromGov = '', fromArea = '', toGov = '', toArea = '', shipmentNum = '';
    let fromAddress = '', toAddress = '';
    let merchantId = null;
    let merchantLat = null;
    let merchantLng = null;
    
    if (isShipment) {
      const [rows] = await conn.query(
        `SELECT id, shipmentNumber, status, fromGovernorate, fromArea, toGovernorate, toArea, fromAddress, toAddress, merchantId, merchantLatitude, merchantLongitude 
         FROM shipments WHERE id = ? FOR UPDATE`,
        [id]
      );
      if (rows.length > 0) {
        entity = rows[0];
        fromGov = entity.fromGovernorate || '';
        fromArea = entity.fromArea || '';
        toGov = entity.toGovernorate || '';
        toArea = entity.toArea || '';
        fromAddress = entity.fromAddress || '';
        toAddress = entity.toAddress || '';
        shipmentNum = entity.shipmentNumber;
        merchantId = entity.merchantId;
        merchantLat = entity.merchantLatitude;
        merchantLng = entity.merchantLongitude;
      }
    } else {
      const [rows] = await conn.query(
        `SELECT o.id, o.orderNumber, o.status, o.deliveryAddress, o.merchantId, m.storeName, m.city, m.latitude as merchantLat, m.longitude as merchantLng
         FROM orders o LEFT JOIN users m ON o.merchantId = m.id
         WHERE o.id = ? FOR UPDATE`,
        [id]
      );
      if (rows.length > 0) {
        entity = rows[0];
        fromAddress = entity.storeName || entity.city || '';
        toAddress = entity.deliveryAddress || '';
        shipmentNum = entity.orderNumber;
        merchantId = entity.merchantId;
        merchantLat = entity.merchantLat;
        merchantLng = entity.merchantLng;
      }
    }
    
    if (!entity) {
      await conn.rollback();
      return;
    }
    
    // Ensure it is in Ready For Assignment
    if (entity.status !== 'Ready For Assignment') {
      await conn.rollback();
      return;
    }

    // 1.5 Load auto-assignment settings from DB
    const [settingRows] = await conn.query(
      "SELECT `key`, `value` FROM app_settings WHERE `key` IN ('enable_auto_assignment', 'max_reassignment_attempts', 'allow_auto_assignment_after_reject', 'allow_auto_assignment_after_timeout', 'route_matching_rule')"
    );
    const settings = {
      enable_auto_assignment: '1',
      max_reassignment_attempts: '5',
      allow_auto_assignment_after_reject: '1',
      allow_auto_assignment_after_timeout: '1',
      route_matching_rule: 'flexible'
    };
    for (const r of settingRows) {
      settings[r.key] = r.value;
    }

    // If disabled, stop immediately
    if (settings.enable_auto_assignment === '0') {
      await conn.rollback();
      return;
    }

    // Check last attempt resolution status for configuration restrictions
    const [lastAttemptRows] = await conn.query(
      `SELECT status FROM auto_assignment_attempts WHERE ${isShipment ? 'shipmentId = ?' : 'orderId = ?'} ORDER BY id DESC LIMIT 1`,
      [id]
    );
    if (lastAttemptRows.length > 0) {
      const lastStatus = lastAttemptRows[0].status;
      if (lastStatus === 'rejected' && settings.allow_auto_assignment_after_reject === '0') {
        const logMsg = `🤖 Auto-assignment: Stopped for ${typeStr} #${shipmentNum} because auto-assignment after rejection is disabled.`;
        console.log(logMsg);
        logToFile(logMsg);
        await conn.query(
          `UPDATE ${isShipment ? 'shipments' : 'orders'} SET autoAssignmentFailed = 1 WHERE id = ?`,
          [id]
        );
        await conn.commit();
        
        // Notify admin about the stoppage
        const io = global.io;
        if (io) {
          const title = `⚠️ تم إيقاف الإسناد التلقائي للـ ${typeStrAr} #${shipmentNum}`;
          const body = `تم إيقاف محاولات الإسناد التلقائي للـ ${typeStrAr} رقم #${shipmentNum} لعدم تفعيل الإسناد بعد رفض الكابتن.`;
          const { notifyAdmins } = require('./adminNotifier');
          notifyAdmins(io, title, body, 'manual_intervention_required', {
            shipmentId: isShipment ? id.toString() : '',
            orderId: !isShipment ? id.toString() : '',
            shipmentNum,
            type: 'manual_intervention_required'
          });
        }
        return;
      }
      if (lastStatus === 'timeout' && settings.allow_auto_assignment_after_timeout === '0') {
        const logMsg = `🤖 Auto-assignment: Stopped for ${typeStr} #${shipmentNum} because auto-assignment after timeout is disabled.`;
        console.log(logMsg);
        logToFile(logMsg);
        await conn.query(
          `UPDATE ${isShipment ? 'shipments' : 'orders'} SET autoAssignmentFailed = 1 WHERE id = ?`,
          [id]
        );
        await conn.commit();
        
        // Notify admin about the stoppage
        const io = global.io;
        if (io) {
          const title = `⚠️ تم إيقاف الإسناد التلقائي للـ ${typeStrAr} #${shipmentNum}`;
          const body = `تم إيقاف محاولات الإسناد التلقائي للـ ${typeStrAr} رقم #${shipmentNum} لعدم تفعيل الإسناد بعد انتهاء مهلة الكابتن.`;
          const { notifyAdmins } = require('./adminNotifier');
          notifyAdmins(io, title, body, 'manual_intervention_required', {
            shipmentId: isShipment ? id.toString() : '',
            orderId: !isShipment ? id.toString() : '',
            shipmentNum,
            type: 'manual_intervention_required'
          });
        }
        return;
      }
    }

    // Check maximum reassignment attempts limit
    const [attemptsCountRows] = await conn.query(
      `SELECT COUNT(*) as cnt FROM auto_assignment_attempts WHERE ${isShipment ? 'shipmentId = ?' : 'orderId = ?'}`,
      [id]
    );
    const totalAttempts = attemptsCountRows[0].cnt;
    const maxAttempts = parseInt(settings.max_reassignment_attempts, 10);
    if (totalAttempts >= maxAttempts) {
      const logMsg = `🤖 Auto-assignment: Exceeded max reassignment attempts (${totalAttempts}/${maxAttempts}) for ${typeStr} #${shipmentNum}.`;
      console.warn(logMsg);
      logToFile(logMsg);
      await conn.query(
        `UPDATE ${isShipment ? 'shipments' : 'orders'} SET autoAssignmentFailed = 1 WHERE id = ?`,
        [id]
      );
      await conn.commit();

      // Notify admin
      const io = global.io;
      if (io) {
        const title = `⚠️ تنبيه إسناد تلقائي لم يتم للـ ${typeStrAr} #${shipmentNum}`;
        const body = `تجاوز عدد محاولات الإسناد التلقائي الحد الأقصى المسموح به (${maxAttempts}) للـ ${typeStrAr} رقم #${shipmentNum}. يرجى التدخل اليدوي.`;
        const { notifyAdmins } = require('./adminNotifier');
        notifyAdmins(io, title, body, 'manual_intervention_required', {
          shipmentId: isShipment ? id.toString() : '',
          orderId: !isShipment ? id.toString() : '',
          shipmentNum,
          type: 'manual_intervention_required'
        });
      }
      return;
    }

    // Fetch fallback merchant coordinates if NULL
    if (merchantLat === null || merchantLng === null) {
      const [mRows] = await conn.query('SELECT latitude, longitude FROM users WHERE id = ?', [merchantId]);
      if (mRows.length > 0) {
        merchantLat = mRows[0].latitude;
        merchantLng = mRows[0].longitude;
      }
    }

    // 2. Fetch list of attempts grouped by captain to count attempts per captain
    const [attemptRows] = await conn.query(
      `SELECT captainId, COUNT(*) as cnt FROM auto_assignment_attempts WHERE ${isShipment ? 'shipmentId = ?' : 'orderId = ?'} GROUP BY captainId`,
      [id]
    );
    const captainAttemptCounts = new Map();
    for (const row of attemptRows) {
      captainAttemptCounts.set(row.captainId, parseInt(row.cnt, 10));
    }

    const maxAttemptsPerCaptain = parseInt(settings.max_attempts_per_captain || '3', 10);

    // 3. Fetch active captains
    const [captains] = await conn.query(
      `SELECT id, firstName, lastName, email, phone, profileImage, latitude, longitude,
              COALESCE(ROUND((SELECT AVG(rating) FROM reviews WHERE revieweeId = users.id), 1), 0.0) as avgRating,
              (SELECT COUNT(*) FROM reviews WHERE revieweeId = users.id) as reviewCount
       FROM users WHERE role = 'captain' AND status = 'active'`
    );

    // Compute today's date in Egypt (UTC+3)
    const now = new Date();
    const egyptNow = new Date(now.getTime() + EGYPT_UTC_OFFSET_HOURS * 3600000);
    const egyptDate = egyptNow.toISOString().slice(0, 10);

    const eligibleCaptains = [];

    for (const captain of captains) {
      // Check attempts for this specific captain
      const captainAttempts = captainAttemptCounts.get(captain.id) || 0;
      if (captainAttempts >= maxAttemptsPerCaptain) {
        // Exceeded max allowed attempts for this captain
        continue;
      }

      // Must be Online (WebSocket)
      const isOnline = activeUsers ? activeUsers.has(String(captain.id)) : false;
      if (!isOnline) continue;

      // Fetch active stats
      const [[overallStats]] = await conn.query(
        `SELECT
           (SELECT COUNT(*) FROM orders 
            WHERE captainId = ? 
              AND LOWER(status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeOrdersCount,
           (SELECT COUNT(*) FROM shipments 
            WHERE captainId = ? 
              AND LOWER(status) IN ('assigned to captain', 'captain arrived', 'picked up', 'in transit', 'ongoing', 'تم القبول', 'تم قبول العرض', 'جاري التنفيذ', 'في الطريق')) as activeShipmentsCount`,
        [captain.id, captain.id]
      );
      captain.activeOrdersCount = parseInt(overallStats.activeOrdersCount || 0);
      captain.activeShipmentsCount = parseInt(overallStats.activeShipmentsCount || 0);
      captain.attemptsCount = captainAttempts;

      // Check if captain has an active trip covering the route
      const [trips] = await conn.query(
        `SELECT id, fromAddress, toAddress, fromCity, toCity, passingCities, status 
         FROM trips 
         WHERE driverId = ? 
           AND status NOT IN ('completed', 'cancelled')
           AND (date IS NULL OR DATE(date) = ? OR DATE(date) >= CURDATE())`,
        [captain.id, egyptDate]
      );
      
      let matchesRoute = false;
      let recommendedTripId = null;

      for (const trip of trips) {
        if (routeMatches(trip, { fromAddress, toAddress, fromGov, toGov, fromArea, toArea }, settings.route_matching_rule)) {
          matchesRoute = true;
          recommendedTripId = trip.id;
          break;
        }
      }

      if (!matchesRoute) continue; // Route check is mandatory

      captain.recommendedTripId = recommendedTripId;
      
      // Calculate distance for proximity sorting
      captain.distance = getDistance(merchantLat, merchantLng, captain.latitude, captain.longitude);
      
      eligibleCaptains.push(captain);
    }

    // Sort eligible captains:
    // 1. Attempts count (captains with fewer attempts first)
    // 2. Distance (closest first)
    // 3. Average Rating (highest first)
    // 4. Busy count (least busy first)
    eligibleCaptains.sort((a, b) => {
      if (a.attemptsCount !== b.attemptsCount) {
        return a.attemptsCount - b.attemptsCount;
      }
      if (a.distance !== b.distance) {
        return a.distance - b.distance;
      }
      if (b.avgRating !== a.avgRating) {
        return b.avgRating - a.avgRating;
      }
      const busyA = a.activeOrdersCount + a.activeShipmentsCount;
      const busyB = b.activeOrdersCount + b.activeShipmentsCount;
      return busyA - busyB;
    });

    if (eligibleCaptains.length > 0) {
      const bestCaptain = eligibleCaptains[0];
      const captainName = `${bestCaptain.firstName} ${bestCaptain.lastName}`;
      const nextStatus = 'Assigned To Captain';

      // Assign atomically
      if (isShipment) {
        await conn.query(
          `UPDATE shipments SET captainId = ?, status = ?, captainApprovalStatus = ?, trip_id = COALESCE(?, trip_id), autoAssignmentFailed = 0 WHERE id = ?`,
          [bestCaptain.id, nextStatus, 'pending', bestCaptain.recommendedTripId, id]
        );
      } else {
        await conn.query(
          `UPDATE orders SET captainId = ?, status = ?, captainApprovalStatus = ?, trip_id = COALESCE(?, trip_id), autoAssignmentFailed = 0 WHERE id = ?`,
          [bestCaptain.id, nextStatus, 'pending', bestCaptain.recommendedTripId, id]
        );
      }

      // Record attempt
      await conn.query(
        `INSERT INTO auto_assignment_attempts (shipmentId, orderId, captainId, status, assignedAt)
         VALUES (?, ?, ?, 'pending', NOW())`,
        [isShipment ? id : null, !isShipment ? id : null, bestCaptain.id]
      );

      await conn.commit();

      // Socket updates
      const targetRoom = isShipment ? `shipment_${id}` : `order_${id}`;
      if (io) {
        io.to(targetRoom).emit('statusUpdate', { status: nextStatus });
        io.to(targetRoom).emit('captain_assigned', { captainId: bestCaptain.id.toString(), captainName });
        io.to(`user_${bestCaptain.id}`).emit('incoming_order', {
          id: id.toString(),
          isShipment,
          shipmentNumber: shipmentNum,
          orderNumber: shipmentNum,
          orderType: isShipment ? 'توصيل شحنة' : 'شراء احتياجات',
          pickupArea: fromAddress || fromArea || fromGov || 'منطقة الاستلام',
          deliveryArea: toAddress || toArea || toGov || 'منطقة التسليم',
          priceText: `${entity.price || entity.deliveryFee || 0} جنيه`,
          notes: entity.notes || 'يرجى التواصل قبل الاستلام',
          timeoutSeconds: parseInt(settings.captain_acceptance_timeout_seconds || '60', 10),
        });
        io.to('admins').emit('dashboard_update');
      }

      // Send Push notification
      sendNotification(io, bestCaptain.id, 'شحنة جديدة مسندة تلقائياً 🚚', `تم إسناد الـ ${typeStrAr} رقم #${shipmentNum} إليك تلقائياً (محاولة رقم ${bestCaptain.attemptsCount + 1}).`, 'order', {
        type: 'shipment_assigned',
        shipmentId: isShipment ? id.toString() : '',
        orderId: !isShipment ? id.toString() : '',
        status: nextStatus
      });

      const logMsg = `🤖 Auto-assignment: Assigned ${typeStr} #${shipmentNum} to captain ${captainName} (ID: ${bestCaptain.id}, Attempt: ${bestCaptain.attemptsCount + 1}/${maxAttemptsPerCaptain})`;
      console.log(logMsg);
      logToFile(logMsg);
    } else {
      // No eligible captains left: reset status back to Ready For Assignment / waiting for admin
      if (isShipment) {
        await conn.query("UPDATE shipments SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment', autoAssignmentFailed = 1 WHERE id = ?", [id]);
      } else {
        await conn.query("UPDATE orders SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment', autoAssignmentFailed = 1 WHERE id = ?", [id]);
      }

      await conn.commit();

      if (io) {
        io.to('admins').emit('dashboard_update');
      }

      const notifyTitle1 = `⚠️ إسناد تلقائي غير مكتمل #${shipmentNum}`;
      const notifyTitle2 = `⚠️ تنبيه توجيه يدوي مطلوبة #${shipmentNum}`;
      const notifyMsg = `لم يتم العثور على أي كابتن أونلاين لديه رحلة مطابقة للمسار [${fromAddress || 'غير محدد'} -> ${toAddress || 'غير محدد'}]، أو تم رفض الشحنة واستنفاذ محاولات الإعادة مع الكباتن المؤهلين. عاودت الشحنة حالة "بانتظار التوجيه اليدوي" من الإدارة.`;

      await notifyAdmins(io, notifyTitle1, notifyMsg, 'manual_intervention_required', {
        shipmentId: isShipment ? id.toString() : '',
        orderId: !isShipment ? id.toString() : '',
        shipmentNum,
        type: 'manual_intervention_required'
      });

      await notifyAdmins(io, notifyTitle2, notifyMsg, 'manual_intervention_required', {
        shipmentId: isShipment ? id.toString() : '',
        orderId: !isShipment ? id.toString() : '',
        shipmentNum,
        type: 'manual_intervention_required'
      });

      const logMsg = `🤖 Auto-assignment: No eligible captains remaining for ${typeStr} #${shipmentNum}. Reset to Ready For Assignment & Admin notified.`;
      console.warn(logMsg);
      logToFile(logMsg);

      // Send independent email to support
      sendManualInterventionEmail(pool, shipmentNum, isShipment, id).catch(err => 
        console.error('Error sending fallback manual intervention email:', err.message)
      );
    }
  } catch (err) {
    await conn.rollback();
    const errMsg = `❌ Error in auto-assigning ${typeStr} ID ${id}: ${err.message}`;
    console.error(errMsg);
    logToFile(errMsg);
  } finally {
    conn.release();
  }
};

let isAssignmentStepRunning = false;

// Check for timeout and process auto assignment loop
const runAutoAssignmentStep = async (pool, io, activeUsers) => {
  if (isAssignmentStepRunning) return;
  isAssignmentStepRunning = true;

  try {
    // 1. Fetch configured timeout from app_settings
    const [settings] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'auto_assignment_timeout'");
    const timeoutSeconds = settings.length > 0 ? parseInt(settings[0].value || '300', 10) : 300;

    // 2. Check pending shipments for timeout
    const [pendingShipments] = await pool.query(
      `SELECT s.id, s.shipmentNumber, s.captainId, a.assignedAt 
       FROM shipments s
       JOIN auto_assignment_attempts a ON s.id = a.shipmentId
       WHERE s.status = 'Assigned To Captain' AND s.captainApprovalStatus = 'pending' AND a.status = 'pending'`
    );

    for (const s of pendingShipments) {
      const elapsed = (Date.now() - new Date(s.assignedAt).getTime()) / 1000;
      if (elapsed >= timeoutSeconds) {
        const logMsg = `🤖 Auto-assignment: Shipment #${s.shipmentNumber} assignment timed out after ${elapsed.toFixed(1)}s (timeout: ${timeoutSeconds}s)`;
        console.log(logMsg);
        logToFile(logMsg);
        
        const prevCaptainId = s.captainId;
        
        await resolveAttempt(pool, { shipmentId: s.id, captainId: s.captainId, status: 'timeout', reason: `Timeout after ${timeoutSeconds} seconds` });
        
        // Reset shipment to ready for assignment
        await pool.query(
          "UPDATE shipments SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment' WHERE id = ?",
          [s.id]
        );

        if (io) {
          const targetRoom = `shipment_${s.id}`;
          // Notify shipment room of status change
          io.to(targetRoom).emit('statusUpdate', { status: 'Ready For Assignment' });
          // Notify shipment room that captain was cleared
          io.to(targetRoom).emit('captain_cleared', { captainId: null, reason: 'timeout' });
          // ✅ Notify the CAPTAIN specifically to remove this shipment from their screen
          if (prevCaptainId) {
            io.to(`user_${prevCaptainId}`).emit('shipment_removed', { shipmentId: s.id.toString(), reason: 'timeout' });
            io.to(`user_${prevCaptainId}`).emit('statusUpdate', { status: 'Ready For Assignment', shipmentId: s.id.toString() });
          }
          io.to('admins').emit('dashboard_update');
          io.to('admins').emit('captain_cleared', { shipmentId: s.id.toString(), captainId: null, reason: 'timeout' });
        }

        // Trigger next assignment
        await assignNextCaptain(pool, io, activeUsers, { shipmentId: s.id });
      }
    }

    // 3. Check pending orders for timeout
    const [pendingOrders] = await pool.query(
      `SELECT o.id, o.orderNumber, o.captainId, a.assignedAt 
       FROM orders o
       JOIN auto_assignment_attempts a ON o.id = a.orderId
       WHERE o.status = 'Assigned To Captain' AND o.captainApprovalStatus = 'pending' AND a.status = 'pending'`
    );

    for (const o of pendingOrders) {
      const elapsed = (Date.now() - new Date(o.assignedAt).getTime()) / 1000;
      if (elapsed >= timeoutSeconds) {
        const logMsg = `🤖 Auto-assignment: Order #${o.orderNumber} assignment timed out after ${elapsed.toFixed(1)}s (timeout: ${timeoutSeconds}s)`;
        console.log(logMsg);
        logToFile(logMsg);
        
        const prevCaptainId = o.captainId;
        
        await resolveAttempt(pool, { orderId: o.id, captainId: o.captainId, status: 'timeout', reason: `Timeout after ${timeoutSeconds} seconds` });
        
        // Reset order to ready for assignment
        await pool.query(
          "UPDATE orders SET captainId = NULL, captainApprovalStatus = NULL, status = 'Ready For Assignment' WHERE id = ?",
          [o.id]
        );

        if (io) {
          const targetRoom = `order_${o.id}`;
          // Notify order room of status change
          io.to(targetRoom).emit('statusUpdate', { status: 'Ready For Assignment' });
          // Notify order room that captain was cleared
          io.to(targetRoom).emit('captain_cleared', { captainId: null, reason: 'timeout' });
          // ✅ Notify the CAPTAIN specifically to remove this order from their screen
          if (prevCaptainId) {
            io.to(`user_${prevCaptainId}`).emit('order_removed', { orderId: o.id.toString(), reason: 'timeout' });
            io.to(`user_${prevCaptainId}`).emit('statusUpdate', { status: 'Ready For Assignment', orderId: o.id.toString() });
          }
          io.to('admins').emit('dashboard_update');
          io.to('admins').emit('captain_cleared', { orderId: o.id.toString(), captainId: null, reason: 'timeout' });
        }

        // Trigger next assignment
        await assignNextCaptain(pool, io, activeUsers, { orderId: o.id });
      }
    }

    // 4. Start auto assignment for any newly ready shipments/orders (unassigned, autoAssignmentFailed = 0)
    const [unassignedShipments] = await pool.query(
      "SELECT id FROM shipments WHERE status = 'Ready For Assignment' AND captainId IS NULL AND autoAssignmentFailed = 0"
    );
    for (const s of unassignedShipments) {
      await assignNextCaptain(pool, io, activeUsers, { shipmentId: s.id });
    }

    const [unassignedOrders] = await pool.query(
      "SELECT id FROM orders WHERE status = 'Ready For Assignment' AND captainId IS NULL AND autoAssignmentFailed = 0"
    );
    for (const o of unassignedOrders) {
      await assignNextCaptain(pool, io, activeUsers, { orderId: o.id });
    }
  } catch (err) {
    const errMsg = `❌ Error in runAutoAssignmentStep: ${err.message}`;
    console.error(errMsg);
    logToFile(errMsg);
  } finally {
    isAssignmentStepRunning = false;
  }
};

let autoAssignmentInterval = null;

const initAutoAssignment = (app) => {
  const pool = getPool();
  const io = app.get('io');
  const activeUsers = app.get('activeUsers');

  if (autoAssignmentInterval) {
    clearInterval(autoAssignmentInterval);
  }

  // Run auto assignment step every 15 seconds
  autoAssignmentInterval = setInterval(() => {
    runAutoAssignmentStep(pool, io, activeUsers);
  }, 15000);

  console.log('🤖 Auto-assignment background worker initialized successfully (Interval: 15s)');
};

const triggerAutoAssignment = async (shipmentId, orderId) => {
  const pool = getPool();
  const io = global.io;
  const activeUsers = global.activeUsers || null; 
  
  await assignNextCaptain(pool, io, activeUsers, { shipmentId, orderId });
};

module.exports = {
  initAutoAssignment,
  triggerAutoAssignment,
  resolveAttempt
};
