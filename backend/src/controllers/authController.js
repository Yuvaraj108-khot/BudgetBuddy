const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { UserModel, SecurityLogModel } = require('../models');

// ── Config ──────────────────────────────────────────────
const MAX_LOGIN_ATTEMPTS = 5;       // lock account after 5 failed logins
const LOGIN_LOCK_MINUTES = 30;      // locked for 30 minutes
const MAX_PIN_ATTEMPTS = 5;       // lock PIN after 5 wrong entries
const PIN_LOCK_MINUTES = 10;      // PIN locked for 10 minutes

// ── Token helpers ────────────────────────────────────────
function generateAccessToken(userId) {
    return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRES_IN || '1d'
    });
}

function generateRefreshToken(userId) {
    // Refresh token is a random 64-byte hex string, not a JWT
    return crypto.randomBytes(64).toString('hex');
}

// ── Helpers for lockout checks ───────────────────────────
function isLocked(lockUntil) {
    return lockUntil && new Date() < new Date(lockUntil);
}

function minutesLeft(lockUntil) {
    return Math.ceil((new Date(lockUntil) - new Date()) / 60000);
}

// ────────────────────────────────────────────────────────
const AuthController = {

    /**
     * POST /api/auth/register
     */
    async register(req, res) {
        const ip = req.ip;
        try {
            const { name, email, password, phone } = req.body;

            const existing = await UserModel.findByEmail(email);
            if (existing) {
                return res.status(409).json({ success: false, message: 'Email already registered' });
            }

            const password_hash = await bcrypt.hash(password, 12);
            const user = await UserModel.create({ name, email, password_hash, phone });

            const accessToken = generateAccessToken(user.id);
            const refreshToken = generateRefreshToken(user.id);
            const refreshHash = await bcrypt.hash(refreshToken, 10);
            await UserModel.setRefreshToken(user.id, refreshHash);

            await SecurityLogModel.log(user.id, 'REGISTER', ip, 'Account created');

            res.status(201).json({
                success: true,
                message: 'Account created successfully',
                access_token: accessToken,
                refresh_token: refreshToken,
                user: { id: user.id, name: user.name, email: user.email, phone: user.phone }
            });
        } catch (err) {
            console.error('Register error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * POST /api/auth/login
     * With account lockout after 5 failed attempts (30 min lock)
     */
    async login(req, res) {
        const ip = req.ip;
        try {
            const { email, password } = req.body;

            const user = await UserModel.findByEmail(email);
            if (!user) {
                // Don't reveal whether email exists
                return res.status(401).json({ success: false, message: 'Invalid email or password' });
            }

            // ── Check account lockout ──
            if (isLocked(user.locked_until)) {
                await SecurityLogModel.log(user.id, 'LOGIN_BLOCKED', ip, 'Account locked');
                return res.status(423).json({
                    success: false,
                    message: `Account locked due to too many failed attempts. Try again in ${minutesLeft(user.locked_until)} minutes.`
                });
            }

            const isMatch = await bcrypt.compare(password, user.password_hash);

            if (!isMatch) {
                await UserModel.incrementFailedLogin(user.id);
                const attempts = (user.failed_login_attempts || 0) + 1;

                if (attempts >= MAX_LOGIN_ATTEMPTS) {
                    await UserModel.lockAccount(user.id, LOGIN_LOCK_MINUTES);
                    await SecurityLogModel.log(user.id, 'ACCOUNT_LOCKED', ip, `Locked after ${attempts} failed attempts`);
                    return res.status(423).json({
                        success: false,
                        message: `Too many failed attempts. Account locked for ${LOGIN_LOCK_MINUTES} minutes.`
                    });
                }

                await SecurityLogModel.log(user.id, 'LOGIN_FAILED', ip, `Attempt ${attempts}/${MAX_LOGIN_ATTEMPTS}`);
                return res.status(401).json({
                    success: false,
                    message: `Invalid email or password. ${MAX_LOGIN_ATTEMPTS - attempts} attempts remaining.`
                });
            }

            // ── Successful login ──
            await UserModel.resetLoginAttempts(user.id);

            const accessToken = generateAccessToken(user.id);
            const refreshToken = generateRefreshToken(user.id);
            const refreshHash = await bcrypt.hash(refreshToken, 10);
            await UserModel.setRefreshToken(user.id, refreshHash);

            await SecurityLogModel.log(user.id, 'LOGIN_SUCCESS', ip);

            res.json({
                success: true,
                message: 'Logged in successfully',
                access_token: accessToken,
                refresh_token: refreshToken,
                has_pin: !!user.pin_hash,
                user: { id: user.id, name: user.name, email: user.email, phone: user.phone }
            });
        } catch (err) {
            console.error('Login error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * POST /api/auth/logout
     * Invalidates the refresh token
     */
    async logout(req, res) {
        try {
            await UserModel.clearRefreshToken(req.user.id);
            await SecurityLogModel.log(req.user.id, 'LOGOUT', req.ip);
            res.json({ success: true, message: 'Logged out successfully' });
        } catch (err) {
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
            res.json({
                success: true,
                user: {
                    id: user.id, name: user.name, email: user.email,
                    phone: user.phone, has_pin: !!user.pin_hash
                }
            });
        } catch (err) {
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    // ══════════════════════════════════════════════════
    // APP PIN LOCK — Phone stolen protection
    // ══════════════════════════════════════════════════

    /**
     * POST /api/auth/pin/set
     * Set a 4 or 6 digit PIN to lock the app.
     * If phone is stolen, thief cannot see any data without PIN.
     */
    async setPin(req, res) {
        try {
            const { pin, current_password } = req.body;

            // Must verify account password before setting PIN (extra security)
            const user = await UserModel.findByEmail(req.userFull.email);
            const isMatch = await bcrypt.compare(current_password, user.password_hash);
            if (!isMatch) {
                await SecurityLogModel.log(req.user.id, 'PIN_SET_DENIED', req.ip, 'Wrong password');
                return res.status(401).json({ success: false, message: 'Wrong account password' });
            }

            const pin_hash = await bcrypt.hash(pin, 12);
            await UserModel.setPin(req.user.id, pin_hash);
            await SecurityLogModel.log(req.user.id, 'PIN_SET', req.ip);

            res.json({ success: true, message: 'App PIN set successfully. App is now PIN-protected.' });
        } catch (err) {
            console.error('Set PIN error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * POST /api/auth/pin/verify
     * Called every time the app opens (or resumes from background).
     * Locks after 5 wrong attempts for 10 minutes.
     */
    async verifyPin(req, res) {
        const ip = req.ip;
        try {
            const { pin } = req.body;
            const user = req.userFull;

            // ── No PIN set ──
            if (!user.pin_hash) {
                return res.json({ success: true, pin_required: false, message: 'No PIN set' });
            }

            // ── PIN lock check ──
            if (isLocked(user.pin_locked_until)) {
                await SecurityLogModel.log(user.id, 'PIN_BLOCKED', ip);
                return res.status(423).json({
                    success: false,
                    message: `PIN locked. Try again in ${minutesLeft(user.pin_locked_until)} minutes.`
                });
            }

            const isMatch = await bcrypt.compare(pin, user.pin_hash);

            if (!isMatch) {
                const attempts = await UserModel.incrementFailedPin(user.id);
                if (attempts >= MAX_PIN_ATTEMPTS) {
                    await UserModel.lockPin(user.id, PIN_LOCK_MINUTES);
                    await SecurityLogModel.log(user.id, 'PIN_LOCKED', ip, `After ${attempts} attempts`);
                    return res.status(423).json({
                        success: false,
                        message: `Too many wrong PINs. Try again in ${PIN_LOCK_MINUTES} minutes.`
                    });
                }
                await SecurityLogModel.log(user.id, 'PIN_FAILED', ip, `Attempt ${attempts}/${MAX_PIN_ATTEMPTS}`);
                return res.status(401).json({
                    success: false,
                    message: `Wrong PIN. ${MAX_PIN_ATTEMPTS - attempts} attempts remaining.`
                });
            }

            // ── PIN correct ──
            await UserModel.resetPinAttempts(user.id);
            await SecurityLogModel.log(user.id, 'PIN_SUCCESS', ip);

            res.json({ success: true, message: 'PIN verified. Access granted.' });
        } catch (err) {
            console.error('Verify PIN error:', err.message);
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * DELETE /api/auth/pin
     * Remove the PIN lock (requires account password confirmation)
     */
    async removePin(req, res) {
        try {
            const { current_password } = req.body;
            const user = await UserModel.findByEmail(req.userFull.email);
            const isMatch = await bcrypt.compare(current_password, user.password_hash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Wrong account password' });
            }

            await UserModel.removePin(req.user.id);
            await SecurityLogModel.log(req.user.id, 'PIN_REMOVED', req.ip);
            res.json({ success: true, message: 'PIN removed. App is no longer PIN-protected.' });
        } catch (err) {
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    },

    /**
     * POST /api/auth/pin/change
     * Change the PIN
     */
    async changePin(req, res) {
        try {
            const { old_pin, new_pin } = req.body;
            const user = req.userFull;

            if (!user.pin_hash) {
                return res.status(400).json({ success: false, message: 'No PIN is set. Use /pin/set first.' });
            }

            const isMatch = await bcrypt.compare(old_pin, user.pin_hash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Old PIN is incorrect' });
            }

            const new_hash = await bcrypt.hash(new_pin, 12);
            await UserModel.setPin(req.user.id, new_hash);
            await SecurityLogModel.log(req.user.id, 'PIN_CHANGED', req.ip);

            res.json({ success: true, message: 'PIN changed successfully' });
        } catch (err) {
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    }
};

module.exports = AuthController;
