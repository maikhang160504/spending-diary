'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');

function signAccessToken(payload) {
  return jwt.sign(payload, env.jwt.secret, {
    expiresIn: env.jwt.accessTtl,
    issuer: 'moneystory',
    audience: 'moneystory-app',
  });
}

function signRefreshToken(payload) {
  return jwt.sign(payload, env.jwt.secret, {
    expiresIn: env.jwt.refreshTtl,
    issuer: 'moneystory',
    audience: 'moneystory-refresh',
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, env.jwt.secret, {
    issuer: 'moneystory',
    audience: 'moneystory-app',
  });
}

function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwt.secret, {
    issuer: 'moneystory',
    audience: 'moneystory-refresh',
  });
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
};
