'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function list(userId) {
  const r = await query(
    `SELECT * FROM goals WHERE user_id = $1 AND status != 'cancelled' ORDER BY created_at DESC`,
    [userId]
  );
  return r.rows;
}

async function getById(userId, goalId) {
  const r = await query(
    'SELECT * FROM goals WHERE id = $1 AND user_id = $2',
    [goalId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Goal not found.');
  return r.rows[0];
}

async function create(userId, payload) {
  const r = await query(
    `INSERT INTO goals (user_id, wallet_id, name, target_amount, emoji, deadline)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [
      userId,
      payload.walletId || null,
      payload.name,
      payload.targetAmount,
      payload.emoji || null,
      payload.deadline || null,
    ]
  );
  return r.rows[0];
}

async function update(userId, goalId, payload) {
  const existing = await getById(userId, goalId);
  const fields = [];
  const values = [goalId, userId];
  let idx = 3;

  for (const [key, col] of [
    ['name', 'name'],
    ['targetAmount', 'target_amount'],
    ['emoji', 'emoji'],
    ['deadline', 'deadline'],
    ['walletId', 'wallet_id'],
  ]) {
    if (payload[key] !== undefined) {
      fields.push(`${col} = $${idx++}`);
      values.push(payload[key]);
    }
  }

  if (fields.length === 0) return existing;

  fields.push('updated_at = NOW()');
  const r = await query(
    `UPDATE goals SET ${fields.join(', ')} WHERE id = $1 AND user_id = $2 RETURNING *`,
    values
  );
  return r.rows[0];
}

async function remove(userId, goalId) {
  const r = await query(
    `UPDATE goals SET status = 'cancelled', updated_at = NOW() WHERE id = $1 AND user_id = $2 RETURNING id`,
    [goalId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Goal not found.');
}

async function contribute(userId, goalId, amount) {
  const goal = await getById(userId, goalId);
  const newAmount = parseFloat(goal.current_amount) + amount;
  const status = newAmount >= parseFloat(goal.target_amount) ? 'completed' : 'active';

  const r = await query(
    `UPDATE goals SET current_amount = $3, status = $4, updated_at = NOW()
     WHERE id = $1 AND user_id = $2 RETURNING *`,
    [goalId, userId, newAmount, status]
  );
  return r.rows[0];
}

module.exports = { list, getById, create, update, remove, contribute };
