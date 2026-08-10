const { getPool } = require('../config/db');

// 1. CREATE OR UPDATE A REVIEW
const createReview = async (req, res, next) => {
  try {
    const pool = getPool();
    const reviewerId = req.user.id;
    let { shipmentId, rating, comment, tags } = req.body;
    let orderId = null;

    if (shipmentId && shipmentId.toString().startsWith('order_')) {
      orderId = parseInt(shipmentId.toString().replace('order_', ''));
      shipmentId = null;
    }

    if (!shipmentId && !orderId) {
      return res.status(400).json({
        status: 0,
        message: 'معرف الشحنة أو معرف الطلب مطلوب'
      });
    }

    if (!rating) {
      return res.status(400).json({
        status: 0,
        message: 'التقييم مطلوب'
      });
    }

    const ratingVal = parseInt(rating);
    if (ratingVal < 1 || ratingVal > 5) {
      return res.status(400).json({
        status: 0,
        message: 'التقييم يجب ان يكون بين 1 و 5'
      });
    }

    let revieweeId = null;

    if (shipmentId) {
      // Check if shipment exists and is completed (status = 'منتهية')
      const [shipments] = await pool.query(
        'SELECT id, merchantId, captainId, status FROM shipments WHERE id = ?',
        [shipmentId]
      );

      if (shipments.length === 0) {
        return res.status(404).json({
          status: 0,
          message: 'الشحنة غير موجودة'
        });
      }

      const shipment = shipments[0];
      if (shipment.status !== 'منتهية' && shipment.status !== 'Completed') {
        return res.status(400).json({
          status: 0,
          message: 'لا يمكن تقييم شحنة لم تكتمل بعد'
        });
      }

      if (reviewerId === shipment.merchantId) {
        revieweeId = shipment.captainId;
      } else if (reviewerId === shipment.captainId) {
        revieweeId = shipment.merchantId;
      }
    } else if (orderId) {
      // Check if order exists and is finished (status = 'منتهي')
      const [orders] = await pool.query(
        'SELECT id, merchantId, captainId, status FROM orders WHERE id = ?',
        [orderId]
      );

      if (orders.length === 0) {
        return res.status(404).json({
          status: 0,
          message: 'الطلب غير موجود'
        });
      }

      const order = orders[0];
      // الحالة النهائية الوحيدة للطلب هي 'Completed'
      if (order.status !== 'Completed') {
        return res.status(400).json({
          status: 0,
          message: 'لا يمكن تقييم طلب لم يكتمل بعد'
        });
      }

      if (reviewerId === order.merchantId) {
        revieweeId = order.captainId;
      } else if (reviewerId === order.captainId) {
        revieweeId = order.merchantId;
      }
    }

    if (!revieweeId) {
      return res.status(403).json({
        status: 0,
        message: 'غير مسموح لك بتقييم هذه المعاملة'
      });
    }

    const tagsJson = tags ? JSON.stringify(tags) : null;

    // Check if review already exists
    let existingReviewSql = '';
    let existingReviewParams = [];
    if (shipmentId) {
      existingReviewSql = 'SELECT id FROM reviews WHERE shipmentId = ? AND reviewerId = ?';
      existingReviewParams = [shipmentId, reviewerId];
    } else {
      existingReviewSql = 'SELECT id FROM reviews WHERE orderId = ? AND reviewerId = ?';
      existingReviewParams = [orderId, reviewerId];
    }

    const [existing] = await pool.query(existingReviewSql, existingReviewParams);

    if (existing.length > 0) {
      // Update existing review
      await pool.query(
        'UPDATE reviews SET rating = ?, comment = ?, tags = ? WHERE id = ?',
        [ratingVal, comment || null, tagsJson, existing[0].id]
      );
    } else {
      // Insert new review
      await pool.query(
        `INSERT INTO reviews (shipmentId, orderId, reviewerId, revieweeId, rating, comment, tags)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [shipmentId || null, orderId || null, reviewerId, revieweeId, ratingVal, comment || null, tagsJson]
      );
    }

    res.status(200).json({
      status: 1,
      message: 'تم حفظ التقييم بنجاح'
    });
  } catch (error) {
    next(error);
  }
};

// 2. GET REVIEWS RECEIVED BY CURRENT USER (Tab 0)
const getMyReviews = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    // Fetch review list
    const [reviews] = await pool.query(
      `SELECT 
        r.id, r.shipmentId, r.orderId, r.reviewerId, r.revieweeId, r.rating, r.comment, r.tags, r.createdAt,
        COALESCE(s.shipmentNumber, o.orderNumber) as shipmentNumber,
        u.firstName, u.lastName, u.profileImage
       FROM reviews r
       LEFT JOIN shipments s ON r.shipmentId = s.id
       LEFT JOIN orders o ON r.orderId = o.id
       JOIN users u ON r.reviewerId = u.id
       WHERE r.revieweeId = ?
       ORDER BY r.createdAt DESC`,
      [userId]
    );

    // Fetch summary stats
    const [summaryRows] = await pool.query(
      `SELECT 
        COUNT(*) as totalCount,
        IFNULL(AVG(rating), 0) as avgRating,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as star5,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as star4,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as star3,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as star2,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as star1
       FROM reviews
       WHERE revieweeId = ?`,
      [userId]
    );

    const summary = summaryRows[0] || {
      totalCount: 0,
      avgRating: 0,
      star5: 0,
      star4: 0,
      star3: 0,
      star2: 0,
      star1: 0
    };

    const avgRating = parseFloat(parseFloat(summary.avgRating).toFixed(1));
    const starCounts = {
      5: parseInt(summary.star5 || 0),
      4: parseInt(summary.star4 || 0),
      3: parseInt(summary.star3 || 0),
      2: parseInt(summary.star2 || 0),
      1: parseInt(summary.star1 || 0)
    };

    res.status(200).json({
      status: 1,
      message: 'تم تحميل التقييمات بنجاح',
      data: {
        totalCount: parseInt(summary.totalCount || 0),
        avgRating: avgRating,
        starCounts: starCounts,
        reviews: reviews.map(row => ({
          id: row.id.toString(),
          shipmentId: row.shipmentId ? row.shipmentId.toString() : '',
          orderId: row.orderId ? row.orderId.toString() : '',
          shipmentNumber: row.shipmentNumber || '',
          reviewerId: row.reviewerId.toString(),
          reviewerName: `${row.firstName} ${row.lastName}`,
          reviewerAvatar: row.profileImage || '',
          rating: row.rating,
          comment: row.comment || '',
          tags: typeof row.tags === 'string' ? JSON.parse(row.tags) : (row.tags || []),
          createdAt: row.createdAt
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. GET REVIEWS GIVEN BY CURRENT USER (Tab 1)
const getGivenReviews = async (req, res, next) => {
  try {
    const pool = getPool();
    const userId = req.user.id;

    const [reviews] = await pool.query(
      `SELECT 
        r.id, r.shipmentId, r.orderId, r.reviewerId, r.revieweeId, r.rating, r.comment, r.tags, r.createdAt,
        COALESCE(s.shipmentNumber, o.orderNumber) as shipmentNumber,
        u.firstName, u.lastName, u.profileImage
       FROM reviews r
       LEFT JOIN shipments s ON r.shipmentId = s.id
       LEFT JOIN orders o ON r.orderId = o.id
       JOIN users u ON r.revieweeId = u.id
       WHERE r.reviewerId = ?
       ORDER BY r.createdAt DESC`,
      [userId]
    );

    res.status(200).json({
      status: 1,
      message: 'تم تحميل التقييمات المرسلة بنجاح',
      data: reviews.map(row => ({
        id: row.id.toString(),
        shipmentId: row.shipmentId ? row.shipmentId.toString() : '',
        orderId: row.orderId ? row.orderId.toString() : '',
        shipmentNumber: row.shipmentNumber || '',
        reviewerId: row.reviewerId.toString(), // user is reviewer, but in Flutter we'll map reviewerName/avatar to the target person being listed in given reviews tab (the reviewee)
        reviewerName: `${row.firstName} ${row.lastName}`,
        reviewerAvatar: row.profileImage || '',
        rating: row.rating,
        comment: row.comment || '',
        tags: typeof row.tags === 'string' ? JSON.parse(row.tags) : (row.tags || []),
        createdAt: row.createdAt
      }))
    });
  } catch (error) {
    next(error);
  }
};

// 4. GET RATING SUMMARY FOR A SPECIFIC USER (by userId)
const getUserRating = async (req, res, next) => {
  try {
    const pool = getPool();
    const { userId } = req.params;

    const [summaryRows] = await pool.query(
      `SELECT 
        COUNT(*) as totalCount,
        IFNULL(AVG(rating), 0) as avgRating,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as star5,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as star4,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as star3,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as star2,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as star1
       FROM reviews
       WHERE revieweeId = ?`,
      [userId]
    );

    const summary = summaryRows[0] || { totalCount: 0, avgRating: 0 };
    const avgRating = parseFloat(parseFloat(summary.avgRating).toFixed(1));

    res.status(200).json({
      status: 1,
      message: 'تم تحميل التقييم بنجاح',
      data: {
        userId: userId.toString(),
        totalCount: parseInt(summary.totalCount || 0),
        avgRating: avgRating,
        starCounts: {
          5: parseInt(summary.star5 || 0),
          4: parseInt(summary.star4 || 0),
          3: parseInt(summary.star3 || 0),
          2: parseInt(summary.star2 || 0),
          1: parseInt(summary.star1 || 0)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// 5. CHECK IF CURRENT USER ALREADY REVIEWED A SHIPMENT
const checkReviewStatus = async (req, res, next) => {
  try {
    const pool = getPool();
    const reviewerId = req.user.id;
    const { shipmentId } = req.params;

    const [rows] = await pool.query(
      'SELECT id, rating, comment, tags FROM reviews WHERE shipmentId = ? AND reviewerId = ?',
      [shipmentId, reviewerId]
    );

    if (rows.length === 0) {
      return res.status(200).json({ status: 1, hasReviewed: false, review: null });
    }

    const r = rows[0];
    res.status(200).json({
      status: 1,
      hasReviewed: true,
      review: {
        id: r.id.toString(),
        rating: r.rating,
        comment: r.comment || '',
        tags: typeof r.tags === 'string' ? JSON.parse(r.tags) : (r.tags || [])
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createReview,
  getMyReviews,
  getGivenReviews,
  getUserRating,
  checkReviewStatus
};
