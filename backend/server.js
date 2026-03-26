require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const helmet = require('helmet');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const logger = require('./utils/logger');
const authRoutes = require('./routes/auth');
const dataRoutes = require('./routes/data');

// 1. Fail-fast Boot Validation
const required = ['PORT', 'MONGO_URI', 'JWT_SECRET', 'JWT_REFRESH_SECRET', 'FIELD_ENCRYPT_KEY', 'ALLOWED_ORIGIN'];
required.forEach(key => {
    if (!process.env[key]) {
        console.error(`FATAL ERROR: Missing required env var: ${key}`);
        process.exit(1);
    }
});

const app = express();

// 2. Security Middleware (Helmet + CORS)
app.use(helmet({
    // Sets Strict-Transport-Security (HSTS), Content-Security-Policy, etc.
    hsts: { maxAge: 63072000, includeSubDomains: true, preload: true },
    hidePoweredBy: true // Disables X-Powered-By
}));

app.use(cors({
    origin: process.env.ALLOWED_ORIGIN, // Whitelisted Origin Only
    credentials: true, // Allow cookies to be sent
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));

app.use(express.json({ limit: '10kb' })); // Body limit to prevent payload flooding
app.use(cookieParser());

// 3. Connect to MongoDB with TLS and Pool Config
mongoose.connect(process.env.MONGO_URI, {
    tls: true, // Enforce TLS
    maxPoolSize: 10,
    serverSelectionTimeoutMS: 5000
}).then(() => {
    logger.info('Connected to MongoDB via TLS');
}).catch(err => {
    // Graceful error handling (do not log connection string)
    logger.error('Failed to connect to MongoDB', { error: err.message });
    process.exit(1);
});

// 4. Routes Mount
app.use('/api/auth', authRoutes);
app.use('/api/data', dataRoutes);

// Generic Error Handler
app.use((err, req, res, next) => {
    logger.error('Unhandled Server Error', { error: err.message });
    res.status(500).json({ error: 'Internal Server Error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    logger.info(`Secure API Server running on port ${PORT}`);
});