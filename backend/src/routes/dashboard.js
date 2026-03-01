const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const DashboardController = require('../controllers/dashboardController');
const { authMiddleware } = require('../middleware');

// All routes require auth
router.use(authMiddleware);

const budgetValidation = [
    body('month').isInt({ min: 1, max: 12 }).withMessage('Month must be 1–12'),
    body('year').isInt({ min: 2020 }).withMessage('Year must be 2020 or later'),
    body('pocket_money').isFloat({ gt: 0 }).withMessage('Pocket money must be a positive number')
];

// Routes
router.get('/', DashboardController.getDashboard);
router.post('/budget', budgetValidation, DashboardController.setBudget);
router.get('/merchants', DashboardController.getMerchants);

module.exports = router;
