'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

function row(r) {
  return {
    id: r.id,
    userId: r.user_id,
    walletId: r.wallet_id,
    categoryCode: r.category_code,
    period: r.period,
    amountLimit: Number(r.amount_limit),
    startDate: r.start_date,
    endDate: r.end_date,
    isActive: r.is_active,
    createdAt: r.created_at,
  };
}

async function list(userId) {
  const r = await query(
    `SELECT * FROM budgets WHERE user_id = $1 AND is_active = TRUE ORDER BY created_at DESC`,
    [userId]
  );
  return r.rows.map(row);
}

async function create(userId, payload) {
  const walletId = payload.walletId || null;
  const categoryCode = payload.categoryCode || null;
  const period = payload.period;

  // Check if an active budget already exists with the same category and wallet
  const existing = await query(
    `SELECT id FROM budgets
     WHERE user_id = $1
       AND (category_code = $2 OR (category_code IS NULL AND $2 IS NULL))
       AND (wallet_id = $3 OR (wallet_id IS NULL AND $3 IS NULL))
       AND period = $4
       AND is_active = TRUE`,
    [userId, categoryCode, walletId, period]
  );

  if (existing.rows.length > 0) {
    const budgetId = existing.rows[0].id;
    // Update the amount of the existing budget
    const r = await query(
      `UPDATE budgets
       SET amount_limit = $1, start_date = $2::date, end_date = $3::date, updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [payload.amountLimit, payload.startDate, payload.endDate || null, budgetId]
    );
    return row(r.rows[0]);
  }

  const r = await query(
    `INSERT INTO budgets
       (user_id, wallet_id, category_code, period, amount_limit, start_date, end_date)
     VALUES ($1, $2, $3, $4, $5, $6::date, $7::date)
     RETURNING *`,
    [
      userId,
      walletId,
      categoryCode,
      period,
      payload.amountLimit,
      payload.startDate,
      payload.endDate || null,
    ]
  );
  return row(r.rows[0]);
}

async function update(userId, id, payload) {
  const fields = [];
  const values = [];
  let i = 1;
  const map = {
    walletId: 'wallet_id',
    categoryCode: 'category_code',
    period: 'period',
    amountLimit: 'amount_limit',
    startDate: 'start_date',
    endDate: 'end_date',
  };
  for (const [k, col] of Object.entries(map)) {
    if (payload[k] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(payload[k]);
    }
  }
  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  fields.push(`updated_at = NOW()`);
  values.push(id, userId);
  const r = await query(
    `UPDATE budgets SET ${fields.join(', ')} WHERE id = $${i++} AND user_id = $${i} RETURNING *`,
    values
  );
  if (r.rowCount === 0) throw ApiError.notFound('Budget not found.');
  return row(r.rows[0]);
}

async function remove(userId, id) {
  const r = await query(
    `UPDATE budgets SET is_active = FALSE WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Budget not found.');
}

/**
 * For each active budget, compute spent + remain in its current period.
 */
async function summary(userId) {
  const budgets = await list(userId);
  if (budgets.length === 0) return [];

  const enriched = [];
  for (const b of budgets) {
    const params = [userId, b.startDate];
    let where = `t.is_deleted = FALSE AND t.type = 'expense'
                 AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
                 AND t.occurred_at >= $2::timestamptz`;
    if (b.endDate) {
      params.push(b.endDate);
      where += ` AND t.occurred_at <= $${params.length}::timestamptz`;
    }
    if (b.walletId) {
      params.push(b.walletId);
      where += ` AND t.wallet_id = $${params.length}`;
    }
    if (b.categoryCode) {
      params.push(b.categoryCode);
      where += ` AND t.category_code = $${params.length}`;
    }
    const r = await query(
      `SELECT COALESCE(SUM(amount), 0)::numeric AS spent FROM transactions t WHERE ${where}`,
      params
    );
    const spent = Number(r.rows[0].spent);
    enriched.push({
      ...b,
      spent,
      remain: Math.max(0, b.amountLimit - spent),
      usagePct: b.amountLimit > 0 ? Math.round((spent / b.amountLimit) * 1000) / 10 : null,
      isOver: spent > b.amountLimit,
    });
  }
  return enriched;
}

module.exports = { list, create, update, remove, summary };
