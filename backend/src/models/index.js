const pool = require('../config/db');

// ─────────────────────────────────────────────────────────
// User Model
// ─────────────────────────────────────────────────────────
const UserModel = {

    async create({ name, email, password_hash, phone }) {
        const result = await pool.query(
            `INSERT INTO users (name, email, password_hash, phone)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, email, phone, created_at`,
            [name, email, password_hash, phone]
        );
        return result.rows[0];
    },

    async findByEmail(email) {
        const result = await pool.query(
            `SELECT * FROM users WHERE email = $1`, [email]
        );
        return result.rows[0] || null;
    },

    async findById(id) {
        const result = await pool.query(
            `SELECT id, name, email, phone, pin_hash,
              failed_login_attempts, locked_until,
              failed_pin_attempts, pin_locked_until,
              created_at
       FROM users WHERE id = $1`, [id]
        );
        return result.rows[0] || null;
    },

    // ── Login security ────────────────────────────────────
    async incrementFailedLogin(id) {
        await pool.query(
            `UPDATE users SET
         failed_login_attempts = failed_login_attempts + 1,
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    async lockAccount(id, minutes = 30) {
        await pool.query(
            `UPDATE users SET
         locked_until = NOW() + INTERVAL '${minutes} minutes',
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    async resetLoginAttempts(id) {
        await pool.query(
            `UPDATE users SET
         failed_login_attempts = 0,
         locked_until = NULL,
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    // ── PIN management ────────────────────────────────────
    async setPin(id, pin_hash) {
        await pool.query(
            `UPDATE users SET pin_hash = $1, updated_at = NOW() WHERE id = $2`,
            [pin_hash, id]
        );
    },

    async removePin(id) {
        await pool.query(
            `UPDATE users SET pin_hash = NULL,
         failed_pin_attempts = 0,
         pin_locked_until = NULL,
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    async incrementFailedPin(id) {
        const result = await pool.query(
            `UPDATE users SET
         failed_pin_attempts = failed_pin_attempts + 1,
         updated_at = NOW()
       WHERE id = $1
       RETURNING failed_pin_attempts`, [id]
        );
        return result.rows[0].failed_pin_attempts;
    },

    async lockPin(id, minutes = 10) {
        await pool.query(
            `UPDATE users SET
         pin_locked_until = NOW() + INTERVAL '${minutes} minutes',
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    async resetPinAttempts(id) {
        await pool.query(
            `UPDATE users SET
         failed_pin_attempts = 0,
         pin_locked_until = NULL,
         updated_at = NOW()
       WHERE id = $1`, [id]
        );
    },

    // ── Refresh token ─────────────────────────────────────
    async setRefreshToken(id, token_hash) {
        await pool.query(
            `UPDATE users SET refresh_token_hash = $1, updated_at = NOW() WHERE id = $2`,
            [token_hash, id]
        );
    },

    async clearRefreshToken(id) {
        await pool.query(
            `UPDATE users SET refresh_token_hash = NULL, updated_at = NOW() WHERE id = $1`,
            [id]
        );
    }
};

// ─────────────────────────────────────────────────────────
// Transaction Model
// ─────────────────────────────────────────────────────────
const TransactionModel = {

    async create({ user_id, amount, type, merchant_or_sender, category, source, note, transaction_date, raw_sms }) {
        const result = await pool.query(
            `INSERT INTO transactions
         (user_id, amount, type, merchant_or_sender, category, source, note, transaction_date, raw_sms)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING *`,
            [user_id, amount, type, merchant_or_sender || 'Unknown',
                category || 'Uncategorized', source, note,
                transaction_date || new Date(), raw_sms]
        );
        return result.rows[0];
    },

    async getByMonth(user_id, month, year) {
        const result = await pool.query(
            `SELECT * FROM transactions
       WHERE user_id = $1
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR  FROM transaction_date) = $3
       ORDER BY transaction_date DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    async getById(id, user_id) {
        const result = await pool.query(
            `SELECT * FROM transactions WHERE id = $1 AND user_id = $2`,
            [id, user_id]
        );
        return result.rows[0] || null;
    },

    async delete(id, user_id) {
        const result = await pool.query(
            `DELETE FROM transactions WHERE id = $1 AND user_id = $2 RETURNING *`,
            [id, user_id]
        );
        return result.rows[0] || null;
    },

    async getMerchantSummary(user_id, month, year) {
        const result = await pool.query(
            `SELECT merchant_or_sender,
              SUM(amount)     AS total_spent,
              COUNT(*)        AS visit_count,
              ROUND(AVG(amount), 2) AS avg_per_visit
       FROM transactions
       WHERE user_id = $1 AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR  FROM transaction_date) = $3
       GROUP BY merchant_or_sender
       ORDER BY total_spent DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    async getCategorySummary(user_id, month, year) {
        const result = await pool.query(
            `SELECT category,
              SUM(amount) AS total_spent,
              COUNT(*)    AS count
       FROM transactions
       WHERE user_id = $1 AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR  FROM transaction_date) = $3
       GROUP BY category
       ORDER BY total_spent DESC`,
            [user_id, month, year]
        );
        return result.rows;
    },

    async getMonthTotals(user_id, month, year) {
        const result = await pool.query(
            `SELECT type, SUM(amount) AS total
       FROM transactions
       WHERE user_id = $1
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR  FROM transaction_date) = $3
       GROUP BY type`,
            [user_id, month, year]
        );
        const totals = { income: 0, expense: 0 };
        result.rows.forEach(r => { totals[r.type] = parseFloat(r.total); });
        return totals;
    },

    async getDailySpend(user_id, month, year) {
        const result = await pool.query(
            `SELECT DATE(transaction_date) AS day,
              SUM(amount) AS daily_total
       FROM transactions
       WHERE user_id = $1 AND type = 'expense'
         AND EXTRACT(MONTH FROM transaction_date) = $2
         AND EXTRACT(YEAR  FROM transaction_date) = $3
       GROUP BY DATE(transaction_date)
       ORDER BY day ASC`,
            [user_id, month, year]
        );
        return result.rows;
    }
};

// ─────────────────────────────────────────────────────────
// Budget Model
// ─────────────────────────────────────────────────────────
const BudgetModel = {

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

    async getByMonth(user_id, month, year) {
        const result = await pool.query(
            `SELECT * FROM budget_settings
       WHERE user_id = $1 AND month = $2 AND year = $3`,
            [user_id, month, year]
        );
        return result.rows[0] || null;
    }
};

// ─────────────────────────────────────────────────────────
// Security Log Model
// ─────────────────────────────────────────────────────────
const SecurityLogModel = {

    async log(user_id, event, ip_address, detail = null) {
        await pool.query(
            `INSERT INTO security_logs (user_id, event, ip_address, detail)
       VALUES ($1, $2, $3, $4)`,
            [user_id, event, ip_address, detail]
        );
    }
};

module.exports = { UserModel, TransactionModel, BudgetModel, SecurityLogModel };
