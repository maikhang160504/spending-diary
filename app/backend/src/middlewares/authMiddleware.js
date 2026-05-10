const jwt = require('jsonwebtoken');
const db = require('../models');

const authenticate = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const token = authHeader.split(' ')[1];
        // FIXME: Thay JWT_SECRET bang process.env.JWT_SECRET sau khi co file .env
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback_secret_key_for_dev');
        
        // Gán userId vào request object d? s? d?ng ? các t?ng sau
        req.user = { id: decoded.userId };

        /**
         * Chú ý: Dùng SET LOCAL trong Transaction c?a Service d? an toàn v?i Connection Pool.
         * Nên ta không set global ? Middleware n?a d? tránh leak scope.
         */
        
        next();
    } catch (error) {
        return res.status(401).json({ message: 'Invalid or expired token' });
    }
};

module.exports = { authenticate };
