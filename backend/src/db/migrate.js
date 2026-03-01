/**
 * Database Migration Script
 * Creates all tables for CampusCash
 */

const pool = require('../config/db');

const createTables = async () => {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Users Table
        await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(150) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
        console.log('✅ users table ready');

        // 2. Budget Settings Table
        await client.query(`
      CREATE TABLE IF NOT EXISTS budget_settings (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id) ON DELETE CASCADE,
        month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
        year INT NOT NULL,
        pocket_money NUMERIC(12, 2) NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE (user_id, month, year)
      );
    `);
        console.log('✅ budget_settings table ready');

        // 3. Transactions Table (Core)
        await client.query(`
      CREATE TABLE IF NOT EXISTS transactions (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id) ON DELETE CASCADE,
        amount NUMERIC(12, 2) NOT NULL,
        type VARCHAR(10) NOT NULL CHECK (type IN ('income', 'expense')),
        merchant_or_sender VARCHAR(200),
        category VARCHAR(100) DEFAULT 'Uncategorized',
        source VARCHAR(10) NOT NULL CHECK (source IN ('sms', 'manual')),
        note TEXT,
        transaction_date TIMESTAMP NOT NULL DEFAULT NOW(),
        raw_sms TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
        console.log('✅ transactions table ready');

        // 4. Index for fast user + date queries
        await client.query(`
      CREATE INDEX IF NOT EXISTS idx_transactions_user_date
      ON transactions(user_id, transaction_date DESC);
    `);

        await client.query(`
      CREATE INDEX IF NOT EXISTS idx_transactions_merchant
      ON transactions(user_id, merchant_or_sender);
    `);

        await client.query('COMMIT');
        console.log('\n🚀 All tables migrated successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', err.message);
        throw err;
    } finally {
        client.release();
        await pool.end();
    }
};

createTables().catch(console.error);
