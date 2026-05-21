'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function list(userId, walletId) {
  let sql = `SELECT s.*, 
    (SELECT COUNT(*) FROM story_items si WHERE si.story_id = s.id) AS item_count,
    (SELECT COUNT(*) FROM transactions t WHERE t.story_item_id IN (SELECT si2.id FROM story_items si2 WHERE si2.story_id = s.id) AND NOT t.is_deleted) AS tx_count
    FROM stories s WHERE s.user_id = $1`;
  const params = [userId];
  if (walletId) {
    sql += ' AND s.wallet_id = $2';
    params.push(walletId);
  }
  sql += ' ORDER BY s.occurred_on DESC, s.created_at DESC';
  const r = await query(sql, params);
  return r.rows;
}

async function getById(userId, storyId) {
  const r = await query(
    `SELECT s.* FROM stories s WHERE s.id = $1 AND s.user_id = $2`,
    [storyId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Story not found.');

  // Also fetch items + transactions
  const items = await query(
    `SELECT si.*, 
      (SELECT json_agg(t.*) FROM transactions t WHERE t.story_item_id = si.id AND NOT t.is_deleted) AS transactions
     FROM story_items si WHERE si.story_id = $1 ORDER BY si.created_at`,
    [storyId]
  );

  return { ...r.rows[0], items: items.rows };
}

async function create(userId, payload) {
  const r = await query(
    `INSERT INTO stories (user_id, wallet_id, title, occurred_on, cover_image_url)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [
      userId,
      payload.walletId,
      payload.title || null,
      payload.occurredOn || new Date().toISOString().split('T')[0],
      payload.coverImageUrl || null,
    ]
  );
  return r.rows[0];
}

async function update(userId, storyId, payload) {
  const existing = await getById(userId, storyId);
  const fields = [];
  const values = [storyId, userId];
  let idx = 3;

  for (const [key, col] of [
    ['title', 'title'],
    ['status', 'status'],
    ['coverImageUrl', 'cover_image_url'],
  ]) {
    if (payload[key] !== undefined) {
      fields.push(`${col} = $${idx++}`);
      values.push(payload[key]);
    }
  }

  if (fields.length === 0) return existing;

  fields.push('updated_at = NOW()');
  const r = await query(
    `UPDATE stories SET ${fields.join(', ')} WHERE id = $1 AND user_id = $2 RETURNING *`,
    values
  );
  return r.rows[0];
}

module.exports = { list, getById, create, update };
