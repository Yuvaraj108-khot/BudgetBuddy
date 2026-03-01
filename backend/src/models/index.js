const pool = require('../config/db');

// ─────────────────────────────────────────────
// Transaction Model
// ─────────────────────────────────────────────

const TransactionModel = {

    /**
     * Create a new transaction
     */
    async create({ user_id, amount, type, merchant_or_sender, category, source, note, transaction_date, raw_sms }) {
        const result = await pool.query(
            `INSERT INTO transactions
        (user_id, amount, type, merchant_or_sender, category, source, note, transaction_date, raw_sms)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
            [user_id, amount, type, merchant_or_sender || 'Unknown', category || 'Uncategorized',
                source, note, transaction_date || new Date(), raw_sms]
        );
        return result.rows[0];
    },

    /**
     * Get all transactions for a user in a specific month/year
     */
    async getByMonth(user_id, month, year) {
        const result = await pool.query(
            `SELECT * FROM transactions
       WHERE user_id = $1
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR FROM transaction_date) = $3
       ORDER BY transaction_date DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    /**
     * Get a single transaction by ID
     */
    async getById(id, user_id) {
        const result = await pool.query(
            `SELECT * FROM transactions WHERE id = $1 AND user_id = $2`,
            [id, user_id]
        );
        return result.rows[0] || null;
    },

    /**
     * Delete a transaction
     */
    async delete(id, user_id) {
        const result = await pool.query(
            `DELETE FROM transactions WHERE id = $1 AND user_id = $2 RETURNING *`,
            [id, user_id]
        );
        return result.rows[0] || null;
    },

    /**
     * Get grouped merchant spending for a user/month
     */
    async getMerchantSummary(user_id, month, year) {
        const result = await pool.query(
            `SELECT
          merchant_or_sender,
          SUM(amount) AS total_spent,
          COUNT(*) AS visit_count,
          ROUND(AVG(amount), 2) AS avg_per_visit
       FROM transactions
       WHERE user_id = $1
         AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR FROM transaction_date) = $3
       GROUP BY merchant_or_sender
       ORDER BY total_spent DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    /**
     * Get category spending breakdown
     */
    async getCategorySummary(user_id, month, year) {
        const result = await pool.query(
            `SELECT
          category,
          SUM(amount) AS total_spent,
          COUNT(*) AS count
       FROM transactions
       WHERE user_id = $1
         AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR FROM transaction_date) = $3
       GROUP BY category
       ORDER BY total_spent DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    /**
     * Get total income and expense for a month
     */
    async getMonthTotals(user_id, month, year) {
        const result = await pool.query(
            `SELECT
          type,
          SUM(amount) AS total
       FROM transactions
       WHERE user_id = $1
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR FROM transaction_date) = $3
       GROUP BY type`,
            [user_id, month, year]
        );

        const totals = { income: 0, expense: 0 };
        result.rows.forEach(row => {
            totals[row.type] = parseFloat(row.total);
        });
        return totals;
    },

    /**
     * Get daily spending for prediction engine
     */
    async getDailySpend(user_id, month, year) {
        const result = await pool.query(
            `SELECT
          DATE(transaction_date) AS day,
          SUM(amount) AS daily_total
       FROM transactions
       WHERE user_id = $1
         AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR FROM transaction_date) = $3
       GROUP BY DATE(transaction_date)
       ORDER BY day ASC`,
            [user_id, month, year]
        );
        return result.rows;
    }
};

// ─────────────────────────────────────────────
// Budget Settings Model
// ─────────────────────────────────────────────

const BudgetModel = {

    /**
     * Set or update monthly pocket money budget
     */
    async upsert(user_id, month, year, pocket_money) {
        const result = await pool.query(
            `INSERT INTO budget_settings (user_id, month, year, pocket_money)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, month, year)
       DO UPDATE SET pocket_money = EXCLUDED.pocket_money, updated_at = NOW()
       RETURNING *`,
            [user_id, month, year, pocket_money]
        );
        return result.rows[0];
    },

    /**
     * Get budget for a specific month
     */
    async getByMonth(user_id, month, year) {
        const result = await pool.query(
            `SELECT * FROM budget_settings
       WHERE user_id = $1 AND month = $2 AND year = $3`,
            [user_id, month, year]
        );
        return result.rows[0] || null;
    }
};

// ─────────────────────────────────────────────
// User Model
// ─────────────────────────────────────────────

const UserModel = {

    async create({ name, email, password_hash, phone }) {
        const result = await pool.query(
            `INSERT INTO users (name, email, password_hash, phone)
       VALUES ($1, $2, $3, $4) RETURNING id, name, email, phone, created_at`,
            [name, email, password_hash, phone]
        );
        return result.rows[0];
    },

    async findByEmail(email) {
        const result = await pool.query(
            `SELECT * FROM users WHERE email = $1`,
            [email]
        );
        return result.rows[0] || null;
    },

    async findById(id) {
        const result = await pool.query(
            `SELECT id, name, email, phone, created_at FROM users WHERE id = $1`,
            [id]
        );
        return result.rows[0] || null;
    }
};

module.exports = { TransactionModel, BudgetModel, UserModel };
