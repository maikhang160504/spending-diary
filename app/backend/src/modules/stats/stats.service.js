'use strict';

const { query } = require('../../config/db');

function parseRange(from, to) {
  const now = new Date();
  const start = from
    ? new Date(from)
    : new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = to ? new Date(to) : now;
  return { start: start.toISOString(), end: end.toISOString() };
}

async function dashboard(userId, { from, to } = {}) {
  const { start, end } = parseRange(from, to);
  const params = [userId, start, end];
  const baseWhere = `
    t.is_deleted = FALSE
    AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
    AND t.occurred_at BETWEEN $2 AND $3`;

  const totalQ = query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS total_expense,
       COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0)  AS total_income,
       COUNT(*) FILTER (WHERE type = 'expense') AS count_expense,
       COUNT(*) FILTER (WHERE type = 'income') AS count_income
     FROM transactions t WHERE ${baseWhere}`,
    params
  );

  const byCategoryQ = query(
    `SELECT COALESCE(category_code, 'Others') AS category_code,
            SUM(amount)::numeric AS total,
            COUNT(*)::int AS count
     FROM transactions t WHERE ${baseWhere} AND type = 'expense'
     GROUP BY COALESCE(category_code, 'Others')
     ORDER BY total DESC`,
    params
  );

  const byDayQ = query(
    `SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
            SUM(amount) FILTER (WHERE type = 'expense')::numeric AS expense,
            SUM(amount) FILTER (WHERE type = 'income')::numeric  AS income
     FROM transactions t WHERE ${baseWhere}
     GROUP BY day ORDER BY day`,
    params
  );

  const topMerchantsQ = query(
    `SELECT note, SUM(amount)::numeric AS total, COUNT(*)::int AS count
     FROM transactions t WHERE ${baseWhere} AND type = 'expense' AND note IS NOT NULL
     GROUP BY note ORDER BY total DESC LIMIT 5`,
    params
  );

  const [total, byCategory, byDay, topMerchants] = await Promise.all([
    totalQ,
    byCategoryQ,
    byDayQ,
    topMerchantsQ,
  ]);

  return {
    range: { from: start, to: end },
    totals: {
      expense: Number(total.rows[0].total_expense),
      income: Number(total.rows[0].total_income),
      net:
        Number(total.rows[0].total_income) - Number(total.rows[0].total_expense),
      countExpense: total.rows[0].count_expense,
      countIncome: total.rows[0].count_income,
    },
    byCategory: byCategory.rows.map((r) => ({
      categoryCode: r.category_code,
      total: Number(r.total),
      count: r.count,
    })),
    byDay: byDay.rows.map((r) => ({
      day: r.day,
      expense: Number(r.expense || 0),
      income: Number(r.income || 0),
    })),
    topNotes: topMerchants.rows.map((r) => ({
      note: r.note,
      total: Number(r.total),
      count: r.count,
    })),
  };
}

async function byMonth(userId, { year } = {}) {
  const y = Number.parseInt(year, 10) || new Date().getUTCFullYear();
  const start = `${y}-01-01T00:00:00Z`;
  const end = `${y + 1}-01-01T00:00:00Z`;
  const r = await query(
    `SELECT to_char(date_trunc('month', occurred_at), 'YYYY-MM') AS month,
            SUM(amount) FILTER (WHERE type = 'expense')::numeric AS expense,
            SUM(amount) FILTER (WHERE type = 'income')::numeric  AS income
     FROM transactions t
     WHERE t.is_deleted = FALSE
       AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
       AND t.occurred_at >= $2 AND t.occurred_at < $3
     GROUP BY month ORDER BY month`,
    [userId, start, end]
  );
  return r.rows.map((row) => ({
    month: row.month,
    expense: Number(row.expense || 0),
    income: Number(row.income || 0),
  }));
}

module.exports = { dashboard, byMonth };
