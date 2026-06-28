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
    `INSERT INTO chat_sessions (user_id, title, wallet_id, last_message_at)
     VALUES ($1, $2, $3, NOW()) RETURNING *`,
    [userId, payload.title || null, payload.walletId || null]
  );
  const session = r.rows[0];

  // Fetch verbal style
  const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
  const style = settingsRes.rows[0]?.verbal_style || 'funny';

  let greeting = 'Hú! Mimo đây! Hôm nay muốn cùng Mimo ghi chép chi tiêu thế nào nào? 🎉';
  if (style === 'funny') {
    greeting = 'Hú! Mimo đây! Hôm nay muốn cùng Mimo quẩy nhật ký chi tiêu thế nào nào? Bắt đầu tám nha! 🎉';
  } else if (style === 'gentle') {
    greeting = 'Chào bạn thương, Mimo ở đây để lắng nghe và đồng hành cùng bạn trong việc quản lý chi tiêu. Hôm nay của bạn thế nào? 💕';
  } else if (style === 'serious') {
    greeting = 'Xin chào. Tôi là Mimo, trợ lý tài chính của bạn. Chúng ta bắt đầu ghi chép và kiểm soát ngân sách hôm nay nhé.';
  } else if (style === 'sarcastic') {
    greeting = 'Ồ, lại là người bạn thích tiêu tiền đây rồi. Mimo sẵn sàng ghi nhận xem hôm nay bạn đã tiêu hoang bao nhiêu rồi đấy! 😏';
  } else if (style === 'strict') {
    greeting = 'Này! Đã vào đây rồi thì lo mà ghi chép chi tiêu đầy đủ vào nhé. Mimo sẽ giám sát kỹ đấy! 😤';
  }

  // Insert mascot's greeting message
  await query(
    `INSERT INTO chat_messages (session_id, role, content, intent_action)
     VALUES ($1, $2, $3, $4)`,
    [session.id, 'assistant', greeting, { intent: 'Chitchat' }]
  );

  return session;
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

async function updateMessageContent(userId, sessionId, messageId, content, intentActionPatch = {}) {
  const session = await query(
    'SELECT id FROM chat_sessions WHERE id = $1 AND user_id = $2',
    [sessionId, userId]
  );
  if (session.rowCount === 0) throw ApiError.notFound('Session not found.');

  const existing = await query(
    'SELECT intent_action FROM chat_messages WHERE id = $1 AND session_id = $2',
    [messageId, sessionId]
  );
  if (existing.rowCount === 0) throw ApiError.notFound('Message not found.');

  const prev = existing.rows[0].intent_action || {};
  const merged = {
    ...prev,
    ...intentActionPatch,
    nlu: {
      ...(prev.nlu || {}),
      ...(intentActionPatch.nlu || {}),
    },
  };

  await query(
    `UPDATE chat_messages SET content = $1, intent_action = $2 WHERE id = $3 AND session_id = $4`,
    [content, merged, messageId, sessionId]
  );

  return { id: messageId, content, intent_action: merged };
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

module.exports = { listSessions, createSession, getMessages, addMessage, updateMessageContent, archiveSession, deleteSession };
