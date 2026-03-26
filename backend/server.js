require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const helmet = require('helmet');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const logger = require('./utils/logger');
const requiredEnvVars = [
    'PORT',
    'MONGO_URI',
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
    'FIELD_ENCRYPT_KEY',
    'ALLOWED_ORIGIN'
];
const fieldKey = process.env.FIELD_ENCRYPT_KEY || '';
const allowedOrigins = (process.env.ALLOWED_ORIGIN || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

for (const key of requiredEnvVars) {
    if (!process.env[key]) {
        console.error(`FATAL ERROR: Missing required env var: ${key}`);
        process.exit(1);
    }
}

if (!/^[a-fA-F0-9]{64}$/.test(fieldKey)) {
    console.error('FATAL ERROR: FIELD_ENCRYPT_KEY must be a 64-character hex string (32 bytes).');
    process.exit(1);
}

if (allowedOrigins.length === 0) {
    console.error('FATAL ERROR: ALLOWED_ORIGIN must contain at least one allowed origin.');
    process.exit(1);
}

const authRoutes = require('./routes/auth');
const dataRoutes = require('./routes/data');

const app = express();
const isProduction = process.env.NODE_ENV === 'production';
const trustProxy = process.env.TRUST_PROXY === '1' ? 1 : false;

app.disable('x-powered-by');
app.set('trust proxy', trustProxy);

app.use((req, res, next) => {
    if (!isProduction) {
        return next();
    }

    if (req.secure || req.get('x-forwarded-proto') === 'https') {
        return next();
    }

    return res.status(400).json({ error: 'HTTPS is required' });
});

app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
    hsts: isProduction ? { maxAge: 63072000, includeSubDomains: true, preload: true } : false,
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
}));

app.use(cors({
    origin(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
            return callback(null, true);
        }
        return callback(new Error('CORS origin denied'));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));

app.use(express.json({ limit: '10kb' }));
app.use(cookieParser());

app.use((err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        return res.status(400).json({ error: 'Invalid JSON payload' });
    }
    return next(err);
});

app.use('/api/auth', authRoutes);
app.use('/api/data', dataRoutes);

app.use((err, req, res, next) => {
    if (err.message === 'CORS origin denied') {
        logger.warn('Blocked disallowed CORS origin', { origin: req.get('origin') || 'unknown', ip: req.ip });
        return res.status(403).json({ error: 'Origin not allowed' });
    }

    logger.error('Unhandled server error', { error: err.message, stack: isProduction ? undefined : err.stack });
    res.status(500).json({ error: 'Internal Server Error' });
});

const PORT = process.env.PORT || 3000;

async function startServer() {
    try {
        const connectOptions = {
            tls: true,
            maxPoolSize: Number.parseInt(process.env.MONGO_MAX_POOL_SIZE || '10', 10),
            serverSelectionTimeoutMS: Number.parseInt(process.env.MONGO_SERVER_SELECTION_TIMEOUT_MS || '5000', 10),
        };

        if (process.env.MONGO_TLS_CA_FILE) {
            connectOptions.tlsCAFile = process.env.MONGO_TLS_CA_FILE;
        }

        if (process.env.MONGO_TLS_ALLOW_INVALID_CERTS === 'true') {
            connectOptions.tlsAllowInvalidCertificates = true;
        }

        await mongoose.connect(process.env.MONGO_URI, {
            ...connectOptions,
        });
        logger.info('Connected to MongoDB via TLS');
    } catch (error) {
        logger.error('Failed to connect to MongoDB', { error: error.message });
        process.exit(1);
    }

    app.listen(PORT, () => {
        logger.info(`Secure API server running on port ${PORT}`);
    });
}

if (require.main === module) {
    startServer();
}

module.exports = { app, startServer };
