'use strict';

const { query } = require('../../config/db');

async function get(userId) {
  // Upsert: create default row if not exists, then return
  const r = await query(
    `INSERT INTO user_settings (user_id)
     VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING
     RETURNING *`,
    [userId]
  );
  if (r.rows[0]) return r.rows[0];
  const existing = await query('SELECT * FROM user_settings WHERE user_id = $1', [userId]);
  return existing.rows[0] || null;
}

async function update(userId, payload) {
  // Ensure row exists
  await query(
    'INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
    [userId]
  );
  const fields = [];
  const values = [userId];
  let idx = 2;

  if (payload.verbalStyle !== undefined) {
    fields.push(`verbal_style = $${idx++}`);
    values.push(payload.verbalStyle);
  }
  if (payload.themeMode !== undefined) {
    fields.push(`theme_mode = $${idx++}`);
    values.push(payload.themeMode);
  }
  if (payload.personality !== undefined) {
    fields.push(`personality = $${idx++}`);
    values.push(payload.personality);
  }
  if (payload.notificationsEnabled !== undefined) {
    fields.push(`notifications_enabled = $${idx++}`);
    values.push(payload.notificationsEnabled);
  }
  if (payload.locale !== undefined) {
    fields.push(`locale = $${idx++}`);
    values.push(payload.locale);
  }
  if (payload.ageGroup !== undefined) {
    fields.push(`age_group = $${idx++}`);
    values.push(payload.ageGroup);
  }
  if (payload.jobType !== undefined) {
    fields.push(`job_type = $${idx++}`);
    values.push(payload.jobType);
  }

  if (fields.length === 0) {
    return get(userId);
  }

  fields.push('updated_at = NOW()');

  const r = await query(
    `UPDATE user_settings SET ${fields.join(', ')} WHERE user_id = $1 RETURNING *`,
    values
  );
  return r.rows[0];
}

module.exports = { get, update };
