'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function list(userId, type) {
  const r = await query(
    `SELECT DISTINCT g.* FROM goals g
     LEFT JOIN wallet_members wm ON wm.wallet_id = g.wallet_id AND wm.user_id = $1
     LEFT JOIN goal_members gm ON gm.goal_id = g.id AND gm.user_id = $1
     WHERE (g.user_id = $1 OR wm.user_id IS NOT NULL OR gm.user_id IS NOT NULL) AND g.status != 'cancelled'
     ORDER BY g.created_at DESC`,
    [userId]
  );
  return r.rows;
}

async function getById(userId, goalId) {
  const r = await query(
    `SELECT g.*, w.name AS wallet_name, w.type AS wallet_type FROM goals g
     LEFT JOIN wallets w ON w.id = g.wallet_id
     LEFT JOIN wallet_members wm ON wm.wallet_id = g.wallet_id AND wm.user_id = $2
     LEFT JOIN goal_members gm ON gm.goal_id = g.id AND gm.user_id = $2
     WHERE g.id = $1 AND (g.user_id = $2 OR wm.user_id IS NOT NULL OR gm.user_id IS NOT NULL)`,
    [goalId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Goal not found.');
  const goal = r.rows[0];

  // Fetch wallet members if linked
  let walletMembers = [];
  if (goal.wallet_id) {
    const mems = await query(
      `SELECT wm.user_id AS id, u.username, u.avatar_url AS "avatarUrl", wm.role
       FROM wallet_members wm
       JOIN users u ON u.id = wm.user_id
       WHERE wm.wallet_id = $1`,
      [goal.wallet_id]
    );
    walletMembers = mems.rows;
  }

  // Fetch goal members
  const gMems = await query(
    `SELECT gm.user_id AS id, u.username, u.avatar_url AS "avatarUrl", gm.role
     FROM goal_members gm
     JOIN users u ON u.id = gm.user_id
     WHERE gm.goal_id = $1`,
    [goalId]
  );

  // Fetch contributions list
  const contribs = await query(
    `SELECT gc.id, gc.amount, gc.created_at, u.username, u.avatar_url AS "avatarUrl"
     FROM goal_contributions gc
     JOIN users u ON u.id = gc.user_id
     WHERE gc.goal_id = $1
     ORDER BY gc.created_at DESC`,
    [goalId]
  );

  // Fetch top 3 contributors
  const tops = await query(
    `SELECT u.username, u.avatar_url AS "avatarUrl", SUM(gc.amount)::numeric AS total
     FROM goal_contributions gc
     JOIN users u ON u.id = gc.user_id
     WHERE gc.goal_id = $1
     GROUP BY u.id, u.username, u.avatar_url
     ORDER BY total DESC
     LIMIT 3`,
    [goalId]
  );

  return {
    ...goal,
    inviteCode: goal.invite_code,
    target_amount: Number(goal.target_amount),
    current_amount: Number(goal.current_amount),
    walletName: goal.wallet_name,
    walletType: goal.wallet_type,
    walletMembers,
    goalMembers: gMems.rows,
    contributions: contribs.rows.map((c) => ({
      id: c.id,
      amount: Number(c.amount),
      createdAt: c.created_at,
      username: c.username,
      avatarUrl: c.avatarUrl,
    })),
    topContributors: tops.rows.map((t) => ({
      username: t.username,
      avatarUrl: t.avatarUrl,
      total: Number(t.total),
    })),
  };
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
  const goal = r.rows[0];
  await query(
    `INSERT INTO goal_members (goal_id, user_id, role)
     VALUES ($1, $2, 'owner')
     ON CONFLICT DO NOTHING`,
    [goal.id, userId]
  );
  return goal;
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

const transactionService = require('../transactions/transactions.service');

async function contribute(userId, goalId, amount) {
  const goal = await getById(userId, goalId);
  const newAmount = goal.current_amount + amount;
  const status = newAmount >= goal.target_amount ? 'completed' : 'active';

  await query(
    `INSERT INTO goal_contributions (goal_id, user_id, amount)
     VALUES ($1, $2, $3)`,
    [goalId, userId, amount]
  );

  const r = await query(
    `UPDATE goals SET current_amount = $2, status = $3, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [goalId, newAmount, status]
  );

  return r.rows[0];
}

const crypto = require('crypto');

async function generateInviteCode(userId, goalId) {
  const goal = await getById(userId, goalId);
  if (goal.inviteCode) return { inviteCode: goal.inviteCode };

  const inviteCode = crypto.randomBytes(3).toString('hex').toUpperCase();
  await query(
    `UPDATE goals SET invite_code = $1 WHERE id = $2`,
    [inviteCode, goalId]
  );
  return { inviteCode };
}

async function joinByInviteCode(userId, inviteCode) {
  const r = await query(
    `SELECT id FROM goals WHERE invite_code = $1 AND status != 'cancelled'`,
    [inviteCode.trim().toUpperCase()]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Mã mời không hợp lệ hoặc mục tiêu đã kết thúc.');
  const goalId = r.rows[0].id;

  await query(
    `INSERT INTO goal_members (goal_id, user_id, role)
     VALUES ($1, $2, 'member')
     ON CONFLICT DO NOTHING`,
    [goalId, userId]
  );

  return getById(userId, goalId);
}

module.exports = {
  list,
  getById,
  create,
  update,
  remove,
  contribute,
  generateInviteCode,
  joinByInviteCode,
};
