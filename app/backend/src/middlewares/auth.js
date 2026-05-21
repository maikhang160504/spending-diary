'use strict';

const ApiError = require('../utils/ApiError');
const { verifyAccessToken } = require('../utils/jwt');

function requireAuth(req, _res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return next(ApiError.unauthorized('Missing Bearer token.'));
  }
  try {
    const decoded = verifyAccessToken(match[1]);
    req.user = { id: decoded.sub, email: decoded.email, role: decoded.role || 'user' };
    return next();
  } catch (err) {
    return next(ApiError.unauthorized('Invalid or expired token.', { reason: err.message }));
  }
}

function requireRole(...roles) {
  return function roleGuard(req, _res, next) {
    if (!req.user) return next(ApiError.unauthorized());
    if (!roles.includes(req.user.role)) {
      return next(ApiError.forbidden('Role not permitted.'));
    }
    return next();
  };
}

module.exports = { requireAuth, requireRole };
