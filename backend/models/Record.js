const mongoose = require('mongoose');
const { decryptField, encryptField } = require('../utils/fieldEncryption');

const recordSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true,
    },
    sensitiveData: {
        type: String,
        required: true,
        get: decryptField,
    },
}, { timestamps: true, toJSON: { getters: true }, toObject: { getters: true } });

recordSchema.pre('save', function saveRecord(next) {
    if (this.isModified('sensitiveData')) {
        this.sensitiveData = encryptField(this.sensitiveData);
    }
    next();
});

module.exports = mongoose.model('Record', recordSchema);
