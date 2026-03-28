const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { decryptField, encryptField } = require('../utils/fieldEncryption');

const userSchema = new mongoose.Schema({
    username: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        get: decryptField
    },
    password: {
        type: String,
        required: true
    }
}, { timestamps: true, toJSON: { getters: true }, toObject: { getters: true } });

userSchema.pre('save', async function saveUser(next) {
    if (this.isModified('password')) {
        this.password = await bcrypt.hash(this.password, 12);
    }

    if (this.isModified('email')) {
        this.email = encryptField(this.email);
    }

    next();
});

module.exports = mongoose.model('User', userSchema);
