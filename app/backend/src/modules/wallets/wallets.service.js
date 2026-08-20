'use strict';

const crypto = require('crypto');
const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const fcmService = require('../fcm/fcm.service');
const { dispatchUserNotification } = require('../../services/notificationDispatch');

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
    unseenCount: Number(r.unseen_count || 0),
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
    `SELECT w.id, w.owner_id, w.name, w.type, w.currency, w.icon, w.color, w.is_archived, w.created_at, w.updated_at,
            COALESCE(
              (SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE -t.amount END)
               FROM transactions t
               WHERE t.wallet_id = w.id AND t.is_deleted = FALSE), 0
            ) AS balance,
            wm.role AS member_role,
            (
              SELECT COUNT(*)::int FROM transactions t
              WHERE t.wallet_id = w.id
                AND t.occurred_at > wm.last_seen_at
                AND t.creator_id != $1
                AND t.is_deleted = FALSE
            ) AS unseen_count
     FROM wallets w
     JOIN wallet_members wm ON wm.wallet_id = w.id
     WHERE wm.user_id = $1 AND w.is_archived = FALSE
     ORDER BY w.created_at DESC`,
    [userId]
  );
  return r.rows.map(row);
}

async function getById(userId, id) {
  // Update last_seen_at for the user in this wallet to reset notifications
  await query(
    `UPDATE wallet_members SET last_seen_at = NOW() WHERE wallet_id = $1 AND user_id = $2`,
    [id, userId]
  );

  const r = await query(
    `SELECT w.id, w.owner_id, w.name, w.type, w.currency, w.icon, w.color, w.is_archived, w.created_at, w.updated_at,
            COALESCE(
              (SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE -t.amount END)
               FROM transactions t
               WHERE t.wallet_id = w.id AND t.is_deleted = FALSE), 0
            ) AS balance,
            wm.role AS member_role, 0 AS unseen_count
     FROM wallets w
     JOIN wallet_members wm ON wm.wallet_id = w.id
     WHERE w.id = $1 AND wm.user_id = $2`,
    [id, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Wallet not found.');
  return row(r.rows[0]);
}

async function create(userId, payload) {
  // Check Premium limits
  const userRes = await query('SELECT is_premium FROM users WHERE id = $1', [userId]);
  const isPremium = userRes.rows[0]?.is_premium;

  if (!isPremium) {
    if (payload.type === 'personal') {
      const pCount = await query(`SELECT COUNT(*) FROM wallets WHERE owner_id = $1 AND type = 'personal' AND is_archived = FALSE`, [userId]);
      if (parseInt(pCount.rows[0].count) >= 2) throw ApiError.forbidden('PREMIUM_REQUIRED_WALLET_LIMIT');
    } else if (payload.type === 'group') {
      const gCount = await query(`SELECT COUNT(*) FROM wallet_members wm JOIN wallets w ON w.id = wm.wallet_id WHERE wm.user_id = $1 AND w.type = 'group' AND w.is_archived = FALSE`, [userId]);
      if (parseInt(gCount.rows[0].count) >= 1) throw ApiError.forbidden('PREMIUM_REQUIRED_WALLET_LIMIT');
    }
  }

  return withTransaction(async (client) => {
    const balance = Number(payload.balance) || 0;
    const w = await client.query(
      `INSERT INTO wallets (owner_id, name, type, currency, icon, color, balance)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [userId, payload.name, payload.type, payload.currency, payload.icon, payload.color, balance]
    );
    await client.query(
      `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')`,
      [w.rows[0].id, userId]
    );

    if (balance > 0) {
      await client.query(
        `INSERT INTO transactions
           (wallet_id, creator_id, amount, type, category_code, source, note, occurred_at)
         VALUES ($1, $2, $3, 'income', 'Other', 'manual', 'Số dư ban đầu', NOW())`,
        [w.rows[0].id, userId, balance]
      );
    }

    return row({ ...w.rows[0], member_role: 'owner', balance });
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

async function inviteMember(userId, walletId, payload) {
  await assertMember(walletId, userId, ['owner']);
  const u = await query('SELECT id FROM users WHERE email = $1', [payload.email]);
  if (u.rowCount === 0) throw ApiError.notFound('User with that email not found.');
  await query(
    `INSERT INTO wallet_members (wallet_id, user_id, role)
     VALUES ($1, $2, $3)
     ON CONFLICT (wallet_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
    [walletId, u.rows[0].id, payload.role || 'member']
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

async function leaveWallet(userId, walletId) {
  const role = await assertMember(walletId, userId);
  if (role === 'owner') {
    throw ApiError.badRequest('Chủ ví không thể tự rời. Hãy chuyển quyền sở hữu hoặc xóa ví.');
  }
  await query(
    `DELETE FROM wallet_members WHERE wallet_id = $1 AND user_id = $2`,
    [walletId, userId]
  );
}

async function generateInviteCode(userId, walletId) {
  await assertMember(walletId, userId, ['owner']);

  // Check if there is an existing active invite code for this wallet
  const existing = await query(
    `SELECT code FROM wallet_invite_codes 
     WHERE wallet_id = $1 AND expires_at > NOW() AND use_count < max_uses 
     LIMIT 1`,
    [walletId]
  );
  if (existing.rowCount > 0) {
    return { code: existing.rows[0].code };
  }

  let code;
  let isUnique = false;
  let retries = 0;
  while (!isUnique && retries < 10) {
    code = crypto.randomBytes(3).toString('hex').toUpperCase();
    const check = await query('SELECT 1 FROM wallet_invite_codes WHERE code = $1', [code]);
    if (check.rowCount === 0) {
      isUnique = true;
    }
    retries++;
  }

  const r = await query(
    `INSERT INTO wallet_invite_codes (wallet_id, code, created_by)
     VALUES ($1, $2, $3)
     RETURNING code`,
    [walletId, code, userId]
  );
  return { code: r.rows[0].code };
}

async function joinByInviteCode(userId, code) {
  const codeUpper = code.trim().toUpperCase();
  const r = await query(
    `SELECT * FROM wallet_invite_codes 
     WHERE code = $1 AND expires_at > NOW() AND use_count < max_uses`,
    [codeUpper]
  );
  if (r.rowCount === 0) {
    throw ApiError.badRequest('Mã mời không hợp lệ hoặc đã hết hạn.');
  }
  const invite = r.rows[0];

  // Check Premium limits
  const userRes = await query('SELECT is_premium FROM users WHERE id = $1', [userId]);
  const isPremium = userRes.rows[0]?.is_premium;

  if (!isPremium) {
    // Joining a wallet implies it's a group wallet (since you invite to group wallets usually, but even if personal, the prompt restricts to 1 group wallet total or 2 personal. We'll count all group wallets for simplicity)
    const gCount = await query(`SELECT COUNT(*) FROM wallet_members wm JOIN wallets w ON w.id = wm.wallet_id WHERE wm.user_id = $1 AND w.type = 'group' AND w.is_archived = FALSE`, [userId]);
    if (parseInt(gCount.rows[0].count) >= 1) throw ApiError.forbidden('PREMIUM_REQUIRED_WALLET_LIMIT');
  }

  // Add user as member to the wallet
  await query(
    `INSERT INTO wallet_members (wallet_id, user_id, role)
     VALUES ($1, $2, 'member')
     ON CONFLICT (wallet_id, user_id) DO NOTHING`,
    [invite.wallet_id, userId]
  );

  // Increment use_count
  await query(
    `UPDATE wallet_invite_codes SET use_count = use_count + 1 WHERE id = $1`,
    [invite.id]
  );

  // Return the wallet
  const walletRes = await query(
    `SELECT w.*, wm.role AS member_role
     FROM wallets w
     JOIN wallet_members wm ON wm.wallet_id = w.id
     WHERE w.id = $1 AND wm.user_id = $2`,
    [invite.wallet_id, userId]
  );

  // Send notification to other members & owner
  try {
    const userRes = await query('SELECT username FROM users WHERE id = $1', [userId]);
    const finalUserName = userRes.rows[0]?.username || 'Thành viên mới';
    const w = walletRes.rows[0];

    const otherMembers = await query(
      `SELECT DISTINCT user_id FROM (
         SELECT user_id FROM wallet_members WHERE wallet_id = $1
         UNION
         SELECT owner_id AS user_id FROM wallets WHERE id = $1
       ) sub
       WHERE user_id != $2 AND user_id IS NOT NULL`,
      [invite.wallet_id, userId]
    );
    console.log(`[WalletJoin] Found ${otherMembers.rowCount} members/owner to notify in wallet ${invite.wallet_id}`);
    for (const row of otherMembers.rows) {
      console.log(`[WalletJoin] Dispatching notification to user ${row.user_id}`);
      await dispatchUserNotification(row.user_id, {
        type: 'WALLET_JOIN',
        payload: {
          title: 'Thành viên mới trong ví chung 👥',
          message: `${finalUserName} đã tham gia ví chung "${w.name}".`,
          deepLink: `/app/wallets/${invite.wallet_id}`,
        }
      }).catch((e) => console.error('Join wallet notification error:', e));
    }
  } catch (e) {
    console.error('Error sending join wallet notification:', e);
  }

  return row(walletRes.rows[0]);
}

async function transferBetweenWallets(userId, fromWalletId, toWalletId, amount) {
  if (amount <= 0) throw ApiError.badRequest('Số tiền chuyển phải lớn hơn 0.');

  await assertMember(fromWalletId, userId, ['owner', 'member']);
  await assertMember(toWalletId, userId, ['owner', 'member']);

  return withTransaction(async (client) => {
    const fromWalletRes = await client.query('SELECT balance, name FROM wallets WHERE id = $1', [fromWalletId]);
    if (fromWalletRes.rowCount === 0) throw ApiError.notFound('Ví chuyển không tồn tại.');
    const fromWallet = fromWalletRes.rows[0];
    const fromBalance = Number(fromWallet.balance);
    if (fromBalance < amount) {
      throw ApiError.badRequest(`Số dư ví "${fromWallet.name}" không đủ để chuyển.`);
    }

    const fromNote = `Chuyển tiền sang ví khác`;
    await client.query(
      `INSERT INTO transactions
         (wallet_id, creator_id, amount, type, source, note, occurred_at)
       VALUES ($1, $2, $3, 'expense', 'manual', $4, NOW())`,
      [fromWalletId, userId, amount, fromNote]
    );

    const toNote = `Nhận tiền từ ví khác`;
    await client.query(
      `INSERT INTO transactions
         (wallet_id, creator_id, amount, type, source, note, occurred_at)
       VALUES ($1, $2, $3, 'income', 'manual', $4, NOW())`,
      [toWalletId, userId, amount, toNote]
    );

    await client.query('UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE id = $2', [amount, fromWalletId]);
    await client.query('UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE id = $2', [amount, toWalletId]);

    return { success: true };
  });
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
  inviteMember,
  removeMember,
  leaveWallet,
  generateInviteCode,
  joinByInviteCode,
  transferBetweenWallets,
};
