'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function listSessions(userId) {
  const r = await query(
    `SELECT cs.*,
      (SELECT COUNT(*) FROM chat_messages cm WHERE cm.session_id = cs.id) AS message_count
     FROM chat_sessions cs
     WHERE cs.user_id = $1 AND NOT cs.is_archived
     ORDER BY cs.updated_at DESC`,
    [userId]
  );
  return r.rows;
}

async function createSession(userId, payload) {
  const r = await query(
    `INSERT INTO chat_sessions (user_id, title)
     VALUES ($1, $2) RETURNING *`,
    [userId, payload.title || null]
  );
  return r.rows[0];
}

async function getMessages(userId, sessionId, opts = {}) {
  const session = await query(
    'SELECT id FROM chat_sessions WHERE id = $1 AND user_id = $2',
    [sessionId, userId]
  );
  if (session.rowCount === 0) throw ApiError.notFound('Session not found.');

  const limit = Math.min(Math.max(Number(opts.limit) || 30, 1), 100);
  const before = opts.before || null;

  const params = [sessionId];
  let where = 'session_id = $1';
  if (before) {
    params.push(before);
    where += ` AND created_at < (SELECT created_at FROM chat_messages WHERE id = $2 AND session_id = $1)`;
  }
  params.push(limit + 1);
  const r = await query(
    `SELECT * FROM chat_messages WHERE ${where} ORDER BY created_at DESC LIMIT $${params.length}`,
    params
  );

  const rows = r.rows;
  const hasMore = rows.length > limit;
  const page = (hasMore ? rows.slice(0, limit) : rows).reverse();

  return {
    messages: page,
    hasMore,
    oldestId: page.length ? page[0].id : null,
  };
}

async function addMessage(userId, sessionId, payload) {
  // Verify ownership
  const session = await query(
    'SELECT id FROM chat_sessions WHERE id = $1 AND user_id = $2',
    [sessionId, userId]
  );
  if (session.rowCount === 0) throw ApiError.notFound('Session not found.');

  const r = await query(
    `INSERT INTO chat_messages (session_id, role, content, intent_action)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [
      sessionId,
      payload.role || 'user',
      payload.content,
      payload.intentAction || {},
    ]
  );

  // Update session timestamp
  await query(
    'UPDATE chat_sessions SET last_message_at = NOW(), updated_at = NOW() WHERE id = $1',
    [sessionId]
  );

  return r.rows[0];
}

async function archiveSession(userId, sessionId) {
  const r = await query(
    `UPDATE chat_sessions SET is_archived = true, updated_at = NOW()
     WHERE id = $1 AND user_id = $2 RETURNING id`,
    [sessionId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Session not found.');
}

async function deleteSession(userId, sessionId) {
  const r = await query(
    `DELETE FROM chat_sessions WHERE id = $1 AND user_id = $2 RETURNING id`,
    [sessionId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Session not found.');
}

module.exports = { listSessions, createSession, getMessages, addMessage, archiveSession, deleteSession };
