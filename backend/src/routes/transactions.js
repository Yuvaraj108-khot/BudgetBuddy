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

// ── SMS Routes ────────────────────────────────────────────────────────────
// Step 1: Parse raw SMS → returns structured data for confirmation popup
router.post('/parse-sms', TransactionController.parseSms);

// Step 2a: Auto-save directly from SMS (use when confidence = 'high')
router.post('/from-sms', TransactionController.createFromSms);

// ── Standard CRUD ─────────────────────────────────────────────────────────
// Step 2b: Manual/confirmed save after popup
router.post('/', txValidation, TransactionController.create);
router.get('/', TransactionController.list);
router.delete('/:id', TransactionController.remove);

module.exports = router;
