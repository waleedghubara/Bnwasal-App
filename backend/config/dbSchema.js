const addColumnIfNotExists = async (pool, tableName, columnName, columnDefinition) => {
  try {
    const [cols] = await pool.query(
      `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
      [tableName, columnName]
    );
    if (cols[0].cnt === 0) {
      await pool.query(`ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${columnDefinition}`);
    }
  } catch (err) {
    console.error(`Error adding column ${columnName} to ${tableName}:`, err);
  }
};

const addForeignKeyIfNotExists = async (pool, tableName, columnName, refTableName, refColumnName, onDeleteAction = 'CASCADE') => {
  try {
    const [fk] = await pool.query(
      `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? 
         AND REFERENCED_TABLE_NAME = ? AND REFERENCED_COLUMN_NAME = ?`,
      [tableName, columnName, refTableName, refColumnName]
    );
    if (fk[0].cnt === 0) {
      await pool.query(
        `ALTER TABLE \`${tableName}\` ADD FOREIGN KEY (\`${columnName}\`) REFERENCES \`${refTableName}\`(\`${refColumnName}\`) ON DELETE ${onDeleteAction}`
      );
    }
  } catch (err) {
    console.error(`Error adding foreign key constraint ${tableName}(${columnName}) to ${refTableName}(${refColumnName}):`, err);
  }
};

const setupDatabaseSchema = async (pool) => {
  try {
    const queries = [
      `CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        firstName VARCHAR(50) NOT NULL,
        lastName VARCHAR(50) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        role ENUM('client', 'merchant', 'captain', 'admin', 'employee') NOT NULL DEFAULT 'client',
        status ENUM('pending_otp', 'pending_verification', 'active', 'banned') DEFAULT 'pending_otp',
        otp_code VARCHAR(6) NULL,
        otp_expiry DATETIME NULL,
        reset_otp VARCHAR(6) NULL,
        reset_otp_expiry DATETIME NULL,
        profileImage VARCHAR(255) NULL,
        storeName VARCHAR(100) NULL,
        city VARCHAR(50) NULL,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        points INT DEFAULT 0,
        vehicleType VARCHAR(50) NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;`,
      
      `CREATE TABLE IF NOT EXISTS driver_documents (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT UNIQUE NOT NULL,
        nationalId VARCHAR(14) NOT NULL,
        nationalIdFront VARCHAR(255) NOT NULL,
        nationalIdBack VARCHAR(255) NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS refresh_tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        token VARCHAR(500) NOT NULL,
        expiresAt DATETIME NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS shipments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shipmentNumber VARCHAR(50) UNIQUE NOT NULL,
        merchantId INT NOT NULL,
        captainId INT NULL,
        title VARCHAR(100) NULL,
        fromAddress TEXT NOT NULL,
        toAddress TEXT NOT NULL,
        fromGovernorate VARCHAR(50) NULL,
        fromArea VARCHAR(50) NULL,
        toGovernorate VARCHAR(50) NULL,
        toArea VARCHAR(50) NULL,
        status VARCHAR(50) DEFAULT 'جديدة',
        estimatedTime VARCHAR(50) NULL,
        price DECIMAL(10,2) NOT NULL,
        weight DECIMAL(10,2) NULL,
        notes TEXT NULL,
        isFragile TINYINT(1) DEFAULT 0,
        isWithoutAdvance TINYINT(1) DEFAULT 0,
        toLatitude DOUBLE NULL,
        toLongitude DOUBLE NULL,
        merchantLatitude DOUBLE NULL,
        merchantLongitude DOUBLE NULL,
        captainApprovalStatus VARCHAR(20) DEFAULT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (captainId) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS shipment_images (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shipmentId INT NOT NULL,
        imageUrl VARCHAR(255) NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shipmentId INT NOT NULL,
        senderId INT NOT NULL,
        receiverId INT NOT NULL,
        text TEXT NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE CASCADE,
        FOREIGN KEY (senderId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (receiverId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS addresses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        label VARCHAR(100) NULL,
        phone VARCHAR(20) NULL,
        governorate VARCHAR(50) NULL,
        city VARCHAR(50) NULL,
        detail TEXT NULL,
        locationText VARCHAR(255) NULL,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS reviews (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shipmentId INT NULL,
        orderId INT NULL,
        reviewerId INT NOT NULL,
        revieweeId INT NOT NULL,
        rating TINYINT NOT NULL,
        comment TEXT NULL,
        tags JSON NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE CASCADE,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewerId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (revieweeId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        orderNumber VARCHAR(50) UNIQUE NOT NULL,
        merchantId INT NOT NULL,
        clientId INT NULL,
        captainId INT NULL,
        details TEXT NOT NULL,
        storeDescription TEXT NOT NULL,
        notes TEXT NULL,
        deliveryAddress TEXT NOT NULL,
        clientName VARCHAR(100) NOT NULL,
        phone VARCHAR(20) NOT NULL,
        orderPrice DECIMAL(10,2) NOT NULL DEFAULT 0,
        deliveryFee DECIMAL(10,2) NOT NULL DEFAULT 0,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        captainApprovalStatus VARCHAR(20) DEFAULT NULL,
        status VARCHAR(50) DEFAULT 'بانتظار القبول',
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (captainId) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB;`,
      
      `CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        category VARCHAR(50) NOT NULL DEFAULT 'system',
        isRead TINYINT(1) DEFAULT 0,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS trips (
        id INT AUTO_INCREMENT PRIMARY KEY,
        driverId INT NOT NULL,
        fromAddress VARCHAR(255) NOT NULL,
        toAddress VARCHAR(255) NOT NULL,
        date DATE NOT NULL,
        time VARCHAR(50) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        price DECIMAL(10,2) NULL,
        distance DECIMAL(10,2) NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (driverId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS shifts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        serviceArea VARCHAR(100) NOT NULL,
        date DATE NOT NULL,
        startTime VARCHAR(20) NOT NULL,
        endTime VARCHAR(20) NOT NULL,
        maxCaptains INT DEFAULT 10,
        status ENUM('scheduled', 'active', 'completed', 'cancelled') DEFAULT 'scheduled',
        notes TEXT NULL,
        createdBy INT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_shift_date (date),
        INDEX idx_shift_area (serviceArea),
        INDEX idx_shift_status (status)
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS shift_captains (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shiftId INT NOT NULL,
        captainId INT NOT NULL,
        status ENUM('joined', 'active', 'completed', 'cancelled') DEFAULT 'joined',
        joinedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        clockInTime DATETIME NULL,
        clockOutTime DATETIME NULL,
        isOnBreak TINYINT(1) DEFAULT 0,
        breakStartTime DATETIME NULL,
        breakEndTime DATETIME NULL,
        breakDurationMinutes INT DEFAULT 0,
        totalBreakMinutesUsed INT DEFAULT 0,
        ordersCount INT DEFAULT 0,
        totalEarnings DECIMAL(10,2) DEFAULT 0.00,
        UNIQUE KEY unique_shift_captain (shiftId, captainId),
        FOREIGN KEY (shiftId) REFERENCES shifts(id) ON DELETE CASCADE,
        FOREIGN KEY (captainId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS referrals (
        id INT AUTO_INCREMENT PRIMARY KEY,
        referrerId INT NOT NULL,
        refereeId INT UNIQUE NOT NULL,
        status ENUM('pending', 'completed', 'rewarded') DEFAULT 'pending',
        rewardAmount DECIMAL(10,2) DEFAULT 15.00,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (referrerId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (refereeId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS wallet_transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        type ENUM('deposit', 'withdraw') NOT NULL,
        status VARCHAR(50) DEFAULT 'success',
        reference VARCHAR(100) NULL,
        paymentMethod VARCHAR(50) NULL,
        accountDetails TEXT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS contact_messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NULL,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        subject VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        source ENUM('app', 'website') DEFAULT 'app',
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS support_messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        senderId INT NOT NULL,
        text TEXT NOT NULL,
        image VARCHAR(255) NULL,
        status ENUM('sent', 'delivered', 'read') DEFAULT 'sent',
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (senderId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`,

      `CREATE TABLE IF NOT EXISTS order_status_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        orderId INT NULL,
        shipmentId INT NULL,
        userId INT NULL,
        userName VARCHAR(100) NULL,
        userRole VARCHAR(50) NOT NULL,
        previousStatus VARCHAR(50) NULL,
        newStatus VARCHAR(50) NOT NULL,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB;`
    ];

    for (const query of queries) {
      await pool.query(query);
    }

    // Add columns if they don't exist (migration for existing tables)
    await addColumnIfNotExists(pool, 'users', 'vehicleType', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'users', 'reset_otp', 'VARCHAR(6) NULL');
    await addColumnIfNotExists(pool, 'users', 'reset_otp_expiry', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'users', 'storeName', 'VARCHAR(100) NULL');
    await addColumnIfNotExists(pool, 'users', 'city', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'users', 'latitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'users', 'longitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'users', 'isLocationConfirmed', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'stores', 'isLocationConfirmed', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'users', 'fcmToken', 'VARCHAR(255) NULL');

    await addColumnIfNotExists(pool, 'shipments', 'negotiatedPrice', 'DECIMAL(10,2) NULL');
    await addColumnIfNotExists(pool, 'shipments', 'startLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'startLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'merchantLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'merchantLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'pickupNearbyNotified', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'shipments', 'deliveryNearbyNotified', 'TINYINT(1) DEFAULT 0');

    await addColumnIfNotExists(pool, 'orders', 'startLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'orders', 'startLongitude', 'DOUBLE NULL');

    await addColumnIfNotExists(pool, 'shipments', 'assignedAdminId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'shipments', 'assignedAdminId', 'users', 'id', 'SET NULL');
    await addColumnIfNotExists(pool, 'orders', 'assignedAdminId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'orders', 'assignedAdminId', 'users', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'users', 'referralCode', 'VARCHAR(50) UNIQUE NULL');
    await addColumnIfNotExists(pool, 'users', 'referredBy', 'INT NULL');
    await addColumnIfNotExists(pool, 'users', 'walletBalance', 'DECIMAL(10,2) NOT NULL DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'users', 'nationalId', 'VARCHAR(14) NULL');
    await addColumnIfNotExists(pool, 'users', 'nationalIdFront', 'VARCHAR(255) NULL');
    await addColumnIfNotExists(pool, 'users', 'nationalIdBack', 'VARCHAR(255) NULL');

    try {
      await pool.query('ALTER TABLE reviews MODIFY COLUMN shipmentId INT NULL');
    } catch (_) { /* column modification may fail or already done */ }

    await addColumnIfNotExists(pool, 'reviews', 'orderId', 'INT NULL');

    await addForeignKeyIfNotExists(pool, 'reviews', 'orderId', 'orders', 'id', 'CASCADE');

    try {
      await pool.query('ALTER TABLE reviews DROP INDEX unique_review');
    } catch (_) { /* index may not exist or already dropped */ }

    // Employee role support
    try {
      await pool.query("ALTER TABLE users MODIFY COLUMN role ENUM('merchant','captain','admin','employee') NOT NULL");
    } catch (_) {}

    await addColumnIfNotExists(pool, 'users', 'permissions', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'users', 'webPushSubscription', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'users', 'points', 'INT DEFAULT 0');
    await addColumnIfNotExists(pool, 'users', 'preparationTime', "VARCHAR(50) DEFAULT '15-25 دقيقة'");
    await addColumnIfNotExists(pool, 'users', 'rating', 'DECIMAL(3,1) DEFAULT 5.0');
    await addColumnIfNotExists(pool, 'users', 'ratingCount', 'INT DEFAULT 1');

    await addColumnIfNotExists(pool, 'merchant_products', 'preparationTime', "VARCHAR(50) DEFAULT '15-25 دقيقة'");
    await addColumnIfNotExists(pool, 'merchant_products', 'rating', 'DECIMAL(3,1) DEFAULT 0.0');
    await addColumnIfNotExists(pool, 'merchant_products', 'ratingCount', 'INT DEFAULT 0');

    await addColumnIfNotExists(pool, 'reviews', 'productId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'reviews', 'productId', 'merchant_products', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'refresh_tokens', 'deviceId', 'VARCHAR(255) NULL');

    // App settings table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS app_settings (
        \`key\` VARCHAR(100) PRIMARY KEY,
        \`value\` TEXT NULL,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Auto assignment attempts table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS auto_assignment_attempts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        shipmentId INT NULL,
        orderId INT NULL,
        captainId INT NOT NULL,
        status VARCHAR(50) NOT NULL,
        assignedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolvedAt TIMESTAMP NULL,
        reason TEXT NULL,
        FOREIGN KEY (captainId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE CASCADE,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Custom migrations for Shipment & Order workflow
    await addColumnIfNotExists(pool, 'shipments', 'autoAssignmentFailed', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'orders', 'autoAssignmentFailed', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'shipments', 'platformShare', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'shipments', 'captainShare', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'shipments', 'pickupConfirmedAt', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'shipments', 'pickupLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'pickupLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'deliveryConfirmedAt', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'shipments', 'deliveryLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'deliveryLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'shipments', 'captainApprovalStatus', 'VARCHAR(20) DEFAULT NULL');
    await addColumnIfNotExists(pool, 'shipments', 'isPaid', 'TINYINT(1) DEFAULT 0');

    await addColumnIfNotExists(pool, 'orders', 'platformShare', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'captainShare', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'pickupConfirmedAt', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'orders', 'pickupLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'orders', 'pickupLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'orders', 'deliveryConfirmedAt', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'orders', 'deliveryLatitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'orders', 'deliveryLongitude', 'DOUBLE NULL');
    await addColumnIfNotExists(pool, 'orders', 'captainApprovalStatus', 'VARCHAR(20) DEFAULT NULL');
    await addColumnIfNotExists(pool, 'orders', 'isPaid', 'TINYINT(1) DEFAULT 0');

    await addColumnIfNotExists(pool, 'trips', 'fromCity', 'VARCHAR(100) NULL');
    await addColumnIfNotExists(pool, 'trips', 'toCity', 'VARCHAR(100) NULL');
    await addColumnIfNotExists(pool, 'trips', 'passingCities', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'trips', 'departureTime', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'trips', 'arrivalTime', 'VARCHAR(50) NULL');

    try {
      await pool.query('CREATE INDEX idx_trips_createdat ON trips (createdAt)');
    } catch (_) {}
    try {
      await pool.query('CREATE INDEX idx_trips_date ON trips (date)');
    } catch (_) {}
    try {
      await pool.query('CREATE INDEX idx_trips_status ON trips (status)');
    } catch (_) {}

    await addColumnIfNotExists(pool, 'messages', 'orderId', 'INT NULL');
    await addColumnIfNotExists(pool, 'messages', 'messageType', "VARCHAR(20) DEFAULT 'text'");
    await addColumnIfNotExists(pool, 'messages', 'offerPrice', 'DECIMAL(10,2) NULL');
    await addColumnIfNotExists(pool, 'messages', 'offerStatus', 'VARCHAR(20) DEFAULT NULL');
    await addColumnIfNotExists(pool, 'messages', 'note', 'TEXT NULL');

    await addForeignKeyIfNotExists(pool, 'messages', 'orderId', 'orders', 'id', 'CASCADE');

    try {
      await pool.query('ALTER TABLE messages MODIFY COLUMN shipmentId INT NULL');
    } catch (_) {}

    try {
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('fee_collection_mode', 'after_agreement')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('merchant_video_url', '')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('captain_video_url', '')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('mobile_update_version', '1.0.0')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('mobile_update_required', '0')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('auto_assignment_timeout', '300')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('enable_auto_assignment', '1')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('max_reassignment_attempts', '5')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('allow_auto_assignment_after_reject', '1')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('allow_auto_assignment_after_timeout', '1')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('route_matching_rule', 'flexible')");
    } catch (_) {}

    // Kashier wallet integration — add reference column for session tracking
    await addColumnIfNotExists(pool, 'wallet_transactions', 'reference', 'VARCHAR(100) NULL');
    try {
      await pool.query('ALTER TABLE wallet_transactions MODIFY COLUMN status VARCHAR(50) DEFAULT \'success\'');
    } catch (_) { /* column may already exist */ }

    // Withdrawal details migration
    await addColumnIfNotExists(pool, 'wallet_transactions', 'paymentMethod', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'wallet_transactions', 'accountDetails', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'wallet_transactions', 'category', "VARCHAR(50) DEFAULT 'general'");

    // Contact messages source migration
    await addColumnIfNotExists(pool, 'contact_messages', 'source', "ENUM('app', 'website') DEFAULT 'app'");

    // Direct payments table (for pay-now via mobile payment providers)
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS direct_payments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        paymentRef VARCHAR(50) UNIQUE NOT NULL,
        merchantId INT NOT NULL,
        orderId INT NULL,
        shipmentId INT NULL,
        amount DECIMAL(10,2) NOT NULL,
        paymentMethod VARCHAR(50) NOT NULL,
        fromPhone VARCHAR(20) NOT NULL,
        fromName VARCHAR(100) NOT NULL,
        receiptImage VARCHAR(255) NOT NULL,
        status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
        adminNote TEXT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE SET NULL,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE SET NULL
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Payment methods settings migration
    try {
      await pool.query(
        "INSERT INTO app_settings (`key`, `value`) VALUES ('payment_methods', '[{\"name\":\"فودافون كاش\",\"icon\":\"vodafone\",\"phone\":\"01033190080\"},{\"name\":\"انستا باي\",\"icon\":\"instapay\",\"phone\":\"01033190080\"}]') ON DUPLICATE KEY UPDATE `key` = `key`"
      );
    } catch (_) {}

    // Coupon management tables and columns
    await addColumnIfNotExists(pool, 'shipments', 'couponCode', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'shipments', 'discountApplied', 'DECIMAL(10,2) NOT NULL DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'shipments', 'serviceFee', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'shipments', 'tip', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'couponCode', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'orders', 'discountApplied', 'DECIMAL(10,2) NOT NULL DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'serviceFee', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'tip', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'direct_payments', 'clientId', 'INT NULL');

    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS coupons (
        id INT AUTO_INCREMENT PRIMARY KEY,
        code VARCHAR(50) NOT NULL UNIQUE,
        discountType ENUM('fixed', 'full') NOT NULL DEFAULT 'fixed',
        discountValue DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        expirationType ENUM('date', 'day_of_week', 'never') NOT NULL DEFAULT 'never',
        expiryDate DATETIME NULL,
        expiryDayOfWeek INT NULL,
        maxUsages INT NOT NULL DEFAULT 1,
        usedCount INT NOT NULL DEFAULT 0,
        targetUserRole ENUM('all', 'specific') NOT NULL DEFAULT 'all',
        status TINYINT(1) NOT NULL DEFAULT 1,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB`);
    } catch (_) {}

    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS coupon_users (
        couponId INT NOT NULL,
        userId INT NOT NULL,
        PRIMARY KEY (couponId, userId),
        FOREIGN KEY (couponId) REFERENCES coupons(id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB`);
    } catch (_) {}

    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS coupon_usages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        couponId INT NOT NULL,
        userId INT NOT NULL,
        shipmentId INT NULL,
        orderId INT NULL,
        discountApplied DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        usedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (couponId) REFERENCES coupons(id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (shipmentId) REFERENCES shipments(id) ON DELETE SET NULL,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE SET NULL
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Merchant profile extensions
    await addColumnIfNotExists(pool, 'users', 'storeDescription', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'users', 'storeAddress', 'VARCHAR(255) NULL');
    await addColumnIfNotExists(pool, 'users', 'openingHours', 'VARCHAR(100) NULL');
    await addColumnIfNotExists(pool, 'users', 'minOrderAmount', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'users', 'deliveryFee', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'users', 'isOpen', 'TINYINT(1) DEFAULT 1');

    // Merchant Categories Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS merchant_categories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        merchantId INT NOT NULL,
        name VARCHAR(100) NOT NULL,
        image VARCHAR(255) NULL,
        icon VARCHAR(100) NULL,
        sortOrder INT DEFAULT 0,
        isActive TINYINT(1) DEFAULT 1,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Merchant Products Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS merchant_products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        merchantId INT NOT NULL,
        categoryId INT NULL,
        name VARCHAR(150) NOT NULL,
        description TEXT NULL,
        price DECIMAL(10,2) NOT NULL,
        discountPrice DECIMAL(10,2) NULL,
        image VARCHAR(255) NULL,
        images JSON NULL,
        isAvailable TINYINT(1) DEFAULT 1,
        sizes JSON NULL,
        addons JSON NULL,
        notes TEXT NULL,
        sortOrder INT DEFAULT 0,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES merchant_categories(id) ON DELETE SET NULL
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Order Items Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS order_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        orderId INT NOT NULL,
        productId INT NULL,
        productName VARCHAR(150) NOT NULL,
        productImage VARCHAR(255) NULL,
        size VARCHAR(50) NULL,
        addons JSON NULL,
        quantity INT DEFAULT 1,
        unitPrice DECIMAL(10,2) NOT NULL,
        totalPrice DECIMAL(10,2) NOT NULL,
        notes TEXT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES merchant_products(id) ON DELETE SET NULL
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // User Favorite Products Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS user_favorite_products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        productId INT NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_user_product (userId, productId),
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES merchant_products(id) ON DELETE CASCADE
      ) ENGINE=InnoDB`);
    } catch (_) {}

    // Delivery Zone Prices Table (From Excel matrix)
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS delivery_zone_prices (
        id INT AUTO_INCREMENT PRIMARY KEY,
        fromZone VARCHAR(100) NOT NULL,
        toZone VARCHAR(100) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_zone_route (fromZone, toZone)
      ) ENGINE=InnoDB`);

      const { PRICING_MATRIX } = require('../utils/zoneDeliveryPricing');
      const insertValues = [];
      for (const [key, price] of Object.entries(PRICING_MATRIX)) {
        const [fromZone, toZone] = key.split('|');
        if (fromZone && toZone) {
          insertValues.push([fromZone, toZone, price]);
        }
      }
      if (insertValues.length > 0) {
        await pool.query(
          `INSERT IGNORE INTO delivery_zone_prices (fromZone, toZone, price) VALUES ?`,
          [insertValues]
        );
      }
    } catch (_) {}

    // Stores Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS stores (
        id INT AUTO_INCREMENT PRIMARY KEY,
        merchantId INT NOT NULL,
        name VARCHAR(150) NOT NULL,
        activityType VARCHAR(100) DEFAULT 'restaurant',
        description TEXT NULL,
        logo VARCHAR(255) NULL,
        coverImage VARCHAR(255) NULL,
        phone VARCHAR(20) NULL,
        address VARCHAR(255) NULL,
        city VARCHAR(100) NULL,
        zone VARCHAR(100) NULL,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        deliveryZones JSON NULL,
        minOrderAmount DECIMAL(10,2) DEFAULT 0.00,
        commissionRate DECIMAL(5,2) DEFAULT 5.00,
        commissionType ENUM('percentage', 'fixed') DEFAULT 'percentage',
        settlementMethod VARCHAR(50) DEFAULT 'bank_transfer',
        isOpen TINYINT(1) DEFAULT 1,
        openingHours JSON NULL,
        preparationTime VARCHAR(50) DEFAULT '15-25 دقيقة',
        status ENUM('active', 'inactive') DEFAULT 'active',
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_store_merchant (merchantId),
        INDEX idx_store_status (status),
        INDEX idx_store_zone (zone),
        INDEX idx_store_activity (activityType)
      ) ENGINE=InnoDB;`);
    } catch (_) {}

    // Merchant Settlements Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS merchant_settlements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        settlementNumber VARCHAR(50) UNIQUE NOT NULL,
        merchantId INT NOT NULL,
        storeId INT NULL,
        periodStart DATETIME NOT NULL,
        periodEnd DATETIME NOT NULL,
        grossSales DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        onlinePaid DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        codAmount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        platformCommission DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        refunds DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        adjustments DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        merchantNet DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        settledAmount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        settlementMethod VARCHAR(50) NOT NULL DEFAULT 'cash',
        status ENUM('completed', 'pending', 'cancelled') DEFAULT 'completed',
        notes TEXT NULL,
        createdBy INT NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (merchantId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (storeId) REFERENCES stores(id) ON DELETE SET NULL,
        FOREIGN KEY (createdBy) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_settlement_merchant (merchantId),
        INDEX idx_settlement_store (storeId),
        INDEX idx_settlement_dates (periodStart, periodEnd)
      ) ENGINE=InnoDB;`);
    } catch (_) {}

    // Captain Settlements Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS captain_settlements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        settlementNumber VARCHAR(50) UNIQUE NOT NULL,
        captainId INT NOT NULL,
        periodStart DATETIME NOT NULL,
        periodEnd DATETIME NOT NULL,
        totalOrders INT DEFAULT 0,
        totalShipments INT DEFAULT 0,
        grossDeliveryFees DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        platformCommission DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        captainEarnings DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        cashCollected DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        onlineCollected DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        platformDues DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        captainDues DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        netBalance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        settledAmount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        settlementType ENUM('collection_from_captain', 'payout_to_captain', 'zero_balance') DEFAULT 'collection_from_captain',
        settlementScope ENUM('total', 'daily') DEFAULT 'total',
        settlementDate DATE NULL,
        paymentMethod VARCHAR(50) DEFAULT 'cash',
        status ENUM('completed', 'pending', 'cancelled') DEFAULT 'completed',
        notes TEXT NULL,
        createdBy INT NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (captainId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (createdBy) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_settlement_captain (captainId),
        INDEX idx_settlement_date (settlementDate)
      ) ENGINE=InnoDB;`);
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE orders ADD COLUMN isCaptainSettled TINYINT(1) DEFAULT 0');
    } catch (_) {}
    try {
      await pool.query('ALTER TABLE orders ADD COLUMN captainSettlementId INT NULL');
    } catch (_) {}
    try {
      await pool.query('ALTER TABLE shipments ADD COLUMN isCaptainSettled TINYINT(1) DEFAULT 0');
    } catch (_) {}
    try {
      await pool.query('ALTER TABLE shipments ADD COLUMN captainSettlementId INT NULL');
    } catch (_) {}

    // Audit Logs Table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS audit_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        actorId INT NOT NULL,
        actorRole VARCHAR(50) NOT NULL,
        action VARCHAR(100) NOT NULL,
        entityType VARCHAR(50) NOT NULL,
        entityId INT NULL,
        oldValue JSON NULL,
        newValue JSON NULL,
        ipAddress VARCHAR(45) NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_audit_actor (actorId),
        INDEX idx_audit_entity (entityType, entityId),
        FOREIGN KEY (actorId) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;`);
    } catch (_) {}

    // Main Activity Categories Table (الأقسام الرئيسية لأنشطة المتاجر)
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS main_activity_categories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        keyName VARCHAR(100) UNIQUE NOT NULL,
        name VARCHAR(150) NOT NULL,
        tag VARCHAR(150) NULL,
        icon VARCHAR(100) NULL,
        image VARCHAR(255) NULL,
        sortOrder INT DEFAULT 0,
        isActive TINYINT(1) DEFAULT 1,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_main_cat_active (isActive),
        INDEX idx_main_cat_key (keyName)
      ) ENGINE=InnoDB;`);

      const [existingCats] = await pool.query('SELECT COUNT(*) as cnt FROM main_activity_categories');
      if (existingCats[0].cnt === 0) {
        const defaultCats = [
          ['all', 'الكل', 'الكل', 'apps_rounded', 1],
          ['restaurant', 'مطاعم', 'مطاعم', 'restaurant_rounded', 2],
          ['supermarket', 'ماركت / سوبر ماركت', 'ماركت', 'shopping_cart_rounded', 3],
          ['bakery', 'مخبوزات', 'مخبوزات', 'bakery_dining_rounded', 4],
          ['roastery', 'محمصة و عطارة', 'محمصة و عطارة', 'grain_rounded', 5],
          ['sweets', 'حلويات', 'حلويات', 'cake_rounded', 6],
          ['vegetables', 'فواكه وخضروات', 'فواكه وخضروات', 'eco_rounded', 7],
          ['dairy', 'ألبان وجبن', 'ألبان وجبن', 'egg_rounded', 8],
          ['juices', 'عصائر وكوكتيلات', 'عصائر وكوكتيلات', 'local_drink_rounded', 9],
          ['coffee', 'قهوة وبُن', 'قهوة وبُن', 'local_cafe_rounded', 10],
          ['online', 'أونلاين', 'أونلاين', 'shopping_bag_rounded', 11],
          ['pharmacy', 'صيدلية', 'صيدلية', 'local_pharmacy_rounded', 12],
          ['clothes', 'ملابس وأزياء', 'ملابس', 'checkroom_rounded', 13],
          ['store', 'محل / متجر عام', 'محل ومتاجر', 'storefront_rounded', 14],
        ];

        for (const [keyName, name, tag, icon, order] of defaultCats) {
          await pool.query(
            'INSERT IGNORE INTO main_activity_categories (keyName, name, tag, icon, sortOrder) VALUES (?, ?, ?, ?, ?)',
            [keyName, name, tag, icon, order]
          );
        }
      }
    } catch (_) {}

    // Migrations for orders, products, categories
    await addColumnIfNotExists(pool, 'orders', 'storeId', 'INT NULL');
    await addColumnIfNotExists(pool, 'orders', 'paymentMethod', "VARCHAR(50) DEFAULT 'cash'");
    await addColumnIfNotExists(pool, 'orders', 'paymentStatus', "ENUM('pending', 'paid', 'refunded') DEFAULT 'pending'");
    await addColumnIfNotExists(pool, 'orders', 'platformCommission', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'merchantNet', 'DECIMAL(10,2) DEFAULT 0.00');
    await addColumnIfNotExists(pool, 'orders', 'isSettled', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'orders', 'settlementId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'orders', 'storeId', 'stores', 'id', 'SET NULL');
    await addForeignKeyIfNotExists(pool, 'orders', 'settlementId', 'merchant_settlements', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'merchant_products', 'storeId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'merchant_products', 'storeId', 'stores', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'merchant_categories', 'storeId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'merchant_categories', 'storeId', 'stores', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'coupons', 'storeId', 'INT NULL');
    await addForeignKeyIfNotExists(pool, 'coupons', 'storeId', 'stores', 'id', 'SET NULL');

    await addColumnIfNotExists(pool, 'stores', 'deletedAt', 'TIMESTAMP NULL');
    await addColumnIfNotExists(pool, 'orders', 'commissionRateSnapshot', 'DECIMAL(5,2) NULL');
    await addColumnIfNotExists(pool, 'orders', 'commissionTypeSnapshot', "ENUM('percentage', 'fixed') DEFAULT 'percentage'");
    await addColumnIfNotExists(pool, 'orders', 'completedAt', 'DATETIME NULL');
    await addColumnIfNotExists(pool, 'orders', 'adminNotes', 'TEXT NULL');
    await addColumnIfNotExists(pool, 'merchant_settlements', 'settlementScope', "VARCHAR(30) DEFAULT 'total'");
    await addColumnIfNotExists(pool, 'merchant_settlements', 'settlementDate', "DATE NULL");

    try {
      await pool.query('CREATE INDEX idx_orders_store_status ON orders (storeId, status, isSettled)');
    } catch (_) {}

    try {
      await pool.query("ALTER TABLE stores MODIFY COLUMN activityType VARCHAR(100) DEFAULT 'restaurant'");
    } catch (_) {}

    // Cleanup orphaned store_banners, merchant_categories, and merchant_products from deleted stores
    try {
      await pool.query(`
        DELETE FROM store_banners 
        WHERE (storeId IS NOT NULL AND storeId IN (SELECT id FROM stores WHERE deletedAt IS NOT NULL))
           OR (merchantId IS NOT NULL AND merchantId IN (SELECT id FROM users WHERE status IN ('banned', 'inactive') AND role = 'merchant') 
               AND (storeId IS NULL OR storeId NOT IN (SELECT id FROM stores WHERE deletedAt IS NULL AND status = 'active')))
      `);

      await pool.query(`
        DELETE FROM merchant_categories 
        WHERE (storeId IS NOT NULL AND storeId IN (SELECT id FROM stores WHERE deletedAt IS NOT NULL))
           OR (merchantId IS NOT NULL AND merchantId IN (SELECT id FROM users WHERE status IN ('banned', 'inactive') AND role = 'merchant') 
               AND (storeId IS NULL OR storeId NOT IN (SELECT id FROM stores WHERE deletedAt IS NULL AND status = 'active')))
      `);

      await pool.query(`
        DELETE FROM merchant_products 
        WHERE (storeId IS NOT NULL AND storeId IN (SELECT id FROM stores WHERE deletedAt IS NOT NULL))
           OR (merchantId IS NOT NULL AND merchantId IN (SELECT id FROM users WHERE status IN ('banned', 'inactive') AND role = 'merchant') 
               AND (storeId IS NULL OR storeId NOT IN (SELECT id FROM stores WHERE deletedAt IS NULL AND status = 'active')))
      `);
    } catch (cleanupErr) {
      console.warn('Orphaned stores cleanup notice:', cleanupErr.message);
    }

    return { success: true };
  } catch (error) {
    console.error('Database Schema Setup Error:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  setupDatabaseSchema
};

