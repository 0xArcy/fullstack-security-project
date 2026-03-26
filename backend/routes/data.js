const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const sanitize = require('mongo-sanitize');
const logger = require('../utils/logger');
const User = require('../models/User');

const router = express.Router();

// Middleware to protect routes via Access Token
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

// GET User Profile (testing authenticated data retrieval and decryption)
router.get('/profile', requireAuth, async (req, res) => {
    try {
        // Will decrypt email automatically due to Mongoose getter
        const user = await User.findById(req.userId);
        if (!user) return res.status(404).json({ error: 'User not found' });

        res.json({
            username: user.username,
            email: user.email // Sent decrypted to the authorized client
        });
    } catch (error) {
        logger.error('Profile fetch failed', { error: error.message });
        res.status(500).json({ error: 'Server error' });
    }
});

// Demo Route for accepting form submissions (NoSQL injection validation)
router.post('/submit', requireAuth, [
    body('sensitiveData').trim().notEmpty().escape()
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ error: 'Invalid request body' });

    const safeData = sanitize(req.body);

    logger.info('Data Submitted', { 
        action: 'data_submit', 
        userId: req.userId, 
        outcome: 'success',
        // Mask the sensitive data before logging
        maskedData: logger.maskData(safeData.sensitiveData) 
    });

    res.json({ 
        message: 'Data successfully received and sanitised.',
        received: safeData.sensitiveData // returning for preview in UI
    });
});

module.exports = router;
