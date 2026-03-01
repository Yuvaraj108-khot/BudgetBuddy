const { TransactionModel } = require('../models');
const { parseSms } = require('../engines/smsParser');

const TransactionController = {

    /**
     * POST /api/transactions
     * Add a new transaction (from SMS detection or manual entry)
     */
    async create(req, res) {
        try {
            const {
                amount, type, merchant_or_sender, category,
                source, note, transaction_date, raw_sms
            } = req.body;

            const transaction = await TransactionModel.create({
                user_id: req.user.id,
                amount,
                type,
                merchant_or_sender,
                category,
                source: source || 'manual',
                note,
                transaction_date,
                raw_sms
            });

            res.status(201).json({
                success: true,
                message: 'Transaction saved',
                transaction
            });
        } catch (err) {
            console.error('Create transaction error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to save transaction' });
        }
    },

    /**
     * POST /api/transactions/parse-sms
     *
     * Flutter sends raw SMS text → backend parses it → returns structured data.
     * The app then shows a confirmation popup to the user before saving.
     *
     * Body: { raw_sms: "Your a/c XXXX debited by Rs.150..." }
     */
    async parseSms(req, res) {
        try {
            const { raw_sms } = req.body;

            if (!raw_sms || typeof raw_sms !== 'string') {
                return res.status(400).json({ success: false, message: 'raw_sms is required' });
            }

            const parsed = parseSms(raw_sms);

            if (!parsed.is_transaction) {
                return res.json({
                    success: false,
                    is_transaction: false,
                    reason: parsed.reason
                });
            }

            res.json({
                success: true,
                is_transaction: true,
                confidence: parsed.confidence,
                parsed: {
                    amount: parsed.amount,
                    type: parsed.type,
                    merchant_or_sender: parsed.merchant_or_sender,
                    category: parsed.category,
                    balance_after: parsed.balance_after,
                    source: 'sms',
                    raw_sms
                }
            });
        } catch (err) {
            console.error('Parse SMS error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to parse SMS' });
        }
    },

    /**
     * POST /api/transactions/from-sms
     *
     * Full auto-save flow:
     * Flutter sends raw SMS → backend parses → saves directly to DB.
     * Use this only when confidence is 'high'.
     */
    async createFromSms(req, res) {
        try {
            const { raw_sms, transaction_date } = req.body;

            if (!raw_sms) {
                return res.status(400).json({ success: false, message: 'raw_sms is required' });
            }

            const parsed = parseSms(raw_sms);

            if (!parsed.is_transaction) {
                return res.json({
                    success: false,
                    is_transaction: false,
                    reason: parsed.reason
                });
            }

            const transaction = await TransactionModel.create({
                user_id: req.user.id,
                amount: parsed.amount,
                type: parsed.type,
                merchant_or_sender: parsed.merchant_or_sender,
                category: parsed.category,
                source: 'sms',
                note: null,
                transaction_date: transaction_date || new Date(),
                raw_sms
            });

            res.status(201).json({
                success: true,
                message: 'Transaction auto-saved from SMS',
                confidence: parsed.confidence,
                transaction
            });
        } catch (err) {
            console.error('Create from SMS error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to save SMS transaction' });
        }
    },

    /**
     * GET /api/transactions?month=3&year=2026
     * List all transactions for a given month
     */
    async list(req, res) {
        try {
            const month = parseInt(req.query.month) || new Date().getMonth() + 1;
            const year = parseInt(req.query.year) || new Date().getFullYear();

            const transactions = await TransactionModel.getByMonth(req.user.id, month, year);

            res.json({
                success: true,
                count: transactions.length,
                month,
                year,
                transactions
            });
        } catch (err) {
            console.error('List transactions error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to fetch transactions' });
        }
    },

    /**
     * DELETE /api/transactions/:id
     * Delete a transaction
     */
    async remove(req, res) {
        try {
            const deleted = await TransactionModel.delete(req.params.id, req.user.id);
            if (!deleted) {
                return res.status(404).json({ success: false, message: 'Transaction not found' });
            }
            res.json({ success: true, message: 'Transaction deleted', transaction: deleted });
        } catch (err) {
            console.error('Delete transaction error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to delete transaction' });
        }
    }
};

module.exports = TransactionController;
