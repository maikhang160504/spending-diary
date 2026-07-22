'use strict';

const ApiError = require('../utils/ApiError');
const { verifyAccessToken } = require('../utils/jwt');

const { query } = require('../config/db');

async function requireAuth(req, _res, next) {
  let token = '';
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (match) {
    token = match[1];
  } else if (req.query?.token) {
    token = req.query.token;
  }

  if (!token) {
    return next(ApiError.unauthorized('Missing Bearer token.'));
  }
  try {
    const decoded = verifyAccessToken(token);
    
    // Check if user is banned
    const userResult = await query('SELECT status, ban_reason FROM users WHERE id = $1', [decoded.sub]);
    if (userResult.rows.length > 0) {
      const user = userResult.rows[0];
      if (user.status === 'banned') {
        return next(ApiError.forbidden(`Your account has been banned. Reason: ${user.ban_reason || 'Unknown'}`));
      }
    }

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

async function requireAuthWithoutBanCheck(req, _res, next) {
  let token = '';
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (match) {
    token = match[1];
  } else if (req.query?.token) {
    token = req.query.token;
  }

  if (!token) {
    return next(ApiError.unauthorized('Missing Bearer token.'));
  }
  try {
    const decoded = verifyAccessToken(token);
    req.user = { id: decoded.sub, email: decoded.email, role: decoded.role || 'user' };
    return next();
  } catch (err) {
    return next(ApiError.unauthorized('Invalid or expired token.', { reason: err.message }));
  }
}

module.exports = { requireAuth, requireRole, requireAuthWithoutBanCheck };
