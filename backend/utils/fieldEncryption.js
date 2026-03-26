const crypto = require('crypto');

const rawKey = process.env.FIELD_ENCRYPT_KEY || '';

if (!/^[a-fA-F0-9]{64}$/.test(rawKey)) {
    throw new Error('FIELD_ENCRYPT_KEY must be a 64-character hex string (32 bytes).');
}

const key = Buffer.from(rawKey, 'hex');

function encryptField(plaintext) {
    if (typeof plaintext !== 'string' || plaintext.length === 0) {
        return plaintext;
    }

    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();

    return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

function decryptField(ciphertext) {
    if (typeof ciphertext !== 'string' || ciphertext.length === 0) {
        return ciphertext;
    }

    const parts = ciphertext.split(':');
    if (parts.length !== 3) {
        return ciphertext;
    }

    const [ivHex, tagHex, encryptedHex] = parts;
    const iv = Buffer.from(ivHex, 'hex');
    const tag = Buffer.from(tagHex, 'hex');
    const encrypted = Buffer.from(encryptedHex, 'hex');

    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);

    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
}

module.exports = {
    decryptField,
    encryptField,
};
