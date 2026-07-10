'use strict';

const { query } = require('../../config/db');

async function overview(walletId, userId) {
  // Verifies user is member
  const memberCheck = await query(
    'SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2',
    [walletId, userId]
  );
  if (memberCheck.rowCount === 0) {
    throw new Error('Not authorized to access this wallet');
  }

  // Get total income (quỹ đóng vào) and total expense (đã chi)
  const r = await query(`
    SELECT
      COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS total_income,
      COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')), 0) AS total_expense
    FROM transactions
    WHERE wallet_id = $1 AND is_deleted = FALSE
  `, [walletId]);

  const totalIncome = Number(r.rows[0].total_income || 0);
  const totalExpense = Number(r.rows[0].total_expense || 0);
  
  return {
    totalFund: totalIncome,
    totalSpent: totalExpense,
    remaining: totalIncome - totalExpense
  };
}

async function categories(walletId, userId) {
  // Verifies user is member
  const memberCheck = await query(
    'SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2',
    [walletId, userId]
  );
  if (memberCheck.rowCount === 0) {
    throw new Error('Not authorized to access this wallet');
  }

  const r = await query(`
    SELECT 
      CASE WHEN category_code IS NULL OR LOWER(category_code) IN ('other', 'others') THEN 'Other' ELSE category_code END AS category_code,
      SUM(amount)::numeric AS total,
      COUNT(*)::int AS count
    FROM transactions
    WHERE wallet_id = $1 AND is_deleted = FALSE AND type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')
    GROUP BY 1
    ORDER BY total DESC
  `, [walletId]);

  const total = r.rows.reduce((s, row) => s + Number(row.total), 0);
  return r.rows.map(row => ({
    categoryCode: row.category_code,
    total: Number(row.total),
    amount: Number(row.total),
    count: row.count,
    percent: total > 0 ? Math.round((Number(row.total) / total) * 100) : 0,
  }));
}

async function settlement(walletId, userId) {
  // Verifies user is member
  const memberCheck = await query(
    'SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2',
    [walletId, userId]
  );
  if (memberCheck.rowCount === 0) {
    throw new Error('Not authorized to access this wallet');
  }

  // Lấy danh sách thành viên trong nhóm
  const membersQuery = await query(`
    SELECT u.id, u.username, u.email
    FROM wallet_members wm
    JOIN users u ON wm.user_id = u.id
    WHERE wm.wallet_id = $1
  `, [walletId]);

  // Lấy công nợ (debts) chưa thanh toán
  const debtsQuery = await query(`
    SELECT d.id, d.debtor_id, d.creditor_id, d.amount, d.status
    FROM debts d
    WHERE d.wallet_id = $1 AND d.status = 'unpaid'
  `, [walletId]);

  return {
    members: membersQuery.rows.map(r => ({
      id: r.id,
      name: r.username,
      email: r.email
    })),
    debts: debtsQuery.rows.map(r => ({
      id: r.id,
      debtorId: r.debtor_id,
      creditorId: r.creditor_id,
      amount: Number(r.amount),
      status: r.status
    }))
  };
}

async function timeline(walletId, userId) {
  // Verifies user is member
  const memberCheck = await query(
    'SELECT 1 FROM wallet_members WHERE wallet_id = $1 AND user_id = $2',
    [walletId, userId]
  );
  if (memberCheck.rowCount === 0) {
    throw new Error('Not authorized to access this wallet');
  }

  const r = await query(`
    SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
           SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving'))::numeric AS expense,
           SUM(amount) FILTER (WHERE type = 'income')::numeric  AS income
    FROM transactions 
    WHERE wallet_id = $1 AND is_deleted = FALSE
    GROUP BY day 
    ORDER BY day ASC
  `, [walletId]);

  return r.rows.map(row => ({
    day: row.day,
    expense: Number(row.expense || 0),
    income: Number(row.income || 0),
  }));
}

module.exports = {
  overview,
  categories,
  settlement,
  timeline
};
