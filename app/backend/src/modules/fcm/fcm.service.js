'use strict';

const { query } = require('../../config/db');
const fcmAdmin = require('../../services/fcmAdmin');
const logger = require('../../config/logger');

async function upsertToken(userId, token, platform = 'android') {
  await query(
    `INSERT INTO user_fcm_tokens (user_id, token, platform, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (user_id, token)
     DO UPDATE SET platform = EXCLUDED.platform, updated_at = NOW()`,
    [userId, token, platform]
  );
}

async function removeToken(userId, token) {
  await query(
    'DELETE FROM user_fcm_tokens WHERE user_id = $1 AND token = $2',
    [userId, token]
  );
}

async function listTokens(userId) {
  const r = await query(
    'SELECT token FROM user_fcm_tokens WHERE user_id = $1',
    [userId]
  );
  return r.rows.map((row) => row.token);
}

async function removeInvalidTokens(tokens) {
  if (!tokens.length) return;
  await query('DELETE FROM user_fcm_tokens WHERE token = ANY($1::text[])', [tokens]);
}

async function sendPushToUser(userId, { title, body, data = {} }) {
  if (!fcmAdmin.isEnabled()) return { sent: 0, skipped: true };

  const tokens = await listTokens(userId);
  if (!tokens.length) return { sent: 0, skipped: true };

  const result = await fcmAdmin.sendMulticast(tokens, { title, body, data });
  if (result.invalidTokens?.length) {
    await removeInvalidTokens(result.invalidTokens);
    logger.info(
      { userId, count: result.invalidTokens.length },
      'Removed invalid FCM tokens'
    );
  }
  return result;
}

module.exports = {
  upsertToken,
  removeToken,
  sendPushToUser,
};
