'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function list(userId, walletId) {
  let sql = `SELECT s.*, 
    (SELECT COUNT(*) FROM story_items si WHERE si.story_id = s.id) AS item_count,
    (SELECT COUNT(*) FROM transactions t WHERE t.story_item_id IN (SELECT si2.id FROM story_items si2 WHERE si2.story_id = s.id) AND NOT t.is_deleted) AS tx_count,
    (SELECT content_text FROM ai_comments ac WHERE ac.story_id = s.id ORDER BY ac.created_at DESC LIMIT 1) AS ai_message,
    (SELECT emotion FROM ai_comments ac WHERE ac.story_id = s.id ORDER BY ac.created_at DESC LIMIT 1) AS ai_emotion,
    (SELECT raw_text FROM story_items si WHERE si.story_id = s.id ORDER BY si.created_at ASC LIMIT 1) AS description
    FROM stories s WHERE `;
  const params = [];
  if (walletId) {
    sql += `s.wallet_id = $1 AND EXISTS (
      SELECT 1 FROM wallet_members wm WHERE wm.wallet_id = s.wallet_id AND wm.user_id = $2
    )`;
    params.push(walletId, userId);
  } else {
    sql += 's.user_id = $1';
    params.push(userId);
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

  const comments = await query(
    `SELECT content_text, emotion FROM ai_comments WHERE story_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [storyId]
  );
  const ai_message = comments.rows[0]?.content_text || null;
  const ai_emotion = comments.rows[0]?.emotion || null;

  return { ...r.rows[0], items: items.rows, ai_message, ai_emotion };
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
