'use strict';

const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} = require('../../utils/jwt');
const env = require('../../config/env');

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function findUserByEmail(email) {
  const r = await query('SELECT * FROM users WHERE email = $1', [email]);
  return r.rows[0] || null;
}

async function findUserById(id) {
  const r = await query(
    `SELECT id, email, username, avatar_url, preferred_vibe, role, is_active, created_at
     FROM users WHERE id = $1`,
    [id]
  );
  return r.rows[0] || null;
}

async function register({ email, password, username, preferredVibe = 'funny' }) {
  const existing = await findUserByEmail(email);
  if (existing) {
    throw ApiError.conflict('Email already registered.');
  }
  const hash = await bcrypt.hash(password, 10);
  const result = await withTransaction(async (client) => {
    const userInsert = await client.query(
      `INSERT INTO users (email, password_hash, username, preferred_vibe)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, username, avatar_url, preferred_vibe, role, created_at`,
      [email, hash, username, preferredVibe]
    );
    const user = userInsert.rows[0];
    const wallet = await client.query(
      `INSERT INTO wallets (owner_id, name, type, currency)
       VALUES ($1, 'Ví cá nhân', 'personal', 'VND') RETURNING id`,
      [user.id]
    );
    await client.query(
      `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')`,
      [wallet.rows[0].id, user.id]
    );
    return { user, walletId: wallet.rows[0].id };
  });
  return issueTokens(result.user);
}

async function login({ email, password }) {
  const user = await findUserByEmail(email);
  if (!user || !user.is_active) {
    throw ApiError.unauthorized('Invalid credentials.');
  }
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    throw ApiError.unauthorized('Invalid credentials.');
  }
  await query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user.id]);
  return issueTokens(user);
}

async function issueTokens(user) {
  const accessToken = signAccessToken({ sub: user.id, email: user.email, role: user.role });
  const refreshToken = signRefreshToken({ sub: user.id });
  const expiresAt = new Date(Date.now() + env.jwt.refreshTtl * 1000);
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [user.id, hashToken(refreshToken), expiresAt]
  );
  return {
    accessToken,
    refreshToken,
    expiresIn: env.jwt.accessTtl,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      preferredVibe: user.preferred_vibe,
      avatarUrl: user.avatar_url,
    },
  };
}

async function refresh({ refreshToken }) {
  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch (err) {
    throw ApiError.unauthorized('Invalid refresh token.', { reason: err.message });
  }
  const hash = hashToken(refreshToken);
  const r = await query(
    `SELECT id FROM refresh_tokens
     WHERE user_id = $1 AND token_hash = $2 AND revoked_at IS NULL AND expires_at > NOW()`,
    [decoded.sub, hash]
  );
  if (r.rowCount === 0) {
    throw ApiError.unauthorized('Refresh token revoked or expired.');
  }
  await query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1', [r.rows[0].id]);
  const user = await findUserById(decoded.sub);
  if (!user) throw ApiError.unauthorized('User not found.');
  return issueTokens({
    id: user.id,
    email: user.email,
    role: user.role,
    preferred_vibe: user.preferred_vibe,
    username: user.username,
    avatar_url: user.avatar_url,
  });
}

async function logout({ refreshToken }) {
  try {
    const decoded = verifyRefreshToken(refreshToken);
    await query(
      `UPDATE refresh_tokens SET revoked_at = NOW()
       WHERE user_id = $1 AND token_hash = $2`,
      [decoded.sub, hashToken(refreshToken)]
    );
  } catch (_) {
    // ignore: idempotent logout
  }
}

module.exports = { register, login, refresh, logout, findUserById };
