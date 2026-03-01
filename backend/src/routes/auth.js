const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const AuthController = require('../controllers/authController');
const { authMiddleware } = require('../middleware');

// ── Validation helpers ────────────────────────────────────
const registerValidation = [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
    body('password')
        .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
        .matches(/[A-Z]/).withMessage('Password must contain an uppercase letter')
        .matches(/[0-9]/).withMessage('Password must contain a number')
];

const loginValidation = [
    body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
    body('password').notEmpty().withMessage('Password is required')
];

const pinValidation = [
    body('pin')
        .isLength({ min: 4, max: 6 }).withMessage('PIN must be 4–6 digits')
        .isNumeric().withMessage('PIN must contain only numbers')
];

// ── Routes ────────────────────────────────────────────────

// Public
router.post('/register', registerValidation, AuthController.register);
router.post('/login', loginValidation, AuthController.login);

// Protected
router.get('/me', authMiddleware, AuthController.me);
router.post('/logout', authMiddleware, AuthController.logout);

// PIN management (all require auth)
router.post('/pin/set', authMiddleware, [...pinValidation, body('current_password').notEmpty()], AuthController.setPin);
router.post('/pin/verify', authMiddleware, pinValidation, AuthController.verifyPin);
router.post('/pin/change', authMiddleware, [...pinValidation.map(v => v), body('old_pin').notEmpty()], AuthController.changePin);
router.delete('/pin', authMiddleware, body('current_password').notEmpty(), AuthController.removePin);

module.exports = router;
