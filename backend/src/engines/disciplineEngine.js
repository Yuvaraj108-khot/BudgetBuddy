/**
 * Discipline Score Engine (0–100)
 *
 * Scores the student's financial discipline based on:
 * - Budget overrun risk          (-20)
 * - Merchant concentration       (-10 if one merchant > 50% of spend)
 * - Category concentration       (-10 if one category > 50% of spend)
 * - Savings ratio                (+10 if savings > 20%)
 * - Low spending days bonus      (+5  if avg daily spend < daily limit)
 *
 * Base score starts at 80.
 */

const { TransactionModel } = require('../models');

const DisciplineEngine = {

    async score(user_id, month, year, balanceData, predictionData) {
        let score = 80;
        const deductions = [];
        const bonuses = [];

        // --- Deduction: Budget overrun predicted ---
        if (predictionData.will_exceed_budget) {
            score -= 20;
            deductions.push({ reason: 'Predicted to exceed budget', points: -20 });
        }

        // --- Deduction: Merchant concentration ---
        const merchantRows = await TransactionModel.getMerchantSummary(user_id, month, year);
        const totalExpense = balanceData.total_expense || 0;

        if (merchantRows.length > 0 && totalExpense > 0) {
            const topMerchant = merchantRows[0];
            const merchantShare = (parseFloat(topMerchant.total_spent) / totalExpense) * 100;
            if (merchantShare > 50) {
                score -= 10;
                deductions.push({
                    reason: `${topMerchant.merchant_or_sender} takes ${merchantShare.toFixed(0)}% of spending`,
                    points: -10
                });
            }
        }

        // --- Deduction: Category concentration ---
        const categoryRows = await TransactionModel.getCategorySummary(user_id, month, year);
        if (categoryRows.length > 0 && totalExpense > 0) {
            const topCategory = categoryRows[0];
            const categoryShare = (parseFloat(topCategory.total_spent) / totalExpense) * 100;
            if (categoryShare > 50) {
                score -= 10;
                deductions.push({
                    reason: `${topCategory.category} takes ${categoryShare.toFixed(0)}% of spending`,
                    points: -10
                });
            }
        }

        // --- Bonus: Healthy savings ratio ---
        const savingsRatio = balanceData.total_income > 0
            ? (balanceData.remaining / balanceData.total_income) * 100
            : 0;

        if (savingsRatio > 20) {
            score += 10;
            bonuses.push({ reason: `Saving ${savingsRatio.toFixed(0)}% of your income`, points: 10 });
        }

        // --- Bonus: Daily spend under control ---
        if (balanceData.daily_safe_limit > 0 &&
            predictionData.avg_daily_spend < balanceData.daily_safe_limit) {
            score += 5;
            bonuses.push({ reason: 'Daily spending is within safe limit', points: 5 });
        }

        // Clamp between 0 and 100
        score = Math.min(100, Math.max(0, score));

        // Rank label
        let rank;
        if (score >= 80) rank = 'Excellent 🌟';
        else if (score >= 60) rank = 'Good 👍';
        else if (score >= 40) rank = 'Fair ⚠️';
        else rank = 'At Risk 🚨';

        return { score, rank, deductions, bonuses };
    }
};

module.exports = DisciplineEngine;
