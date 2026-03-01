const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const TransactionController = require('../controllers/transactionController');
const { authMiddleware } = require('../middleware');

// All routes require auth
router.use(authMiddleware);

const txValidation = [
    body('amount').isFloat({ gt: 0 }).withMessage('Amount must be a positive number'),
    body('type').isIn(['income', 'expense']).withMessage('Type must be income or expense'),
    body('source').optional().isIn(['sms', 'manual']).withMessage('Source must be sms or manual')
];

// Routes
router.post('/', txValidation, TransactionController.create);
router.get('/', TransactionController.list);
router.delete('/:id', TransactionController.remove);

module.exports = router;
