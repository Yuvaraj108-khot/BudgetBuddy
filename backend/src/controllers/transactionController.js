const { TransactionModel } = require('../models');

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
