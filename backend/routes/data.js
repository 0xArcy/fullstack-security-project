const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const sanitize = require('mongo-sanitize');
const logger = require('../utils/logger');
const User = require('../models/User');
const Record = require('../models/Record');

const router = express.Router();

const requireAuth = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.userId = decoded.userId;
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Token expired or invalid' });
    }
};

router.get('/profile', requireAuth, async (req, res) => {
    try {
        const user = await User.findById(req.userId);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json({
            username: user.username,
            email: user.email,
        });
    } catch (error) {
        logger.error('Profile fetch failed', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/records', requireAuth, async (req, res) => {
    try {
        const records = await Record.find({ userId: req.userId })
            .sort({ createdAt: -1 })
            .limit(20);

        res.json({
            records: records.map((record) => ({
                id: record._id,
                sensitiveData: record.sensitiveData,
                createdAt: record.createdAt,
            })),
        });
    } catch (error) {
        logger.error('Record fetch failed', { error: error.message, userId: req.userId });
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/submit', requireAuth, [
    body('sensitiveData')
        .isString()
        .trim()
        .isLength({ min: 1, max: 500 }),
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Invalid request body' });
    }

    const safeData = sanitize(req.body.sensitiveData);

    try {
        const record = await Record.create({
            userId: req.userId,
            sensitiveData: safeData,
        });

        logger.info('Data submitted', {
            action: 'data_submit',
            userId: req.userId,
            ip: req.ip,
            outcome: 'success',
            maskedData: logger.maskData(safeData),
        });

        res.status(201).json({
            message: 'Data successfully stored.',
            record: {
                id: record._id,
                sensitiveData: record.sensitiveData,
                createdAt: record.createdAt,
            },
        });
    } catch (error) {
        logger.error('Data submission failed', { error: error.message, userId: req.userId });
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
