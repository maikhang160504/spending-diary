'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const crypto = require('crypto');

async function list(userId, type) {
  let whereType = '';
  if (type === 'challenge') {
    whereType = " AND g.type LIKE 'challenge%'";
  } else if (type === 'personal' || type === 'savings') {
    whereType = " AND (g.type IS NULL OR g.type NOT LIKE 'challenge%')";
  }

  const r = await query(
    `SELECT DISTINCT g.*, w.name AS wallet_name, w.type AS wallet_type FROM goals g
     LEFT JOIN wallets w ON w.id = g.wallet_id
     LEFT JOIN wallet_members wm ON wm.wallet_id = g.wallet_id AND wm.user_id = $1
     LEFT JOIN goal_members gm ON gm.goal_id = g.id AND gm.user_id = $1
     WHERE (g.user_id = $1 OR wm.user_id IS NOT NULL OR gm.user_id IS NOT NULL)
       AND g.status != 'cancelled'${whereType}
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

  // Fetch all contributors for leaderboard
  const allContribs = await query(
    `SELECT u.id AS "userId", u.username, u.avatar_url AS "avatarUrl", COALESCE(SUM(gc.amount), 0)::numeric AS total
     FROM goal_contributions gc
     JOIN users u ON u.id = gc.user_id
     WHERE gc.goal_id = $1
     GROUP BY u.id, u.username, u.avatar_url
     ORDER BY total DESC`,
    [goalId]
  );

  const targetAmount = Number(goal.target_amount) || 1;
  const contributorLeaderboard = allContribs.rows.map((t, idx) => {
    const total = Number(t.total);
    return {
      rank: idx + 1,
      userId: t.userId,
      username: t.username,
      avatarUrl: t.avatarUrl,
      totalContributed: total,
      percentage: Math.min(100, Math.round((total / targetAmount) * 100)),
    };
  });

  // Fetch challenge progress leaderboard from goal_members
  const challengeProgressRes = await query(
    `SELECT gm.user_id AS "userId", u.username, u.avatar_url AS "avatarUrl", gm.role,
            COALESCE(gm.current_amount, 0)::numeric AS "currentAmount", gm.status, gm.completed_at AS "completedAt"
     FROM goal_members gm
     JOIN users u ON u.id = gm.user_id
     WHERE gm.goal_id = $1
     ORDER BY COALESCE(gm.current_amount, 0) DESC, gm.completed_at ASC NULLS LAST`,
    [goalId]
  );

  const progressLeaderboard = challengeProgressRes.rows.map((row, idx) => {
    const curr = Number(row.currentAmount);
    const pct = Math.min(100, Math.round((curr / targetAmount) * 100));
    return {
      rank: idx + 1,
      userId: row.userId,
      username: row.username,
      avatarUrl: row.avatarUrl,
      role: row.role,
      currentAmount: curr,
      targetAmount,
      percentage: pct,
      status: row.status || (curr >= targetAmount ? 'completed' : 'active'),
      completedAt: row.completedAt,
    };
  });

  const myProgress = progressLeaderboard.find((m) => String(m.userId) === String(userId)) || {
    userId,
    currentAmount: 0,
    targetAmount,
    percentage: 0,
    status: 'active',
  };

  return {
    ...goal,
    inviteCode: goal.invite_code,
    target_amount: targetAmount,
    current_amount: Number(goal.current_amount),
    walletName: goal.wallet_name,
    walletType: goal.wallet_type,
    walletMembers,
    goalMembers: gMems.rows,
    contributorLeaderboard,
    progressLeaderboard,
    myProgress,
    contributions: contribs.rows.map((c) => ({
      id: c.id,
      amount: Number(c.amount),
      createdAt: c.created_at,
      username: c.username,
      avatarUrl: c.avatarUrl,
    })),
    topContributors: contributorLeaderboard.slice(0, 3).map((t) => ({
      username: t.username,
      avatarUrl: t.avatarUrl,
      total: t.totalContributed,
    })),
  };
}

async function create(userId, payload) {
  const type = payload.type || 'personal';
  const isGroup = payload.isGroup === true || type === 'saving_group' || type === 'challenge_group';
  
  // Check Premium limits
  const userRes = await query('SELECT is_premium FROM users WHERE id = $1', [userId]);
  const isPremium = userRes.rows[0]?.is_premium;

  if (!isPremium) {
    const isChallenge = type.startsWith('challenge');
    const q = isChallenge 
      ? `SELECT COUNT(*) FROM goal_members gm JOIN goals g ON g.id = gm.goal_id WHERE gm.user_id = $1 AND g.type LIKE 'challenge%' AND g.status != 'cancelled'`
      : `SELECT COUNT(*) FROM goal_members gm JOIN goals g ON g.id = gm.goal_id WHERE gm.user_id = $1 AND (g.type IS NULL OR g.type NOT LIKE 'challenge%') AND g.status != 'cancelled'`;
      
    const countRes = await query(q, [userId]);
    if (parseInt(countRes.rows[0].count) >= 5) {
      throw ApiError.forbidden('PREMIUM_REQUIRED_GOAL_LIMIT');
    }
  }

  const inviteCode = isGroup ? crypto.randomBytes(3).toString('hex').toUpperCase() : null;
  const r = await query(
    `INSERT INTO goals (user_id, wallet_id, name, target_amount, emoji, deadline, type, invite_code)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      userId,
      payload.walletId || null,
      payload.name,
      payload.targetAmount,
      payload.emoji || null,
      payload.deadline || null,
      type,
      inviteCode,
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

async function leaveGoal(userId, goalId) {
  const goal = await getById(userId, goalId);
  if (goal.user_id === userId) {
    throw ApiError.badRequest('Chủ mục tiêu không thể rời. Hãy xóa mục tiêu.');
  }
  await query(
    `DELETE FROM goal_members WHERE goal_id = $1 AND user_id = $2`,
    [goalId, userId]
  );
}

const transactionService = require('../transactions/transactions.service');

async function contribute(userId, goalId, amount) {
  const goal = await getById(userId, goalId);

  await query(
    `INSERT INTO goal_contributions (goal_id, user_id, amount)
     VALUES ($1, $2, $3)`,
    [goalId, userId, amount]
  );

  let myCurrentAmount = 0;
  if (goal.type === 'challenge') {
    const memRes = await query(
      `INSERT INTO goal_members (goal_id, user_id, role, current_amount)
       VALUES ($1, $2, 'member', $3)
       ON CONFLICT (goal_id, user_id)
       DO UPDATE SET current_amount = goal_members.current_amount + EXCLUDED.current_amount,
                     status = CASE WHEN goal_members.current_amount + EXCLUDED.current_amount >= $4 THEN 'completed' ELSE goal_members.status END,
                     completed_at = CASE WHEN goal_members.current_amount + EXCLUDED.current_amount >= $4 AND goal_members.completed_at IS NULL THEN NOW() ELSE goal_members.completed_at END
       RETURNING current_amount`,
      [goalId, userId, amount, Number(goal.target_amount)]
    );
    myCurrentAmount = Number(memRes.rows[0]?.current_amount || amount);
  }

  const r = await query(
    `UPDATE goals
     SET current_amount = current_amount + $2,
         status = CASE WHEN current_amount + $2 >= target_amount THEN 'completed' ELSE status END,
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [goalId, amount]
  );

  const updatedGoal = r.rows[0];
  return {
    ...updatedGoal,
    myCurrentAmount: goal.type === 'challenge' ? myCurrentAmount : Number(updatedGoal.current_amount),
  };
}

async function generateInviteCode(userId, goalId) {
  const goal = await getById(userId, goalId);
  const existingCode = goal.invite_code || goal.inviteCode;
  if (existingCode) return { inviteCode: existingCode };

  const inviteCode = crypto.randomBytes(3).toString('hex').toUpperCase();
  await query(
    `UPDATE goals SET invite_code = $1 WHERE id = $2`,
    [inviteCode, goalId]
  );
  return { inviteCode };
}

async function joinByInviteCode(userId, inviteCode) {
  const r = await query(
    `SELECT id, type FROM goals WHERE invite_code = $1 AND status != 'cancelled'`,
    [inviteCode.trim().toUpperCase()]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Mã mời không hợp lệ hoặc mục tiêu đã kết thúc.');
  const goalId = r.rows[0].id;
  const type = r.rows[0].type || '';

  // Check Premium limits
  const userRes = await query('SELECT is_premium FROM users WHERE id = $1', [userId]);
  const isPremium = userRes.rows[0]?.is_premium;

  if (!isPremium) {
    const isChallenge = type.startsWith('challenge');
    const q = isChallenge 
      ? `SELECT COUNT(*) FROM goal_members gm JOIN goals g ON g.id = gm.goal_id WHERE gm.user_id = $1 AND g.type LIKE 'challenge%' AND g.status != 'cancelled'`
      : `SELECT COUNT(*) FROM goal_members gm JOIN goals g ON g.id = gm.goal_id WHERE gm.user_id = $1 AND (g.type IS NULL OR g.type NOT LIKE 'challenge%') AND g.status != 'cancelled'`;
      
    const countRes = await query(q, [userId]);
    if (parseInt(countRes.rows[0].count) >= 5) {
      throw ApiError.forbidden('PREMIUM_REQUIRED_GOAL_LIMIT');
    }
  }

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
  leaveGoal,
  contribute,
  generateInviteCode,
  joinByInviteCode,
};
