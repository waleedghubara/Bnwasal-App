const express = require('express');
const router = express.Router();
const { authenticateToken, authorizeRoles } = require('../middlewares/authMiddleware');
const { getEmployees, getEmployee, createEmployee, updateEmployee, deleteEmployee } = require('../controllers/adminController');

router.use(authenticateToken, authorizeRoles('admin'));

router.get('/', getEmployees);
router.get('/:id', getEmployee);
router.post('/', createEmployee);
router.put('/:id', updateEmployee);
router.delete('/:id', deleteEmployee);

module.exports = router;
