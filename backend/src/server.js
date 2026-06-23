require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const app = express();

// ─── Security & Middleware ───────────────────
app.use(helmet());
const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : '*';
app.use(cors({ origin: allowedOrigins }));
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
const aiRoutes = require('./routes/ai');
app.use('/api/ai', aiRoutes);

// Health check
app.get('/health', (req, res) => {
    res.json({
        success: true,
        service: 'BudgetBuddy AI Proxy',
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
    console.log(`\n🚀 BudgetBuddy AI Proxy running on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   AI:     http://localhost:${PORT}/api/ai\n`);
});

module.exports = app;
