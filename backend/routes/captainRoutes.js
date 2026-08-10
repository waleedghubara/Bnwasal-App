const express = require('express');
const router = express.Router();
const captainController = require('../controllers/captainController');
const { authenticateToken, authorizeRoles, authorizeByPermission } = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');

router.get('/', authenticateToken, authorizeByPermission('captains'), captainController.getCaptains);
router.get('/:id', authenticateToken, authorizeByPermission('captains'), captainController.getCaptainDetail);
router.delete('/:id', authenticateToken, authorizeRoles('admin'), captainController.deleteCaptain);
router.patch('/:id/status', authenticateToken, authorizeRoles('admin'), captainController.updateCaptainStatus);
router.post('/:id/warning', authenticateToken, authorizeRoles('admin'), captainController.sendWarning);

router.post(
  '/:id/documents',
  authenticateToken,
  authorizeByPermission('captains'),
  upload.fields([
    { name: 'profileImage', maxCount: 1 },
    { name: 'nationalIdFront', maxCount: 1 },
    { name: 'nationalIdBack', maxCount: 1 }
  ]),
  captainController.uploadCaptainDocuments
);

module.exports = router;
