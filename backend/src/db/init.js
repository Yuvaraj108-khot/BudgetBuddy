/**
 * Database Initialization Script — CampusCash
 * Connects to the default 'postgres' database and creates the 'campuscash' database if it doesn't exist.
 */

const { Client } = require('pg');
require('dotenv').config();

const initDatabase = async () => {
  // Use a separate client to connect to the default 'postgres' database
  // since we can't connect to 'campuscash' until it's created.
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: 'postgres', // Connect to default DB
  });

  try {
    await client.connect();
    console.log('✅ Connected to PostgreSQL server');

    // Check if the database already exists
    const res = await client.query("SELECT 1 FROM pg_database WHERE datname = 'campuscash'");
    if (res.rowCount === 0) {
      console.log('🏗️  Creating database "campuscash"...');
      await client.query('CREATE DATABASE campuscash');
      console.log('✅ Database "campuscash" created successfully');
    } else {
      console.log('ℹ️  Database "campuscash" already exists');
    }
  } catch (err) {
    if (err.code === 'ECONNREFUSED') {
      console.error('\n❌ ERROR: Connection Refused.');
      console.error('Please ensure PostgreSQL is installed and the service is running.');
    } else {
      console.error('❌ Error during database initialization:', err.message);
    }
    process.exit(1);
  } finally {
    await client.end();
  }
};

initDatabase();
