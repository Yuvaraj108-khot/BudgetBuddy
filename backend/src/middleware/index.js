const jwt = require('jsonwebtoken');
const { UserModel } = require('../models');

/**
 * JWT Authentication Middleware
 * Validates Bearer token and attaches req.user + req.userFull
 */
const authMiddleware = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ success: false, message: 'No token provided. Please log in.' });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;          // { id }
        req.userFull = await UserModel.findById(decoded.id);

        if (!req.userFull) {
            return res.status(401).json({ success: false, message: 'User account not found.' });
        }

        next();
    } catch (err) {
        if (err.name === 'TokenExpiredError') {
            return res.status(401).json({ success: false, message: 'Session expired. Please log in again.', code: 'TOKEN_EXPIRED' });
        }
        return res.status(401).json({ success: false, message: 'Invalid token. Please log in again.' });
    }
};

/**
 * PIN Check Middleware
 * Use on routes that need PIN verification (optional, Flutter-controlled)
 */
const pinRequiredMiddleware = (req, res, next) => {
    const pinVerified = req.headers['x-pin-verified'];
    if (!pinVerified || pinVerified !== 'true') {
        return res.status(403).json({
            success: false,
            message: 'App PIN verification required. Unlock the app first.',
            code: 'PIN_REQUIRED'
        });
    }
    next();
};

/**
 * Global Error Handler
 */
const errorHandler = (err, req, res, next) => {
    console.error('Unhandled error:', err.stack);
    res.status(500).json({
        success: false,
        message: 'An unexpected error occurred',
        ...(process.env.NODE_ENV === 'development' && { error: err.message })
    });
};

/**
 * 404 Not Found
 */
const notFound = (req, res) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.method} ${req.originalUrl} not found`
    });
};

module.exports = { authMiddleware, pinRequiredMiddleware, errorHandler, notFound };
