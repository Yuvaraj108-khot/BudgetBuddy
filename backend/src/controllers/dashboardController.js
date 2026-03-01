const { BudgetModel, TransactionModel } = require('../models');
const BalanceEngine = require('../engines/balanceEngine');
const PredictionEngine = require('../engines/predictionEngine');
const DisciplineEngine = require('../engines/disciplineEngine');
const InsightEngine = require('../engines/insightEngine');

const DashboardController = {

    /**
     * GET /api/dashboard?month=3&year=2026
     *
     * Returns complete dashboard data:
     * - Balance summary
     * - Monthly transactions
     * - Merchant breakdown
     * - Category breakdown
     * - Prediction data
     * - Discipline score
     * - Smart insights
     */
    async getDashboard(req, res) {
        try {
            const month = parseInt(req.query.month) || new Date().getMonth() + 1;
            const year = parseInt(req.query.year) || new Date().getFullYear();
            const user_id = req.user.id;

            // Run all calculations in parallel for speed
            const [
                balanceData,
                merchantData,
                categoryData,
                transactions
            ] = await Promise.all([
                BalanceEngine.calculate(user_id, month, year),
                TransactionModel.getMerchantSummary(user_id, month, year),
                TransactionModel.getCategorySummary(user_id, month, year),
                TransactionModel.getByMonth(user_id, month, year)
            ]);

            // These depend on balanceData
            const predictionData = await PredictionEngine.predict(user_id, month, year, balanceData.total_income);
            const disciplineData = await DisciplineEngine.score(user_id, month, year, balanceData, predictionData);
            const insightData = await InsightEngine.generate(user_id, month, year, balanceData, predictionData, disciplineData);

            // Add merchant percentage to each row
            const totalExpense = balanceData.total_expense;
            const merchantSummary = merchantData.map(m => ({
                ...m,
                pct_of_budget: totalExpense > 0
                    ? parseFloat(((parseFloat(m.total_spent) / totalExpense) * 100).toFixed(1))
                    : 0
            }));

            res.json({
                success: true,
                month,
                year,
                balance: balanceData,
                prediction: predictionData,
                discipline: disciplineData,
                insights: insightData,
                merchants: merchantSummary,
                categories: categoryData,
                recent_transactions: transactions.slice(0, 10),
                total_transactions: transactions.length
            });
        } catch (err) {
            console.error('Dashboard error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to load dashboard' });
        }
    },

    /**
     * POST /api/dashboard/budget
     * Set or update pocket money budget for the month
     */
    async setBudget(req, res) {
        try {
            const { month, year, pocket_money } = req.body;
            const budget = await BudgetModel.upsert(req.user.id, month, year, pocket_money);
            res.json({
                success: true,
                message: 'Budget updated',
                budget
            });
        } catch (err) {
            console.error('Set budget error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to update budget' });
        }
    },

    /**
     * GET /api/dashboard/merchants?month=3&year=2026
     * Get full merchant breakdown
     */
    async getMerchants(req, res) {
        try {
            const month = parseInt(req.query.month) || new Date().getMonth() + 1;
            const year = parseInt(req.query.year) || new Date().getFullYear();

            const balanceData = await BalanceEngine.calculate(req.user.id, month, year);
            const merchantData = await TransactionModel.getMerchantSummary(req.user.id, month, year);

            const merchants = merchantData.map(m => ({
                ...m,
                pct_of_budget: balanceData.total_expense > 0
                    ? parseFloat(((parseFloat(m.total_spent) / balanceData.total_expense) * 100).toFixed(1))
                    : 0
            }));

            res.json({ success: true, month, year, merchants });
        } catch (err) {
            console.error('Merchant error:', err.message);
            res.status(500).json({ success: false, message: 'Failed to fetch merchant data' });
        }
    }
};

module.exports = DashboardController;
