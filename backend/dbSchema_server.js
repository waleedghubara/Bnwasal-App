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
        role ENUM('merchant', 'captain', 'admin') NOT NULL,
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
    try {
      await pool.query('ALTER TABLE shipments ADD FOREIGN KEY (assignedAdminId) REFERENCES users(id) ON DELETE SET NULL');
    } catch (_) {}
    await addColumnIfNotExists(pool, 'orders', 'assignedAdminId', 'INT NULL');
    try {
      await pool.query('ALTER TABLE orders ADD FOREIGN KEY (assignedAdminId) REFERENCES users(id) ON DELETE SET NULL');
    } catch (_) {}

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

    try {
      await pool.query('ALTER TABLE reviews ADD FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE');
    } catch (_) { /* foreign key may already exist */ }

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

    await addColumnIfNotExists(pool, 'refresh_tokens', 'deviceId', 'VARCHAR(255) NULL');

    // App settings table
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS app_settings (
        \`key\` VARCHAR(100) PRIMARY KEY,
        \`value\` TEXT NULL,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB`);

      await pool.query(
        `INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('captain_acceptance_timeout_seconds', '60')`
      );
    } catch (_) {}

    // Custom migrations for Shipment & Order workflow
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
    await addColumnIfNotExists(pool, 'shipments', 'rejectedCaptainIds', 'TEXT NULL');

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
    await addColumnIfNotExists(pool, 'orders', 'rejectedCaptainIds', 'TEXT NULL');

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

    try {
      await pool.query('ALTER TABLE messages ADD FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE');
    } catch (_) {}

    try {
      await pool.query('ALTER TABLE messages MODIFY COLUMN shipmentId INT NULL');
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

    await addColumnIfNotExists(pool, 'shipments', 'autoAssignmentFailed', 'TINYINT(1) DEFAULT 0');
    await addColumnIfNotExists(pool, 'orders', 'autoAssignmentFailed', 'TINYINT(1) DEFAULT 0');

    try {
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('fee_collection_mode', 'after_agreement')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('merchant_video_url', '')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('captain_video_url', '')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('mobile_update_version', '1.0.0')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('mobile_update_required', '0')");
      await pool.query("INSERT IGNORE INTO app_settings (\`key\`, \`value\`) VALUES ('auto_assignment_timeout', '300')");
    } catch (_) {}

    // Kashier wallet integration — add reference column for session tracking
    await addColumnIfNotExists(pool, 'wallet_transactions', 'reference', 'VARCHAR(100) NULL');
    try {
      await pool.query('ALTER TABLE wallet_transactions MODIFY COLUMN status VARCHAR(50) DEFAULT \'success\'');
    } catch (_) { /* column may already exist */ }

    // Withdrawal details migration
    await addColumnIfNotExists(pool, 'wallet_transactions', 'paymentMethod', 'VARCHAR(50) NULL');
    await addColumnIfNotExists(pool, 'wallet_transactions', 'accountDetails', 'TEXT NULL');

    // Contact messages source migration
    await addColumnIfNotExists(pool, 'contact_messages', 'source', "ENUM('app', 'website') DEFAULT 'app'");

    return { success: true };
  } catch (error) {
    console.error('Database Schema Setup Error:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  setupDatabaseSchema
};
