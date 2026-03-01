/**
 * Monthly Balance Engine
 *
 * Calculates:
 * - Total income (pocket money + income transactions)
 * - Total expense
 * - Remaining balance
 * - Daily safe spending limit
 * - Budget usage percentage
 */

const { TransactionModel, BudgetModel } = require('../models');

const BalanceEngine = {

    async calculate(user_id, month, year) {
        const today = new Date();
        const daysInMonth = new Date(year, month, 0).getDate();
        const currentDay = (month === today.getMonth() + 1 && year === today.getFullYear())
            ? today.getDate()
            : daysInMonth;
        const daysRemaining = daysInMonth - currentDay;

        // Get pocket money budget
        const budget = await BudgetModel.getByMonth(user_id, month, year);
        const pocket_money = budget ? parseFloat(budget.pocket_money) : 0;

        // Get income/expense totals from transactions
        const totals = await TransactionModel.getMonthTotals(user_id, month, year);

        const total_income = pocket_money + (totals.income || 0);
        const total_expense = totals.expense || 0;
        const remaining = total_income - total_expense;
        const income_transactions = totals.income || 0;

        // Daily safe spend = what's left / days remaining (avoid division by zero)
        const daily_safe_limit = daysRemaining > 0
            ? parseFloat((remaining / daysRemaining).toFixed(2))
            : 0;

        // Budget usage %
        const budget_usage_pct = total_income > 0
            ? parseFloat(((total_expense / total_income) * 100).toFixed(1))
            : 0;

        return {
            pocket_money,
            income_transactions,
            total_income: parseFloat(total_income.toFixed(2)),
            total_expense: parseFloat(total_expense.toFixed(2)),
            remaining: parseFloat(remaining.toFixed(2)),
            daily_safe_limit,
            budget_usage_pct,
            days_passed: currentDay,
            days_remaining: daysRemaining,
            days_in_month: daysInMonth
        };
    }
};

module.exports = BalanceEngine;
