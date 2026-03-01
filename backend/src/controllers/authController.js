const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { UserModel } = require('../models');

const AuthController = {

    /**
     * POST /api/auth/register
     */
    async register(req, res) {
        try {
            const { name, email, password, phone } = req.body;

            // Check duplicate email
            const existing = await UserModel.findByEmail(email);
            if (existing) {
                return res.status(409).json({ success: false, message: 'Email already registered' });
            }

            const password_hash = await bcrypt.hash(password, 12);
            const user = await UserModel.create({ name, email, password_hash, phone });

            const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
                expiresIn: process.env.JWT_EXPIRES_IN || '7d'
            });

            res.status(201).json({
                success: true,
                message: 'Account created successfully',
                token,
                user
            });
        } catch (err) {
            console.error('Register error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * POST /api/auth/login
     */
    async login(req, res) {
        try {
            const { email, password } = req.body;

            const user = await UserModel.findByEmail(email);
            if (!user) {
                return res.status(401).json({ success: false, message: 'Invalid email or password' });
            }

            const isMatch = await bcrypt.compare(password, user.password_hash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Invalid email or password' });
            }

            const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
                expiresIn: process.env.JWT_EXPIRES_IN || '7d'
            });

            res.json({
                success: true,
                message: 'Logged in successfully',
                token,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    phone: user.phone
                }
            });
        } catch (err) {
            console.error('Login error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * GET /api/auth/me
     */
    async me(req, res) {
        try {
            const user = await UserModel.findById(req.user.id);
            if (!user) return res.status(404).json({ success: false, message: 'User not found' });
            res.json({ success: true, user });
        } catch (err) {
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    }
};

module.exports = AuthController;
