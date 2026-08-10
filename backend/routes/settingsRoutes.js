const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const settingsController = require('../controllers/settingsController');
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');

// Multer config for update files
const updatesDir = path.join(__dirname, '..', 'uploads', 'updates');
if (!fs.existsSync(updatesDir)) {
  fs.mkdirSync(updatesDir, { recursive: true });
}
const updateStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, updatesDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `update_${Date.now()}${ext}`);
  },
});
const uploadUpdateFile = multer({
  storage: updateStorage,
  limits: { fileSize: 500 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.exe' || ext === '.msi' || ext === '.zip') {
      cb(null, true);
    } else {
      cb(new Error('.exe, .msi, .zip فقط'));
    }
  },
});

// All routes require admin
router.get('/', authenticateToken, authorizeRoles('admin'), settingsController.getSettings);
router.put('/social', authenticateToken, authorizeRoles('admin'), settingsController.updateSocialLinks);
router.post('/upload-update', authenticateToken, authorizeRoles('admin'), uploadUpdateFile.single('updateFile'), settingsController.uploadUpdate);
router.get('/download-update', authenticateToken, authorizeRoles('admin'), settingsController.downloadUpdate);
router.get('/check-update', settingsController.checkUpdate);
router.get('/config', settingsController.getConfig);
router.put('/maintenance', authenticateToken, authorizeRoles('admin'), settingsController.toggleMaintenance);
router.put('/update-key', authenticateToken, authorizeRoles('admin'), settingsController.updateSettingKey);

module.exports = router;
