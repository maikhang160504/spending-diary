'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

function row(r) {
  return {
    id: r.id,
    userId: r.user_id,
    walletId: r.wallet_id,
    amount: Number(r.amount),
    type: r.type,
    categoryCode: r.category_code,
    note: r.note,
    frequency: r.frequency,
    nextOccurrence: r.next_occurrence,
    isActive: r.is_active,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

async function list(userId) {
  const r = await query(
    `SELECT * FROM recurring_rules WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId]
  );
  return r.rows.map(row);
}

async function create(userId, payload) {
  const walletId = payload.walletId;
  const categoryCode = payload.categoryCode || null;
  const type = payload.type || 'expense';
  const amount = payload.amount;
  const note = payload.note || null;
  const frequency = payload.frequency;
  const nextOccurrence = payload.nextOccurrence;
  const isActive = payload.isActive !== undefined ? payload.isActive : true;

  // Verify wallet ownership
  const walletCheck = await query(
    `SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2`,
    [walletId, userId]
  );
  if (walletCheck.rows.length === 0) {
    throw ApiError.forbidden('You do not have access to this wallet.');
  }

  const r = await query(
    `INSERT INTO recurring_rules
       (user_id, wallet_id, amount, type, category_code, note, frequency, next_occurrence, is_active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::date, $9)
     RETURNING *`,
    [userId, walletId, amount, type, categoryCode, note, frequency, nextOccurrence, isActive]
  );
  return row(r.rows[0]);
}

async function update(userId, id, payload) {
  const fields = [];
  const values = [];
  let i = 1;
  const map = {
    walletId: 'wallet_id',
    amount: 'amount',
    type: 'type',
    categoryCode: 'category_code',
    note: 'note',
    frequency: 'frequency',
    nextOccurrence: 'next_occurrence',
    isActive: 'is_active',
  };

  // If walletId is updated, verify user has access
  if (payload.walletId) {
    const walletCheck = await query(
      `SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2`,
      [payload.walletId, userId]
    );
    if (walletCheck.rows.length === 0) {
      throw ApiError.forbidden('You do not have access to this wallet.');
    }
  }

  for (const [k, col] of Object.entries(map)) {
    if (payload[k] !== undefined) {
      if (k === 'nextOccurrence') {
        fields.push(`${col} = $${i++}::date`);
      } else {
        fields.push(`${col} = $${i++}`);
      }
      values.push(payload[k]);
    }
  }

  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  fields.push(`updated_at = NOW()`);
  values.push(id, userId);

  const r = await query(
    `UPDATE recurring_rules SET ${fields.join(', ')} WHERE id = $${i++} AND user_id = $${i} RETURNING *`,
    values
  );

  if (r.rowCount === 0) throw ApiError.notFound('Recurring rule not found.');
  return row(r.rows[0]);
}

async function remove(userId, id) {
  const r = await query(
    `DELETE FROM recurring_rules WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Recurring rule not found.');
}

module.exports = { list, create, update, remove };
