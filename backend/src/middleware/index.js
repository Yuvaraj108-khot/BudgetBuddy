const jwt = require('jsonwebtoken');

/**
 * JWT Authentication Middleware
 * Protects all routes that require a logged-in user.
 * Expects: Authorization: Bearer <token>
 */
const authMiddleware = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ success: false, message: 'No token provided. Please log in.' });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // { id: ... }
        next();
    } catch (err) {
        return res.status(401).json({ success: false, message: 'Invalid or expired token. Please log in again.' });
    }
};

/**
 * Error Handler Middleware
 * Global fallback for unhandled errors.
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
 * 404 Not Found Middleware
 */
const notFound = (req, res) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.method} ${req.originalUrl} not found`
    });
};

module.exports = { authMiddleware, errorHandler, notFound };
