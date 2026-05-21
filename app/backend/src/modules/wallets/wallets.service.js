'use strict';

const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

function row(r) {
  return {
    id: r.id,
    name: r.name,
    type: r.type,
    currency: r.currency,
    balance: Number(r.balance),
    icon: r.icon,
    color: r.color,
    isArchived: r.is_archived,
    ownerId: r.owner_id,
    memberRole: r.member_role || null,
    createdAt: r.created_at,
  };
}

async function assertMember(walletId, userId, requiredRoles = ['owner', 'member', 'viewer']) {
  const r = await query(
    `SELECT role FROM wallet_members WHERE wallet_id = $1 AND user_id = $2`,
    [walletId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Wallet not found.');
  if (!requiredRoles.includes(r.rows[0].role)) {
    throw ApiError.forbidden('Wallet role does not allow this action.');
  }
  return r.rows[0].role;
}

async function list(userId) {
  const r = await query(
    `SELECT w.*, wm.role AS member_role
     FROM wallets w
     JOIN wallet_members wm ON wm.wallet_id = w.id
     WHERE wm.user_id = $1 AND w.is_archived = FALSE
     ORDER BY w.created_at DESC`,
    [userId]
  );
  return r.rows.map(row);
}

async function getById(userId, id) {
  const r = await query(
    `SELECT w.*, wm.role AS member_role
     FROM wallets w
     JOIN wallet_members wm ON wm.wallet_id = w.id
     WHERE w.id = $1 AND wm.user_id = $2`,
    [id, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Wallet not found.');
  return row(r.rows[0]);
}

async function create(userId, payload) {
  return withTransaction(async (client) => {
    const w = await client.query(
      `INSERT INTO wallets (owner_id, name, type, currency, icon, color)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, payload.name, payload.type, payload.currency, payload.icon, payload.color]
    );
    await client.query(
      `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')`,
      [w.rows[0].id, userId]
    );
    return row({ ...w.rows[0], member_role: 'owner' });
  });
}

async function update(userId, id, payload) {
  await assertMember(id, userId, ['owner']);
  const fields = [];
  const values = [];
  let i = 1;
  for (const k of ['name', 'type', 'currency', 'icon', 'color']) {
    if (payload[k] !== undefined) {
      fields.push(`${k} = $${i++}`);
      values.push(payload[k]);
    }
  }
  if (fields.length === 0) throw ApiError.badRequest('No fields to update.');
  fields.push(`updated_at = NOW()`);
  values.push(id);
  const r = await query(
    `UPDATE wallets SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
    values
  );
  return row({ ...r.rows[0], member_role: 'owner' });
}

async function archive(userId, id) {
  await assertMember(id, userId, ['owner']);
  await query(
    `UPDATE wallets SET is_archived = TRUE, updated_at = NOW() WHERE id = $1`,
    [id]
  );
}

async function listMembers(userId, walletId) {
  await assertMember(walletId, userId);
  const r = await query(
    `SELECT u.id, u.email, u.username, u.avatar_url, wm.role, wm.joined_at
     FROM wallet_members wm
     JOIN users u ON u.id = wm.user_id
     WHERE wm.wallet_id = $1
     ORDER BY wm.joined_at`,
    [walletId]
  );
  return r.rows.map((m) => ({
    id: m.id,
    email: m.email,
    username: m.username,
    avatarUrl: m.avatar_url,
    role: m.role,
    joinedAt: m.joined_at,
  }));
}

async function addMember(userId, walletId, payload) {
  await assertMember(walletId, userId, ['owner']);
  // Ensure target user exists
  const u = await query('SELECT id FROM users WHERE id = $1', [payload.userId]);
  if (u.rowCount === 0) throw ApiError.notFound('User to add not found.');
  await query(
    `INSERT INTO wallet_members (wallet_id, user_id, role)
     VALUES ($1, $2, $3)
     ON CONFLICT (wallet_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
    [walletId, payload.userId, payload.role]
  );
  return listMembers(userId, walletId);
}

async function removeMember(userId, walletId, memberId) {
  await assertMember(walletId, userId, ['owner']);
  if (memberId === userId) {
    throw ApiError.badRequest('Owner cannot remove themselves; transfer ownership first.');
  }
  const r = await query(
    `DELETE FROM wallet_members WHERE wallet_id = $1 AND user_id = $2 RETURNING wallet_id`,
    [walletId, memberId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Member not found.');
}

module.exports = {
  assertMember,
  list,
  getById,
  create,
  update,
  archive,
  listMembers,
  addMember,
  removeMember,
};
