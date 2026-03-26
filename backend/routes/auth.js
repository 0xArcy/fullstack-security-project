const express = require('express');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sanitize = require('mongo-sanitize');
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const logger = require('../utils/logger');

const router = express.Router();
const secureCookie = process.env.COOKIE_SECURE !== 'false';

const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests from this IP, please try again later' },
});

const registerValidation = [
    body('username')
        .isString()
        .trim()
        .isLength({ min: 3, max: 30 })
        .matches(/^[A-Za-z0-9_.-]+$/),
    body('email')
        .isString()
        .trim()
        .isLength({ max: 254 })
        .isEmail()
        .normalizeEmail(),
    body('password')
        .isString()
        .isLength({ min: 12, max: 128 }),
];

const loginValidation = [
    body('username')
        .isString()
        .trim()
        .isLength({ min: 3, max: 30 }),
    body('password')
        .isString()
        .isLength({ min: 1, max: 128 }),
];

const validateRequest = (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        res.status(400).json({ error: 'Invalid request body' });
        return false;
    }
    return true;
};

const generateTokens = (userId) => {
    const accessToken = jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '15m', algorithm: 'HS256' });
    const refreshToken = jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d', algorithm: 'HS256' });
    return { accessToken, refreshToken };
};

const refreshCookieOptions = {
    httpOnly: true,
    secure: secureCookie,
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000,
};

router.post('/register', authLimiter, registerValidation, async (req, res) => {
    if (!validateRequest(req, res)) {
        return;
    }

    const username = sanitize(req.body.username);
    const email = sanitize(req.body.email);
    const password = sanitize(req.body.password);

    try {
        const existing = await User.findOne({ username });
        if (existing) {
            return res.status(400).json({ error: 'User already exists' });
        }

        const user = new User({
            username,
            email,
            password,
        });
        await user.save();

        logger.info('User registered', { action: 'register', userId: user._id, ip: req.ip, outcome: 'success' });
        res.status(201).json({ message: 'Registration successful' });
    } catch (error) {
        logger.error('Registration failed', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/login', authLimiter, loginValidation, async (req, res) => {
    if (!validateRequest(req, res)) {
        return;
    }

    const username = sanitize(req.body.username);
    const password = sanitize(req.body.password);

    try {
        const user = await User.findOne({ username });
        if (!user) {
            logger.warn('Failed login attempt (user not found)', { action: 'login', ip: req.ip, outcome: 'fail' });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            logger.warn('Failed login attempt (bad password)', { action: 'login', userId: user._id, ip: req.ip, outcome: 'fail' });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const { accessToken, refreshToken } = generateTokens(user._id);
        logger.info('User logged in', { action: 'login', userId: user._id, ip: req.ip, outcome: 'success' });
        res.cookie('refreshToken', refreshToken, refreshCookieOptions);
        res.json({ accessToken });
    } catch (error) {
        logger.error('Login failed', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/refresh', authLimiter, (req, res) => {
    const refreshToken = req.cookies.refreshToken;
    if (!refreshToken) {
        return res.status(401).json({ error: 'No refresh token' });
    }

    try {
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
        const tokens = generateTokens(decoded.userId);
        res.cookie('refreshToken', tokens.refreshToken, refreshCookieOptions);
        logger.info('Token refreshed', {
            action: 'refresh_token',
            userId: decoded.userId,
            ip: req.ip,
            outcome: 'success',
        });
        res.json({ accessToken: tokens.accessToken });
    } catch (error) {
        logger.warn('Invalid refresh token attempt', { action: 'refresh_token', ip: req.ip, outcome: 'fail' });
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

router.post('/logout', (req, res) => {
    res.clearCookie('refreshToken', {
        httpOnly: true,
        secure: secureCookie,
        sameSite: 'strict',
    });
    logger.info('User logged out', { action: 'logout', ip: req.ip, outcome: 'success' });
    res.json({ message: 'Logged out' });
});

module.exports = router;
