'use strict';

const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const walletService = require('../wallets/wallets.service');
const { paginate } = require('../../utils/paginate');

function row(r) {
  return {
    id: r.id,
    walletId: r.wallet_id,
    creatorId: r.creator_id,
    categoryId: r.category_id,
    categoryCode: r.category_code,
    amount: Number(r.amount),
    type: r.type,
    source: r.source,
    note: r.note,
    imageUrl: r.image_url,
    thumbnailUrl: r.thumbnail_url,
    aiExtracted: r.ai_extracted,
    aiConfidence: r.ai_confidence !== null ? Number(r.ai_confidence) : null,
    aiMeta: r.ai_meta || {},
    mascotMood: r.mascot_mood,
    aiComment: r.ai_comment,
    occurredAt: r.occurred_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

async function findCategoryByCode(userId, code, type) {
  if (!code) return null;
  const r = await query(
    `SELECT id FROM categories
     WHERE code = $1
       AND (owner_id IS NULL OR owner_id = $2)
       AND (type = $3 OR type = 'both')
       AND is_active = TRUE
     ORDER BY owner_id NULLS LAST
     LIMIT 1`,
    [code, userId, type]
  );
  return r.rows[0]?.id || null;
}

async function create(userId, payload) {
  await walletService.assertMember(payload.walletId, userId, ['owner', 'member']);
  const categoryId = await findCategoryByCode(userId, payload.categoryCode, payload.type);

  const r = await query(
    `INSERT INTO transactions
       (wallet_id, creator_id, category_id, category_code, amount, type, source,
        note, image_url, thumbnail_url, ai_extracted, ai_confidence, ai_meta,
        occurred_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
             COALESCE($14::timestamptz, NOW()))
     RETURNING *`,
    [
      payload.walletId,
      userId,
      categoryId,
      payload.categoryCode || null,
      payload.amount,
      payload.type,
      payload.source,
      payload.note || null,
      payload.imageUrl || null,
      payload.thumbnailUrl || null,
      payload.aiExtracted || false,
      payload.aiConfidence || null,
      payload.aiMeta || {},
      payload.occurredAt || null,
    ]
  );
  return row(r.rows[0]);
}

async function listForUser(userId, filters) {
  const { limit, offset, page, pageSize } = paginate(filters);

  const conds = ['t.is_deleted = FALSE'];
  const values = [];

  // Restrict to wallets the user belongs to.
  values.push(userId);
  conds.push(
    `t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $${values.length})`
  );

  if (filters.walletId) {
    values.push(filters.walletId);
    conds.push(`t.wallet_id = $${values.length}`);
  }
  if (filters.categoryCode) {
    values.push(filters.categoryCode);
    conds.push(`t.category_code = $${values.length}`);
  }
  if (filters.type) {
    values.push(filters.type);
    conds.push(`t.type = $${values.length}`);
  }
  if (filters.from) {
    values.push(filters.from);
    conds.push(`t.occurred_at >= $${values.length}`);
  }
  if (filters.to) {
    values.push(filters.to);
    conds.push(`t.occurred_at <= $${values.length}`);
  }

  const where = conds.join(' AND ');

  const totalQ = await query(`SELECT COUNT(*)::int AS c FROM transactions t WHERE ${where}`, values);
  values.push(limit, offset);
  const dataQ = await query(
    `SELECT t.* FROM transactions t WHERE ${where}
     ORDER BY t.occurred_at DESC, t.created_at DESC
     LIMIT $${values.length - 1} OFFSET $${values.length}`,
    values
  );
  return {
    page,
    pageSize,
    total: totalQ.rows[0].c,
    items: dataQ.rows.map(row),
  };
}

async function getById(userId, id) {
  const r = await query(
    `SELECT t.* FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id AND wm.user_id = $1
     WHERE t.id = $2 AND t.is_deleted = FALSE`,
    [userId, id]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Transaction not found.');
  return row(r.rows[0]);
}

async function update(userId, id, payload) {
  // Make sure user can access tx (also returns wallet to assert role).
  const current = await query(
    `SELECT t.wallet_id, t.type FROM transactions t
     JOIN wallet_members wm ON wm.wallet_id = t.wallet_id AND wm.user_id = $1
     WHERE t.id = $2 AND t.is_deleted = FALSE`,
    [userId, id]
  );
  if (current.rowCount === 0) throw ApiError.notFound('Transaction not found.');
  await walletService.assertMember(current.rows[0].wallet_id, userId, ['owner', 'member']);

  const fields = [];
  const values = [];
  let i = 1;
  for (const [k, col] of [
    ['amount', 'amount'],
    ['type', 'type'],
    ['note', 'note'],
    ['categoryCode', 'category_code'],
    ['imageUrl', 'image_url'],
    ['thumbnailUrl', 'thumbnail_url'],
  ]) {
    if (payload[k] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(payload[k]);
    }
  }
  if (payload.occurredAt !== undefined) {
    fields.push(`occurred_at = $${i++}`);
    values.push(payload.occurredAt);
  }
  if (payload.categoryCode !== undefined) {
    const newType = payload.type || current.rows[0].type;
    const catId = await findCategoryByCode(userId, payload.categoryCode, newType);
    fields.push(`category_id = $${i++}`);
    values.push(catId);
  }
  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  fields.push(`updated_at = NOW()`);
  values.push(id);
  const r = await query(
    `UPDATE transactions SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
    values
  );
  return row(r.rows[0]);
}

async function softDelete(userId, id) {
  const r = await query(
    `UPDATE transactions t SET is_deleted = TRUE, updated_at = NOW()
     WHERE t.id = $2
       AND EXISTS (SELECT 1 FROM wallet_members wm
                   WHERE wm.wallet_id = t.wallet_id AND wm.user_id = $1)
     RETURNING id`,
    [userId, id]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Transaction not found.');
}

async function createFromAi(userId, payload) {
  return withTransaction(async (client) => {
    const tx = await create(userId, payload);
    return tx;
  });
}

module.exports = {
  create,
  listForUser,
  getById,
  update,
  softDelete,
  createFromAi,
  findCategoryByCode,
};
