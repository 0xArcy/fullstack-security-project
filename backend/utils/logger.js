const winston = require('winston');

// Structured JSON logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json() // Output as JSON for SIEM compatibility
    ),
    defaultMeta: { service: 'backend-api' },
    transports: [
        new winston.transports.Console()
        // In production, you'd add: new winston.transports.File({ filename: 'audit.log' })
    ]
});

// Helper to mask PII data
logger.maskData = (str) => {
    if (!str || str.length < 4) return '****';
    return '*'.repeat(str.length - 4) + str.slice(-4);
};

module.exports = logger;
