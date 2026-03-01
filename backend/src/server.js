require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const app = express();

// ─── Security & Middleware ───────────────────
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(morgan('dev'));

// Rate limiting — 100 requests per 15 minutes per IP
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: { success: false, message: 'Too many requests, please try again later.' }
});
app.use('/api', limiter);

// ─── Routes ─────────────────────────────────
const authRoutes = require('./routes/auth');
const transactionRoutes = require('./routes/transactions');
const dashboardRoutes = require('./routes/dashboard');

app.use('/api/auth', authRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Health check
app.get('/health', (req, res) => {
    res.json({
        success: true,
        service: 'CampusCash API',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// ─── Error Handlers ──────────────────────────
const { errorHandler, notFound } = require('./middleware');
app.use(notFound);
app.use(errorHandler);

// ─── Start Server ────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`\n🚀 CampusCash API running on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   Auth:   http://localhost:${PORT}/api/auth`);
    console.log(`   Tx:     http://localhost:${PORT}/api/transactions`);
    console.log(`   Dash:   http://localhost:${PORT}/api/dashboard\n`);
});

module.exports = app;
