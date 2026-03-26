const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

const KEY = process.env.FIELD_ENCRYPT_KEY;

// AES-256-GCM encryption
function encrypt(plaintext) {
    if (!plaintext) return plaintext;
    const iv = crypto.randomBytes(12); // 96-bit IV for GCM
    const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(KEY, 'hex'), iv);
    
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag(); // Authentication tag

    return iv.toString('hex') + ':' + tag.toString('hex') + ':' + encrypted.toString('hex');
}

function decrypt(ciphertext) {
    if (!ciphertext) return ciphertext;
    const parts = ciphertext.split(':');
    if (parts.length !== 3) return ciphertext; // Return as is if not encrypted properly

    const iv = Buffer.from(parts[0], 'hex');
    const tag = Buffer.from(parts[1], 'hex');
    const encryptedText = Buffer.from(parts[2], 'hex');

    const decipher = crypto.createDecipheriv('aes-256-gcm', Buffer.from(KEY, 'hex'), iv);
    decipher.setAuthTag(tag);

    const decrypted = Buffer.concat([decipher.update(encryptedText), decipher.final()]);
    return decrypted.toString('utf8');
}

const userSchema = new mongoose.Schema({
    username: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        // Using a getter to decrypt on read
        get: decrypt
    },
    password: {
        type: String,
        required: true
    }
}, { timestamps: true, toJSON: { getters: true }, toObject: { getters: true } });

// Hooks for encrypting email and hashing password
userSchema.pre('save', async function(next) {
    // Hash password with bcrypt cost factor 12
    if (this.isModified('password')) {
        this.password = await bcrypt.hash(this.password, 12);
    }
    
    // Encrypt email with AES-256-GCM
    if (this.isModified('email')) {
        this.email = encrypt(this.email);
    }
    next();
});

module.exports = mongoose.model('User', userSchema);
