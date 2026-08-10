const startTime = performance.now();
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const path = require('path');
const os = require('os');
const webpush = require('web-push');
const { initializeDatabase, getPool } = require('./config/db');
const { assertSecurityConfig, isProduction } = require('./utils/securityConfig');
const { escapeHtml } = require('./utils/htmlEscape');
const { registerSocketHandlers } = require('./socket/socketHandler');
const { uploadsAuthMiddleware } = require('./middlewares/uploadAuth');
const { verifyRequestSignature } = require('./middlewares/signatureMiddleware');

assertSecurityConfig();

if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
  if (isProduction()) {
    throw new Error('VAPID keys must be configured in production');
  }
  const vapidKeys = webpush.generateVAPIDKeys();
  process.env.VAPID_PUBLIC_KEY = vapidKeys.publicKey;
  process.env.VAPID_PRIVATE_KEY = vapidKeys.privateKey;
  console.log('🔑 Generated dev VAPID keys (set env vars to persist)');
}
webpush.setVapidDetails(
  'mailto:contact@bnwasal.com',
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const corsOptions = {
  origin: allowedOrigins.length > 0 ? allowedOrigins : !isProduction(),
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
};

const app = express();
const PORT = process.env.PORT || 5000;

const http = require('http');
const server = http.createServer(app);
const io = require('socket.io')(server, {
  cors: {
    ...corsOptions,
    methods: ['GET', 'POST'],
  },
});

const activeUsers = new Map(); // userId → Set<socketId>
app.set('io', io);
app.set('activeUsers', activeUsers);
global.io = io; // make accessible from controllers without req
global.activeUsers = activeUsers;


const { refreshSocketUser } = require('./utils/socketUser');

registerSocketHandlers(io, activeUsers, refreshSocketUser);

// Global Middlewares
if (isProduction()) {
  app.set('trust proxy', 1);
  app.use((req, res, next) => {
    if (req.secure || req.headers['x-forwarded-proto'] === 'https') {
      next();
    } else {
      res.redirect(301, `https://${req.headers.host}${req.url}`);
    }
  });
}

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors(corsOptions));
app.use(
  express.json({
    limit: '2mb',
    verify: (req, res, buf) => {
      req.rawBody = buf.toString('utf8');
    },
  })
);
app.use(express.urlencoded({ extended: true, limit: '2mb' }));
app.use(morgan(isProduction() ? 'combined' : 'dev'));
app.use(verifyRequestSignature);

app.use('/uploads', uploadsAuthMiddleware, express.static(path.join(__dirname, 'uploads')));

// Health check / Root Route
app.get('/', (req, res) => {
  res.status(200).json({
    status: 1,
    message: 'Welcome to We Deliver API server is running successfully.',
    data: {
      uptime: process.uptime(),
      timestamp: Date.now()
    }
  });
});

// ── Public stats route (landing page) ──────────────────────────────────────
const publicStatsRoutes = require('./routes/publicStatsRoutes');
app.use('/api/public', publicStatsRoutes);

app.get('/invite/:code', async (req, res) => {
  const code = req.params.code;
  let referrerName = '';
  try {
    const { getPool } = require('./config/db');
    const pool = getPool();
    const [rows] = await pool.query('SELECT firstName, lastName, storeName FROM users WHERE referralCode = ?', [code]);
    if (rows.length > 0) {
      referrerName = rows[0].storeName || `${rows[0].firstName} ${rows[0].lastName}`;
    }
  } catch (err) {
    console.error('Error fetching referrer in invite link:', err);
  }

  const safeReferrer = escapeHtml(referrerName);
  const referrerBadge = safeReferrer
    ? `<div class="referrer-alert"><i class="fa-solid fa-user-check"></i><span>دعوة خاصة من <strong>${safeReferrer}</strong></span></div>`
    : `<div class="referrer-alert"><i class="fa-solid fa-gift"></i><span>مرحباً بك في منصة بنوصل</span></div>`;

  try {
    const fs = require('fs').promises;
    const templatePath = path.join(__dirname, 'views', 'invite.html');
    let html = await fs.readFile(templatePath, 'utf8');
    html = html.replace(/{{referrerBadge}}/g, referrerBadge)
      .replace(/{{code}}/g, code);
    res.send(html);
  } catch (templateErr) {
    console.error('Error reading invite template:', templateErr);
    res.status(500).send('Error loading template');
  }
});

const authRoutes = require('./routes/authRoutes');
const shipmentRoutes = require('./routes/shipmentRoutes');
const addressRoutes = require('./routes/addressRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const orderRoutes = require('./routes/orderRoutes');
const tripRoutes = require('./routes/tripRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const referralRoutes = require('./routes/referralRoutes');
const supportRoutes = require('./routes/supportRoutes');
const negotiationRoutes = require('./routes/negotiationRoutes');
const dispatcherRoutes = require('./routes/dispatcherRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const directPaymentRoutes = require('./routes/directPaymentRoutes');

// Auth Routes
app.use('/api/auth', authRoutes);

// Shipment Routes
app.use('/api/shipments', shipmentRoutes);

// Address Routes
app.use('/api/addresses', addressRoutes);

// Review Routes
app.use('/api/reviews', reviewRoutes);

// Order Routes
app.use('/api/orders', orderRoutes);

// Trip Routes
app.use('/api/trips', tripRoutes);

// Notification Routes
app.use('/api/notifications', notificationRoutes);

// Referral Routes
app.use('/api/referrals', referralRoutes);

// Support Routes
app.use('/api/support', supportRoutes);

// Negotiation Routes
app.use('/api/negotiation', negotiationRoutes);

// Dispatcher Routes
app.use('/api/dispatcher', dispatcherRoutes);

// Payment Routes
app.use('/api/payments', paymentRoutes);

// Direct Payment Routes (pay-now with receipt upload)
app.use('/api/direct-payments', directPaymentRoutes);

// Wallet Routes (with Kashier integration)
const walletRoutes = require('./routes/walletRoutes');
app.use('/api/wallet', walletRoutes);

// Coupon Routes
const couponRoutes = require('./routes/couponRoutes');
app.use('/api/coupons', couponRoutes);

// Settings Routes (admin only)
const settingsRoutes = require('./routes/settingsRoutes');
app.use('/api/settings', settingsRoutes);

// Merchant Routes (admin only)
const merchantRoutes = require('./routes/merchantRoutes');
app.use('/api/admin/merchants', merchantRoutes);

// Admin Withdrawals Routes (admin & employee only)
const adminWithdrawalRoutes = require('./routes/adminWithdrawalRoutes');
app.use('/api/admin/withdrawals', adminWithdrawalRoutes);

// Admin Wallet Routes (admin & employee only)
const adminWalletRoutes = require('./routes/adminWalletRoutes');
app.use('/api/admin/wallet', adminWalletRoutes);

// Captain Routes (admin only)
const captainRoutes = require('./routes/captainRoutes');
app.use('/api/admin/captains', captainRoutes);

// Trips Routes (admin)
const tripsRoutes = require('./routes/tripsRoutes');
app.use('/api/admin/trips', tripsRoutes);

// Dashboard Routes (admin only)
const dashboardRoutes = require('./routes/dashboardRoutes');
app.use('/api/admin/dashboard', dashboardRoutes);

// All Orders & Shipments Routes (admin & employee)
const allOrdersShipmentsRoutes = require('./routes/allOrdersShipmentsRoutes');
app.use('/api/admin/all-orders-shipments', allOrdersShipmentsRoutes);


// Pending Accounts Routes (admin only)
const pendingAccountsRoutes = require('./routes/pendingAccountsRoutes');
app.use('/api/admin/pending-accounts', pendingAccountsRoutes);

// Employee Routes (admin only)
const employeeRoutes = require('./routes/employeeRoutes');
app.use('/api/admin/employees', employeeRoutes);

// 404 Route handler
app.use((req, res, next) => {
  res.status(404).json({
    status: 0,
    message: `API Route not found: ${req.originalUrl}`
  });
});

// Global Error Handler Middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      status: 0,
      message: 'حجم الملف كبير جدًا. الحد الأقصى هو 10 ميجابايت'
    });
  }
  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    return res.status(400).json({
      status: 0,
      message: 'حقل الملف غير متوقع'
    });
  }
  const status = err.status || 500;
  res.status(status).json({
    status: 0,
    message:
      status < 500
        ? err.publicMessage || err.message
        : isProduction()
          ? 'An internal server error occurred'
          : err.message,
  });
});

// Start Server — initialize DB first, THEN open the port to traffic
(async () => {
  const dbStatus = await initializeDatabase();

  if (!dbStatus.success) {
    console.error(`\x1b[31m[FATAL] Database initialization failed: ${dbStatus.error}\x1b[0m`);
    console.error('\x1b[31m[FATAL] Server will NOT start without a database connection.\x1b[0m');
    process.exit(1);
  }

  server.listen(PORT, async () => {
    // Initialize auto assignment background worker
    try {
      const { initAutoAssignment } = require('./utils/autoAssignment');
      initAutoAssignment(app);
    } catch (err) {
      console.error('❌ Failed to initialize auto-assignment background worker:', err.message);
    }

    const duration = (performance.now() - startTime).toFixed(2);
    const timeString = new Date().toLocaleTimeString('en-US', { hour12: true });
    const dateString = new Date().toLocaleDateString('en-US');

    const platform = os.platform();
    const arch = os.arch();
    const platformName = platform === 'win32' ? 'Windows' : platform === 'darwin' ? 'macOS' : 'Linux';

    const cpus = os.cpus();
    const cpuModel = cpus && cpus.length > 0 ? cpus[0].model : 'Unknown CPU';
    const cpuDisplayName = cpuModel.length > 38 ? cpuModel.slice(0, 35) + '...' : cpuModel;

    const totalMemGB = (os.totalmem() / (1024 * 1024 * 1024)).toFixed(2);
    const freeMemGB = (os.freemem() / (1024 * 1024 * 1024)).toFixed(2);

    const networkInterfaces = os.networkInterfaces();
    const localIPs = [];
    Object.keys(networkInterfaces).forEach((interfaceName) => {
      networkInterfaces[interfaceName].forEach((iface) => {
        if (iface.family === 'IPv4' && !iface.internal) {
          localIPs.push(iface.address);
        }
      });
    });

    const printBoxLine = (content = '') => {
      const innerWidth = 56;
      const rawLength = content.replace(/\x1b\[[0-9;]*m/g, '').length;
      const padding = Math.max(0, innerWidth - rawLength);
      console.log(`\x1b[36m│\x1b[0m ${content}${' '.repeat(padding)} \x1b[36m│\x1b[0m`);
    };

    const dbErrorClean = dbStatus.error && dbStatus.error.length > 25
      ? dbStatus.error.slice(0, 22) + '...'
      : dbStatus.error || '';
    const dbLine = dbStatus.success
      ? `   • Database:  🟢 Connected (\x1b[32m${dbStatus.dbName}\x1b[0m)`
      : `   • Database:  🔴 Failed (\x1b[31m${dbErrorClean}\x1b[0m)`;

    console.log(`\n\x1b[36m┌${'─'.repeat(58)}┐\x1b[0m`);
    printBoxLine(`\x1b[1m\x1b[32m🚀 WE DELIVER SERVER IS ONLINE\x1b[0m`);
    console.log(`\x1b[36m├${'─'.repeat(58)}┤\x1b[0m`);
    printBoxLine(`\x1b[1m📍 Server URLs:\x1b[0m`);
    printBoxLine(`   • Local:   \x1b[36mhttp://localhost:${PORT}\x1b[0m`);
    localIPs.forEach(ip => {
      printBoxLine(`   • Network: \x1b[36mhttp://${ip}:${PORT}\x1b[0m`);
    });
    printBoxLine();
    printBoxLine(`\x1b[1m🖥️  System Specification:\x1b[0m`);
    printBoxLine(`   • Device/OS: \x1b[33m${platformName} (${arch} arch)\x1b[0m`);
    printBoxLine(`   • CPU Model: \x1b[90m${cpuDisplayName}\x1b[0m`);
    printBoxLine(`   • Memory:    \x1b[35m${freeMemGB} GB Free / ${totalMemGB} GB Total\x1b[0m`);
    printBoxLine();
    printBoxLine(`\x1b[1m⏱️  Startup Stats & DB:\x1b[0m`);
    printBoxLine(dbLine);
    printBoxLine(`   • Time/Date: \x1b[34m${timeString} - ${dateString}\x1b[0m`);
    printBoxLine(`   • Speed:     \x1b[32m⚡ ${duration} ms (Bootstrap)\x1b[0m`);
    printBoxLine(`   • Environment: \x1b[31m${process.env.NODE_ENV || 'development'}\x1b[0m`);
    console.log(`\x1b[36m└${'─'.repeat(58)}┘\n\x1b[0m`);
  });
})();
// Server reload trigger v4




