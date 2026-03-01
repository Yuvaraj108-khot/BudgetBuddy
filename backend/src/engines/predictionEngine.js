/**
 * Spending Prediction Engine
 *
 * Calculates:
 * - Average daily spend based on days passed
 * - Predicted total spend for the month
 * - Whether user will exceed budget
 * - Projected shortfall or surplus
 */

const { TransactionModel } = require('../models');

const PredictionEngine = {

    async predict(user_id, month, year, total_income) {
        const today = new Date();
        const daysInMonth = new Date(year, month, 0).getDate();
        const daysPassed = (month === today.getMonth() + 1 && year === today.getFullYear())
            ? today.getDate()
            : daysInMonth;

        // Get all daily expenses so far
        const dailyRows = await TransactionModel.getDailySpend(user_id, month, year);
        const total_spent_so_far = dailyRows.reduce((sum, r) => sum + parseFloat(r.daily_total), 0);

        const avg_daily_spend = daysPassed > 0
            ? parseFloat((total_spent_so_far / daysPassed).toFixed(2))
            : 0;

        const predicted_total = parseFloat((avg_daily_spend * daysInMonth).toFixed(2));

        const will_exceed = predicted_total > total_income;
        const projected_gap = parseFloat((predicted_total - total_income).toFixed(2));
        const projected_surplus = will_exceed ? 0 : Math.abs(projected_gap);
        const projected_shortfall = will_exceed ? projected_gap : 0;

        const overshoot_pct = total_income > 0
            ? parseFloat(((predicted_total / total_income) * 100).toFixed(1))
            : 0;

        return {
            avg_daily_spend,
            total_spent_so_far: parseFloat(total_spent_so_far.toFixed(2)),
            predicted_total_spend: predicted_total,
            will_exceed_budget: will_exceed,
            projected_shortfall: parseFloat(projected_shortfall.toFixed(2)),
            projected_surplus: parseFloat(projected_surplus.toFixed(2)),
            overshoot_pct,
            days_used_for_prediction: daysPassed
        };
    }
};

module.exports = PredictionEngine;
