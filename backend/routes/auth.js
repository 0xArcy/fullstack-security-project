const express = require('express');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sanitize = require('mongo-sanitize');
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const logger = require('../utils/logger');

const router = express.Router();

// Rate limiting for auth routes
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 20, // limit each IP to 20 requests per windowMs
    message: 'Too many requests from this IP, please try again later'
});

// Helper for generating tokens
const generateTokens = (userId) => {
    const accessToken = jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '15m' }); // Short lived
    const refreshToken = jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
    return { accessToken, refreshToken };
};

// Route: Register
router.post('/register', authLimiter, [
    body('username').trim().isLength({ min: 3, max: 30 }).escape(),
    body('email').trim().isEmail().normalizeEmail(),
    body('password').isLength({ min: 8 })
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ error: 'Invalid request body' });

    // Prevent NoSQL Injection via strict sanitization
    const sanitizedBody = sanitize(req.body);

    try {
        const existing = await User.findOne({ username: sanitizedBody.username });
        if (existing) return res.status(400).json({ error: 'User already exists' });

        const user = new User({
            username: sanitizedBody.username,
            email: sanitizedBody.email,
            password: sanitizedBody.password
        });

        await user.save();

        logger.info('User Registered', { action: 'register', userId: user._id, ip: req.ip, outcome: 'success' });
        res.status(201).json({ message: 'Registration successful' });
    } catch (error) {
        logger.error('Registration failed', { error: error.message });
        res.status(500).json({ error: 'Server error' });
    }
});

// Route: Login
router.post('/login', authLimiter, [
    body('username').trim().escape(),
    body('password').notEmpty()
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ error: 'Invalid request body' });

    const sanitizedBody = sanitize(req.body);

    try {
        const user = await User.findOne({ username: sanitizedBody.username });
        if (!user) {
            logger.warn('Failed login attempt user not found', { action: 'login', ip: req.ip, outcome: 'fail' });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const isMatch = await bcrypt.compare(sanitizedBody.password, user.password);
        if (!isMatch) {
            logger.warn('Failed login attempt invalid password', { action: 'login', userId: user._id, ip: req.ip, outcome: 'fail' });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const { accessToken, refreshToken } = generateTokens(user._id);

        logger.info('User Logged In', { action: 'login', userId: user._id, ip: req.ip, outcome: 'success' });

        // HTTPOnly, SameSite=Strict secure cookie for Refresh Token
        res.cookie('refreshToken', refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'strict',
            maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
        });

        // Pass Access Token in JSON Response body
        res.json({ accessToken });
    } catch (error) {
        logger.error('Login failed', { error: error.message });
        res.status(500).json({ error: 'Server error' });
    }
});

// Route: Refresh Token
router.post('/refresh', (req, res) => {
    const refreshToken = req.cookies.refreshToken;
    if (!refreshToken) return res.status(401).json({ error: 'No refresh token' });

    try {
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
        const tokens = generateTokens(decoded.userId);

        res.cookie('refreshToken', tokens.refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'strict',
            maxAge: 7 * 24 * 60 * 60 * 1000
        });

        logger.info('Token Refreshed', { action: 'refresh_token', userId: decoded.userId, outcome: 'success' });
        res.json({ accessToken: tokens.accessToken });
    } catch (err) {
        logger.warn('Invalid refresh token attempt', { action: 'refresh_token', outcome: 'fail' });
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

// Route: Logout
router.post('/logout', (req, res) => {
    res.clearCookie('refreshToken', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict'
    });
    res.json({ message: 'Logged out' });
});

module.exports = router;
