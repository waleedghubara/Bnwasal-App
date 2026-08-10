const express = require('express');
const router = express.Router();
const merchantController = require('../controllers/merchantController');
const { authenticateToken, authorizeRoles, authorizeByPermission } = require('../middlewares/authMiddleware');

router.get('/', authenticateToken, authorizeByPermission('merchants'), merchantController.getMerchants);
router.get('/:id', authenticateToken, authorizeByPermission('merchants'), merchantController.getMerchantDetail);
router.delete('/:id', authenticateToken, authorizeRoles('admin'), merchantController.deleteMerchant);
router.patch('/:id/status', authenticateToken, authorizeRoles('admin'), merchantController.updateMerchantStatus);
router.post('/:id/warning', authenticateToken, authorizeRoles('admin'), merchantController.sendWarning);

module.exports = router;
