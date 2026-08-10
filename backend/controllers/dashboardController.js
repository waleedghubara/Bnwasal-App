const { getPool } = require('../config/db');
const { addEffectiveStatusBulk } = require('./tripsController');

const getDashboard = async (req, res, next) => {
  try {
    const pool = getPool();

    const [stats] = await pool.query(`
      SELECT
        /* ===== المستخدمون ===== */
        (SELECT COUNT(*) FROM users WHERE role='merchant') as merchants,
        (SELECT COUNT(*) FROM users WHERE role='client')   as clients,
        (SELECT COUNT(*) FROM users WHERE role='captain')  as captains,
        /* active_captains يُحسب لاحقاً من Socket activeUsers */
        (SELECT COUNT(*) FROM users WHERE status='pending_verification') as pending_verifications,
        (SELECT COUNT(*) FROM users WHERE status='pending_otp') as pending_otp,

        /* ===== الطلبات ===== */
        (SELECT COUNT(*) FROM orders) as orders,
        (SELECT COUNT(*) FROM orders WHERE DATE(createdAt) = CURDATE()) as new_orders,
        /* قيد المراجعة: بانتظار القبول + بانتظار الدفع + تفاوض + حالات Processing */
        (
          SELECT COUNT(*) FROM orders
          WHERE status IN (
            'بانتظار القبول', 'بانتظار الدفع', 'قيد التفاوض',
            'Processing','Preparing','Pending','pending','processing','preparing'
          )
        ) as orders_processing,
        (
          SELECT COUNT(*) FROM orders
          WHERE status IN ('Out_for_delivery','In_progress','in_progress','out_for_delivery','Delivering','delivering','جاري التوصيل','في الطريق')
        ) as orders_delivering,
        (
          SELECT COUNT(*) FROM orders
          WHERE status IN ('Completed','Delivered','completed','delivered','مكتمل','تم التوصيل')
        ) as orders_completed,
        (
          SELECT COUNT(*) FROM orders
          WHERE status IN ('Cancelled','cancelled','ملغي','ملغى')
        ) as orders_cancelled,

        /* ===== الشحنات ===== */
        (SELECT COUNT(*) FROM shipments) as shipments,
        (SELECT COUNT(*) FROM shipments WHERE DATE(createdAt) = CURDATE()) as new_shipments,
        /* قيد المراجعة للشحنات: جديدة + بانتظار الدفع + قيد التفاوض */
        (
          SELECT COUNT(*) FROM shipments
          WHERE status IN (
            'جديدة', 'بانتظار الدفع', 'قيد التفاوض',
            'Processing','Preparing','Pending','pending','processing','preparing'
          )
        ) as shipments_processing,
        (
          SELECT COUNT(*) FROM shipments
          WHERE status IN ('Out_for_delivery','In_progress','in_progress','out_for_delivery','Delivering','delivering','جاري التوصيل','في الطريق')
        ) as shipments_delivering,
        (
          SELECT COUNT(*) FROM shipments
          WHERE status IN ('Completed','Delivered','completed','delivered','مكتمل','تم التوصيل')
        ) as shipments_completed,
        (
          SELECT COUNT(*) FROM shipments
          WHERE status IN ('Cancelled','cancelled','ملغي','ملغى')
        ) as shipments_cancelled,

        /* ===== الرحلات ===== */
        /* إجمالي الرحلات = كل الرحلات المسجلة في الجدول */
        (SELECT COUNT(*) FROM trips) as total_trips,
        /* رحلات اليوم = فقط رحلات تاريخها اليوم */
        (SELECT COUNT(*) FROM trips WHERE DATE(date) = CURDATE()) as today_trips,
        /* الرحلات النشطة = أي طلب أو شحنة حالياً قيد التوصيل (كابتن يسير فعلياً) */
        (
          SELECT
            (
              SELECT COUNT(*) FROM orders
              WHERE status IN (
                'Picked Up','In Transit','Captain Arrived',
                'تم التنفيذ','جاري التوصيل','في الطريق',
                'Out_for_delivery','In_progress','in_progress','out_for_delivery',
                'Delivering','delivering'
              )
            )
            +
            (
              SELECT COUNT(*) FROM shipments
              WHERE status IN (
                'Picked Up','In Transit','Captain Arrived',
                'تم التنفيذ','جاري التوصيل','في الطريق',
                'Out_for_delivery','In_progress','in_progress','out_for_delivery',
                'Delivering','delivering'
              )
            )
        ) as active_trips,

        /* ===== المحفظة والأرباح ===== */
        (SELECT COUNT(*) FROM wallet_transactions) as wallet_tx,
        (SELECT COUNT(*) FROM wallet_transactions WHERE type='deposit')  as deposits,
        (SELECT COUNT(*) FROM wallet_transactions WHERE type='withdraw') as withdrawals,
        (
          SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
          WHERE wt.type='withdraw' AND wt.status IN ('pending','Pending')
        ) as withdrawal_requests,
        (
          SELECT COUNT(*) FROM wallet_transactions
          WHERE type='withdraw' AND status IN ('pending','Pending')
        ) as withdrawal_requests_count,

        /* ===== ارباح المنصة = platformShare من كل الشحنات/الطلبات المكتملة ===== */
        (
          SELECT COALESCE(SUM(platformShare), 0) FROM orders
          WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
        ) as platform_profit_orders,
        (
          SELECT COALESCE(SUM(platformShare), 0) FROM shipments
          WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
        ) as platform_profit_shipments,

        /* ===== مستحقات الكابتن = مجموع أرصدة محافظ كل الكباتن ===== */
        (
          SELECT COALESCE(SUM(walletBalance), 0) FROM users
          WHERE role = 'captain'
        ) as captain_dues,

        /* ===== الشكاوى ===== */
        (SELECT COUNT(*) FROM contact_messages) as complaints
    `);

    // حساب الأرقام المجمّعة على مستوى JS
    const s = stats[0];
    s.merchants_and_clients = (Number(s.merchants) + Number(s.clients));
    s.processing  = (Number(s.orders_processing)  + Number(s.shipments_processing));
    s.delivering  = (Number(s.orders_delivering)  + Number(s.shipments_delivering));
    s.completed   = (Number(s.orders_completed)   + Number(s.shipments_completed));
    s.cancelled   = (Number(s.orders_cancelled)   + Number(s.shipments_cancelled));
    s.platform_profit = (
      Number(s.platform_profit_orders) + Number(s.platform_profit_shipments)
    );
    s.captain_dues = Number(s.captain_dues);

    // عدد الكباتن النشطين = من لديهم اتصال Socket فعلي (online حقيقي)
    // activeUsers هو Map<userId, Set<socketId>> محفوظ في app
    const activeUsers = req.app.get('activeUsers') || new Map();
    let activeCaptains = 0;
    if (activeUsers.size > 0) {
      // نحتاج IDs الكباتن فقط
      const [captainIds] = await pool.query(
        `SELECT id FROM users WHERE role='captain' AND status='active'`
      );
      for (const row of captainIds) {
        if (activeUsers.has(String(row.id))) activeCaptains++;
      }
    }
    s.active_captains = activeCaptains;

    // Wallet chart: last 6 months grouped by month
    const [walletChart] = await pool.query(`
      SELECT
        DATE_FORMAT(createdAt, '%Y-%m') as month,
        SUM(CASE WHEN type='deposit' THEN amount ELSE 0 END) as deposits,
        SUM(CASE WHEN type='withdraw' THEN amount ELSE 0 END) as withdrawals
      FROM wallet_transactions
      WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(createdAt, '%Y-%m')
      ORDER BY month ASC
    `);

    // Revenue chart: orders + shipments by month
    const [revenueChart] = await pool.query(`
      SELECT month, SUM(orders) as orders_revenue, SUM(shipments) as shipments_revenue FROM (
        SELECT DATE_FORMAT(createdAt, '%Y-%m') as month, COALESCE(orderPrice + deliveryFee, 0) as orders, 0 as shipments
        FROM orders WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
        UNION ALL
        SELECT DATE_FORMAT(createdAt, '%Y-%m') as month, 0 as orders, COALESCE(price, 0) as shipments
        FROM shipments WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      ) combined GROUP BY month ORDER BY month ASC
    `);

    // ===== 1. Lifecycle Breakdown =====
    const [lifecycleRows] = await pool.query(`
      SELECT 
        SUM(CASE WHEN status IN ('Pending Review', 'pending_review', 'قيد المراجعة', 'Processing', 'Processing', 'Preparing', 'Pending', 'pending', 'new', 'جديد', 'جديدة', 'بانتظار الدفع', 'قيد التفاوض') THEN 1 ELSE 0 END) as under_review_count,

        SUM(CASE WHEN status IN ('Ready For Assignment', 'ready_for_assignment', 'بانتظار تعيين مندوب', 'في انتظار القبول', 'بانتظار القبول', 'pending_approval') THEN 1 ELSE 0 END) as pending_captain_count,

        SUM(CASE WHEN status IN ('Assigned To Captain', 'assigned_to_captain', 'تم تعيين مندوب', 'معينة لكابتن', 'assigned_captain') THEN 1 ELSE 0 END) as captain_assigned_count,

        SUM(CASE WHEN status IN ('Picked Up', 'picked_up', 'تم استلام الشحنة من التاجر', 'تم استلام الشحنة', 'تم الاستلام') THEN 1 ELSE 0 END) as picked_up_count,

        SUM(CASE WHEN status IN ('In Transit', 'in_transit', 'Out_for_delivery', 'out_for_delivery', 'Delivering', 'delivering', 'جاري توصيل الشحنة', 'جاري التوصيل', 'في الطريق') THEN 1 ELSE 0 END) as in_delivery_count,

        SUM(CASE WHEN status IN ('Delivered', 'delivered', 'تم التوصيل') THEN 1 ELSE 0 END) as delivered_count,

        SUM(CASE WHEN status IN ('Completed', 'completed', 'مكتملة', 'مكتمل') THEN 1 ELSE 0 END) as completed_count,

        SUM(CASE WHEN status IN ('Cancelled', 'cancelled', 'ملغاة', 'ملغي', 'ملغى') THEN 1 ELSE 0 END) as cancelled_count,

        SUM(CASE WHEN status IN ('delayed', 'متأخرة', 'متأخر') OR (status NOT IN ('Completed','Delivered','Cancelled','completed','delivered','cancelled','مكتمل','مكتملة','ملغاة') AND createdAt < DATE_SUB(NOW(), INTERVAL 1 DAY)) THEN 1 ELSE 0 END) as delayed_count,

        COUNT(*) as total_count
      FROM (
        SELECT status, createdAt FROM orders
        UNION ALL
        SELECT status, createdAt FROM shipments
      ) all_items
    `);

    const lf = lifecycleRows[0] || {};
    const lifecycleBreakdown = {
      under_review: Number(lf.under_review_count || 0),
      pending_captain: Number(lf.pending_captain_count || 0),
      captain_assigned: Number(lf.captain_assigned_count || 0),
      picked_up: Number(lf.picked_up_count || 0),
      in_delivery: Number(lf.in_delivery_count || 0),
      delivered: Number(lf.delivered_count || 0),
      completed: Number(lf.completed_count || 0),
      cancelled: Number(lf.cancelled_count || 0),
      delayed: Number(lf.delayed_count || 0),
      total: Number(lf.total_count || 0),
    };

    // ===== 2. Recent Notifications =====
    const [recentNotifsRows] = await pool.query(`
      SELECT 
        n.id, n.title, n.body, n.category, n.isRead, n.createdAt,
        CONCAT(u.firstName, ' ', u.lastName) as userName
      FROM notifications n
      LEFT JOIN users u ON u.id = n.userId
      ORDER BY n.createdAt DESC
      LIMIT 10
    `);

    // If notifications table has few rows, fall back to recent contact messages / system alerts
    let recentNotifications = recentNotifsRows.map(n => ({
      id: n.id,
      title: n.title,
      body: n.body,
      category: n.category || 'system',
      isRead: Boolean(n.isRead),
      userName: n.userName || 'النظام',
      createdAt: n.createdAt
    }));

    if (recentNotifications.length === 0) {
      // Create system alerts based on DB states
      const [messagesRows] = await pool.query(`
        SELECT id, name, subject, message, createdAt FROM contact_messages ORDER BY createdAt DESC LIMIT 5
      `);
      recentNotifications = messagesRows.map(m => ({
        id: `cm_${m.id}`,
        title: m.subject || 'رسالة تواصل جديدة',
        body: `من ${m.name}: ${m.message.substring(0, 50)}`,
        category: 'message',
        isRead: false,
        userName: m.name,
        createdAt: m.createdAt
      }));
    }

    // ===== 3. Area Distribution =====
    const [areaRows] = await pool.query(`
      SELECT area, COUNT(*) as count FROM (
        SELECT fromArea as area FROM shipments WHERE fromArea IS NOT NULL AND TRIM(fromArea) != ''
        UNION ALL
        SELECT toArea as area FROM shipments WHERE toArea IS NOT NULL AND TRIM(toArea) != ''
        UNION ALL
        SELECT 'العجمي' as area FROM orders WHERE deliveryAddress LIKE '%العجمي%'
        UNION ALL
        SELECT 'الدخيلة' as area FROM orders WHERE deliveryAddress LIKE '%الدخيلة%'
        UNION ALL
        SELECT 'العامرية' as area FROM orders WHERE deliveryAddress LIKE '%العامرية%'
        UNION ALL
        SELECT 'كرموز' as area FROM orders WHERE deliveryAddress LIKE '%كرموز%'
        UNION ALL
        SELECT 'محطة مصر' as area FROM orders WHERE deliveryAddress LIKE '%مصر%'
        UNION ALL
        SELECT 'سموحة' as area FROM orders WHERE deliveryAddress LIKE '%سموحة%'
        UNION ALL
        SELECT 'سيدي جابر' as area FROM orders WHERE deliveryAddress LIKE '%جابر%'
        UNION ALL
        SELECT 'ميامي' as area FROM orders WHERE deliveryAddress LIKE '%ميامي%'
      ) areas_combined
      GROUP BY area
      ORDER BY count DESC
      LIMIT 10
    `);

    const totalAreaItems = areaRows.reduce((sum, r) => sum + Number(r.count), 0) || 1;
    const areaDistribution = areaRows.map(r => ({
      area: r.area,
      count: Number(r.count),
      percentage: parseFloat(((Number(r.count) / totalAreaItems) * 100).toFixed(1))
    }));

    // ===== 4. Platform Commissions Breakdown & Dynamic Growth Rates =====
    const [commissionStats] = await pool.query(`
      SELECT 
        COALESCE(SUM(CASE WHEN DATE(createdAt) = CURDATE() THEN platformShare ELSE 0 END), 0) as today,
        COALESCE(SUM(CASE WHEN DATE(createdAt) = CURDATE() - INTERVAL 1 DAY THEN platformShare ELSE 0 END), 0) as yesterday,
        
        COALESCE(SUM(CASE WHEN createdAt >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN platformShare ELSE 0 END), 0) as week,
        COALESCE(SUM(CASE WHEN createdAt BETWEEN DATE_SUB(NOW(), INTERVAL 14 DAY) AND DATE_SUB(NOW(), INTERVAL 7 DAY) THEN platformShare ELSE 0 END), 0) as prevWeek,
        
        COALESCE(SUM(CASE WHEN createdAt >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN platformShare ELSE 0 END), 0) as month,
        COALESCE(SUM(CASE WHEN createdAt BETWEEN DATE_SUB(NOW(), INTERVAL 60 DAY) AND DATE_SUB(NOW(), INTERVAL 30 DAY) THEN platformShare ELSE 0 END), 0) as prevMonth,
        
        COALESCE(SUM(platformShare), 0) as total
      FROM (
        SELECT platformShare, createdAt FROM orders WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
        UNION ALL
        SELECT platformShare, createdAt FROM shipments WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
      ) comm_items
    `);

    const cStat = commissionStats[0] || {};
    const todayAmount = Number(cStat.today || 0);
    const yesterdayAmount = Number(cStat.yesterday || 0);
    const weekAmount = Number(cStat.week || 0);
    const prevWeekAmount = Number(cStat.prevWeek || 0);
    const monthAmount = Number(cStat.month || 0);
    const prevMonthAmount = Number(cStat.prevMonth || 0);
    const totalAmount = Number(cStat.total || 0);

    const calcGrowth = (current, previous) => {
      if (previous > 0) {
        return parseFloat((((current - previous) / previous) * 100).toFixed(1));
      } else if (current > 0) {
        return 100.0;
      }
      return 0.0;
    };

    const todayGrowth = calcGrowth(todayAmount, yesterdayAmount);
    const weekGrowth = calcGrowth(weekAmount, prevWeekAmount);
    const monthGrowth = calcGrowth(monthAmount, prevMonthAmount);

    const arabicMonthNames = {
      '01': 'يناير', '02': 'فبراير', '03': 'مارس', '04': 'أبريل',
      '05': 'مايو', '06': 'يونيو', '07': 'يوليو', '08': 'أغسطس',
      '09': 'سبتمبر', '10': 'أكتوبر', '11': 'نوفمبر', '12': 'ديسمبر'
    };

    // 1) 7 Days chart
    const [comm7DaysRows] = await pool.query(`
      SELECT 
        DATE_FORMAT(d.date_val, '%d') as day_num,
        DATE_FORMAT(d.date_val, '%m') as month_num,
        COALESCE(SUM(c.platformShare), 0) as amount
      FROM (
        SELECT CURDATE() - INTERVAL (a.a) DAY as date_val
        FROM (SELECT 0 as a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6) as a
      ) d
      LEFT JOIN (
        SELECT platformShare, createdAt FROM orders WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
        UNION ALL
        SELECT platformShare, createdAt FROM shipments WHERE status IN ('Completed', 'Delivered', 'completed', 'delivered')
      ) c ON DATE(c.createdAt) = d.date_val
      GROUP BY d.date_val, day_num, month_num
      ORDER BY d.date_val ASC
    `);

    const chart7Days = comm7DaysRows.map(r => ({
      day: `${r.day_num} ${arabicMonthNames[r.month_num] || r.month_num}`,
      amount: Number(r.amount)
    }));

    // 2) Monthly chart (last 30 days grouped by day)
    const [commMonthlyRows] = await pool.query(`
      SELECT 
        DATE_FORMAT(d.date_val, '%d') as day_num,
        DATE_FORMAT(d.date_val, '%m') as month_num,
        COALESCE(SUM(c.platformShare), 0) as amount
      FROM (
        SELECT CURDATE() - INTERVAL (a.a + b.a * 6) DAY as date_val
        FROM (SELECT 0 as a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) as a
        CROSS JOIN (SELECT 0 as a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) as b
        WHERE (a.a + b.a * 6) < 30
      ) d
      LEFT JOIN (
        SELECT platformShare, createdAt FROM orders WHERE isPaid = 1
        UNION ALL
        SELECT platformShare, createdAt FROM shipments WHERE isPaid = 1
      ) c ON DATE(c.createdAt) = d.date_val
      GROUP BY d.date_val, day_num, month_num
      ORDER BY d.date_val ASC
    `);

    const chartMonthly = commMonthlyRows.map(r => ({
      day: `${r.day_num} ${arabicMonthNames[r.month_num] || r.month_num}`,
      amount: Number(r.amount)
    }));

    // 3) Quarterly, Semi-Annual, Yearly charts (grouped by month)
    // 3) Quarterly, Semi-Annual, Yearly charts (guaranteed all months exist)
    const monthsList = [];
    const now = new Date();
    for (let i = 11; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const yearMonth = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const mNum = String(d.getMonth() + 1).padStart(2, '0');
      monthsList.push({
        key: yearMonth,
        monthNum: mNum,
        name: arabicMonthNames[mNum] || mNum,
      });
    }

    const [commMonthsRows] = await pool.query(`
      SELECT 
        DATE_FORMAT(createdAt, '%Y-%m') as month_key,
        COALESCE(SUM(platformShare), 0) as amount
      FROM (
        SELECT platformShare, createdAt FROM orders WHERE isPaid = 1
        UNION ALL
        SELECT platformShare, createdAt FROM shipments WHERE isPaid = 1
      ) c
      WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
      GROUP BY month_key
    `);

    const monthAmountMap = {};
    for (const r of commMonthsRows) {
      monthAmountMap[r.month_key] = Number(r.amount || 0);
    }

    const monthsData = monthsList.map(m => ({
      day: m.name,
      amount: monthAmountMap[m.key] || 0
    }));

    const chartQuarterly = monthsData.slice(-3);
    const chartSemiAnnual = monthsData.slice(-6);
    const chartYearly = monthsData.slice(-12);

    const platformCommissions = {
      today: todayAmount,
      todayGrowth: todayGrowth,
      week: weekAmount,
      weekGrowth: weekGrowth,
      month: monthAmount,
      monthGrowth: monthGrowth,
      total: totalAmount,
      chart7Days: chart7Days,
      chartMonthly: chartMonthly,
      chartQuarterly: chartQuarterly,
      chartSemiAnnual: chartSemiAnnual,
      chartYearly: chartYearly,
    };

    // ===== 5. Withdrawal Requests Summary =====
    const [withdrawSummaryRows] = await pool.query(`
      SELECT 
        SUM(CASE WHEN status IN ('pending', 'Pending', 'new') THEN 1 ELSE 0 END) as new_count,
        SUM(CASE WHEN status IN ('under_review', 'underReview', 'مراجعة') THEN 1 ELSE 0 END) as under_review_count,
        SUM(CASE WHEN status IN ('transferred', 'completed', 'success', 'Approved', 'approved') THEN 1 ELSE 0 END) as transferred_count,
        SUM(CASE WHEN status IN ('rejected', 'Rejected', 'failed', 'مرفوض') THEN 1 ELSE 0 END) as rejected_count,
        COALESCE(SUM(amount), 0) as total_amount
      FROM wallet_transactions
      WHERE type = 'withdraw'
    `);

    const wSum = withdrawSummaryRows[0] || {};

    const withdrawalSummary = {
      new: Number(wSum.new_count || 0),
      underReview: Number(wSum.under_review_count || 0),
      transferred: Number(wSum.transferred_count || 0),
      rejected: Number(wSum.rejected_count || 0),
      totalAmount: Number(wSum.total_amount || 0)
    };

    // ===== 6. Top Captains =====
    const [topCaptainsRows] = await pool.query(`
      SELECT 
        u.id,
        CONCAT(u.firstName, ' ', u.lastName) as name,
        u.profileImage,
        (
          SELECT COUNT(*) FROM (
            SELECT captainId FROM orders WHERE status IN ('Completed','Delivered','completed','delivered','مكتمل')
            UNION ALL
            SELECT captainId FROM shipments WHERE status IN ('Completed','Delivered','completed','delivered','مكتمل')
          ) completed_tasks WHERE captainId = u.id
        ) as ordersCount,
        COALESCE(
          (SELECT AVG(rating) FROM reviews WHERE revieweeId = u.id),
          4.8
        ) as rating
      FROM users u
      WHERE u.role = 'captain' AND u.status = 'active'
      ORDER BY ordersCount DESC, rating DESC
      LIMIT 5
    `);

    const topCaptains = topCaptainsRows.map((c, idx) => ({
      rank: idx + 1,
      id: c.id,
      name: c.name,
      profileImage: c.profileImage,
      ordersCount: Number(c.ordersCount || 0),
      successRate: 95 + (5 - idx),
      rating: parseFloat(Number(c.rating || 4.8).toFixed(1))
    }));

    // ===== 7. Live Map Data Items =====
    const [mapCaptains] = await pool.query(`
      SELECT id, CONCAT(firstName, ' ', lastName) as name, latitude, longitude, 'captain' as type
      FROM users WHERE role = 'captain' AND latitude IS NOT NULL AND status = 'active'
    `);

    const [mapOrders] = await pool.query(`
      SELECT id, orderNumber as number, latitude, longitude, status, 'order' as type
      FROM orders WHERE latitude IS NOT NULL AND status NOT IN ('Completed','Cancelled','Delivered')
      LIMIT 30
    `);

    const mapItems = [...mapCaptains, ...mapOrders];

    // ===== 8. Active Captains Now (Strictly Online Connected Sockets) =====
    const [allActiveCaptains] = await pool.query(`
      SELECT id, CONCAT(firstName, ' ', lastName) as name, profileImage, status, updatedAt
      FROM users WHERE role = 'captain' AND status = 'active'
      ORDER BY updatedAt DESC
    `);

    // Only captains who have the app connected/online right now
    const onlineCaptains = allActiveCaptains.filter(c => activeUsers.has(String(c.id)));

    const activeCaptainsNow = {
      count: onlineCaptains.length,
      captains: onlineCaptains.map(c => ({
        id: c.id,
        name: c.name,
        profileImage: c.profileImage,
        isOnline: true
      }))
    };

    // ===== 9. Users By Role =====
    const [usersByRole] = await pool.query(`
      SELECT role, COUNT(*) as count FROM users GROUP BY role
    `);

    // ===== 10. Today Trips & Stats =====
    const [todayTripsRows] = await pool.query(`
      SELECT
        t.id, t.driverId, t.fromAddress, t.toAddress, t.date, t.time,
        t.status, t.price, t.distance, t.createdAt,
        t.departureTime, t.arrivalTime,
        CONCAT(u.firstName, ' ', u.lastName) as captainName,
        u.profileImage, u.phone as captainPhone,
        (
          SELECT COUNT(*) FROM (
            SELECT id FROM shipments WHERE captainId = t.driverId AND status NOT IN ('Cancelled')
            UNION ALL
            SELECT id FROM orders WHERE captainId = t.driverId AND status NOT IN ('Cancelled')
          ) trip_items
        ) as shipmentsCount
      FROM trips t
      JOIN users u ON u.id = t.driverId
      WHERE t.date = CURDATE() OR t.createdAt >= CURDATE() - INTERVAL 2 DAY
      ORDER BY t.createdAt DESC
      LIMIT 10
    `);

    const todayTripsProcessed = addEffectiveStatusBulk(todayTripsRows);
    
    for (const trip of todayTripsProcessed) {
      const [tripShipments] = await pool.query(`
        SELECT id, shipmentNumber as number, title, fromAddress, toAddress, status, price, 'shipment' as type
        FROM shipments WHERE captainId = ? AND status NOT IN ('Cancelled')
        ORDER BY createdAt DESC
        LIMIT 10
      `, [trip.driverId]);

      const [tripOrders] = await pool.query(`
        SELECT id, orderNumber as number, details as title, storeDescription as fromAddress, deliveryAddress as toAddress, status, orderPrice as price, 'order' as type
        FROM orders WHERE captainId = ? AND status NOT IN ('Cancelled')
        ORDER BY createdAt DESC
        LIMIT 10
      `, [trip.driverId]);

      trip.assignedItems = [...tripShipments, ...tripOrders];
    }

    const todayTrips = todayTripsProcessed;

    let completedCount = 0;
    let inProgressCount = 0;
    let cancelledCount = 0;

    todayTrips.forEach(t => {
      const dbStatus = t.status || '';
      const eff = t.effectiveStatus || dbStatus;
      if (dbStatus === 'completed' || eff === 'completed') {
        completedCount++;
      } else if (dbStatus === 'cancelled' || eff === 'cancelled') {
        cancelledCount++;
      } else if (eff === 'expired') {
        completedCount++;
      } else {
        inProgressCount++;
      }
    });

    const todayTripStats = [{
      total: todayTrips.length,
      completed: completedCount,
      inProgress: inProgressCount,
      cancelled: cancelledCount
    }];

    // ===== 11. Today Orders & Shipments =====
    const [todayOrders] = await pool.query(`
      SELECT
        o.id, o.orderNumber, o.details, o.storeDescription, o.notes,
        o.deliveryAddress, o.clientName, o.phone, o.orderPrice, o.deliveryFee,
        o.latitude, o.longitude, o.status, o.createdAt,
        COALESCE(u.storeName, CONCAT(u.firstName, ' ', u.lastName)) as merchantName,
        CONCAT(c.firstName, ' ', c.lastName) as captainName,
        o.assignedAdminId,
        CONCAT(a.firstName, ' ', a.lastName) as assignedAdminName
      FROM orders o
      LEFT JOIN users u ON u.id = o.merchantId
      LEFT JOIN users c ON c.id = o.captainId
      LEFT JOIN users a ON a.id = o.assignedAdminId
      WHERE (o.status NOT IN ('Completed', 'Delivered', 'Cancelled'))
         OR (o.createdAt >= NOW() - INTERVAL 2 DAY)
      ORDER BY o.createdAt DESC
    `);

    const [todayShipments] = await pool.query(`
      SELECT
        s.id, s.shipmentNumber, s.title, s.fromAddress, s.toAddress,
        s.fromGovernorate, s.fromArea, s.toGovernorate, s.toArea,
        s.status, s.estimatedTime, s.price, s.weight, s.notes,
        s.isFragile, s.isWithoutAdvance, s.createdAt,
        COALESCE(u.storeName, CONCAT(u.firstName, ' ', u.lastName)) as merchantName,
        CONCAT(c.firstName, ' ', c.lastName) as captainName,
        s.assignedAdminId,
        CONCAT(a.firstName, ' ', a.lastName) as assignedAdminName
      FROM shipments s
      LEFT JOIN users u ON u.id = s.merchantId
      LEFT JOIN users c ON c.id = s.captainId
      LEFT JOIN users a ON a.id = s.assignedAdminId
      WHERE (s.status NOT IN ('Completed', 'Cancelled'))
         OR (s.createdAt >= NOW() - INTERVAL 2 DAY)
      ORDER BY s.createdAt DESC
    `);

    res.status(200).json({
      status: 1,
      data: {
        stats: { ...s, active_captains: onlineCaptains.length },
        lifecycleBreakdown,
        recentNotifications,
        areaDistribution,
        platformCommissions,
        withdrawalSummary,
        topCaptains,
        mapItems,
        activeCaptainsNow,
        walletChart,
        revenueChart,
        usersByRole,
        todayTrips,
        todayTripStats: todayTripStats[0],
        todayOrders,
        todayShipments,
      },
    });
  } catch (error) {
    console.error('Error in getDashboard:', error);
    res.status(500).json({
      status: 0,
      message: error.message || 'حدث خطأ في السيرفر أثناء جلب بيانات لوحة التحكم',
    });
  }
};

module.exports = { getDashboard };
