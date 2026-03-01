/**
 * Smart Rule-Based Insight Engine
 *
 * Generates human-readable insights WITHOUT any paid AI.
 * Pure deterministic rule engine that outputs:
 * - Up to 3 behavioral insights
 * - 1 warning (if applicable)
 * - 1 improvement suggestion
 */

const { TransactionModel } = require('../models');

const InsightEngine = {

    async generate(user_id, month, year, balanceData, predictionData, disciplineData) {
        const insights = [];
        let warning = null;
        let suggestion = null;

        const totalExpense = balanceData.total_expense || 0;
        const totalIncome = balanceData.total_income || 0;
        const avgDaily = predictionData.avg_daily_spend;
        const safeDaily = balanceData.daily_safe_limit;
        const remaining = balanceData.remaining;

        // --- Fetch merchants and categories ---
        const merchantRows = await TransactionModel.getMerchantSummary(user_id, month, year);
        const categoryRows = await TransactionModel.getCategorySummary(user_id, month, year);

        // ── INSIGHTS ────────────────────────────────────────

        // 1. Top merchant insight
        if (merchantRows.length > 0) {
            const top = merchantRows[0];
            const share = totalExpense > 0
                ? ((parseFloat(top.total_spent) / totalExpense) * 100).toFixed(0)
                : 0;
            insights.push(
                `You spend the most at "${top.merchant_or_sender}" — ₹${top.total_spent} across ${top.visit_count} visit(s), which is ${share}% of your total spending.`
            );
        }

        // 2. Top category insight
        if (categoryRows.length > 0) {
            const top = categoryRows[0];
            const share = totalExpense > 0
                ? ((parseFloat(top.total_spent) / totalExpense) * 100).toFixed(0)
                : 0;
            insights.push(
                `Your biggest expense category is "${top.category}" at ₹${top.total_spent} (${share}% of spending).`
            );
        }

        // 3. Daily pace insight
        if (avgDaily > 0) {
            if (avgDaily > safeDaily && safeDaily > 0) {
                insights.push(
                    `You're spending ₹${avgDaily}/day but your safe daily limit is ₹${safeDaily}/day. You need to slow down.`
                );
            } else {
                insights.push(
                    `Your current daily spending of ₹${avgDaily} is within your safe limit of ₹${safeDaily}/day. Keep it up!`
                );
            }
        }

        // ── WARNING ─────────────────────────────────────────

        if (predictionData.will_exceed_budget) {
            warning = `⚠️ At your current pace, you'll overspend by ₹${predictionData.projected_shortfall} by end of month. Your predicted spend is ₹${predictionData.predicted_total_spend} but your budget is ₹${totalIncome}.`;
        } else if (remaining < 200) {
            warning = `⚠️ You have only ₹${remaining} left for the rest of the month. Be very careful with spending!`;
        }

        // ── SUGGESTION ──────────────────────────────────────

        if (merchantRows.length > 0) {
            const topM = merchantRows[0];
            const visits = parseInt(topM.visit_count);
            const avgV = parseFloat(topM.avg_per_visit);

            if (visits >= 5) {
                const savedAmount = (Math.ceil(visits * 0.3) * avgV).toFixed(0);
                suggestion = `💡 Reducing your visits to "${topM.merchant_or_sender}" by 30% (about ${Math.ceil(visits * 0.3)} fewer visits) could save you ₹${savedAmount} this month.`;
            } else if (predictionData.will_exceed_budget) {
                const cutPerDay = ((predictionData.projected_shortfall) / balanceData.days_remaining).toFixed(0);
                suggestion = `💡 You need to cut ₹${cutPerDay}/day to avoid going over budget this month.`;
            } else {
                const savingPct = totalIncome > 0
                    ? ((remaining / totalIncome) * 100).toFixed(0)
                    : 0;
                suggestion = `💡 You're on track to save ${savingPct}% of your income this month. Try to maintain this pace!`;
            }
        } else {
            suggestion = `💡 Start tracking your expenses regularly so we can give you personalized insights!`;
        }

        return { insights, warning, suggestion };
    }
};

module.exports = InsightEngine;
