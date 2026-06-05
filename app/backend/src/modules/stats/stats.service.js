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

function generateDateRange(startStr, endStr) {
  const dates = [];
  const start = new Date(startStr);
  const end = new Date(endStr);
  
  const current = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));
  const target = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));

  while (current <= target) {
    const yyyy = current.getUTCFullYear();
    const mm = String(current.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(current.getUTCDate()).padStart(2, '0');
    dates.push(`${yyyy}-${mm}-${dd}`);
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}

async function dashboard(userId, { from, to, walletId } = {}) {
  const { start, end } = parseRange(from, to);
  const params = [userId, start, end];
  
  let baseWhere;
  if (walletId) {
    params.push(walletId);
    baseWhere = `
      t.is_deleted = FALSE
      AND t.wallet_id = $4
      AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
      AND t.occurred_at BETWEEN $2 AND $3`;
  } else {
    baseWhere = `
      t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at BETWEEN $2 AND $3`;
  }

  const totalQ = query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')), 0) AS total_expense,
       COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0)  AS total_income,
       COUNT(*) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')) AS count_expense,
       COUNT(*) FILTER (WHERE type = 'income') AS count_income
     FROM transactions t WHERE ${baseWhere}`,
    params
  );

  const byCategoryQ = query(
    `SELECT COALESCE(category_code, 'Others') AS category_code,
            SUM(amount)::numeric AS total,
            COUNT(*)::int AS count
     FROM transactions t WHERE ${baseWhere} AND type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')
     GROUP BY COALESCE(category_code, 'Others')
     ORDER BY total DESC`,
    params
  );

  const byDayQ = query(
    `SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
            SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving'))::numeric AS expense,
            SUM(amount) FILTER (WHERE type = 'income')::numeric  AS income
     FROM transactions t WHERE ${baseWhere}
     GROUP BY day ORDER BY day`,
    params
  );

  const topMerchantsQ = query(
    `SELECT note, SUM(amount)::numeric AS total, COUNT(*)::int AS count
     FROM transactions t WHERE ${baseWhere} AND type = 'expense' AND (category_code IS NULL OR category_code != 'Saving') AND note IS NOT NULL
     GROUP BY note ORDER BY total DESC LIMIT 5`,
    params
  );

  const [total, byCategory, byDay, topMerchants] = await Promise.all([
    totalQ,
    byCategoryQ,
    byDayQ,
    topMerchantsQ,
  ]);

  const allDays = generateDateRange(start, end);
  const dayMap = new Map(byDay.rows.map((r) => [r.day, r]));
  for (const r of byDay.rows) {
    if (!dayMap.has(r.day)) {
      dayMap.set(r.day, r);
    }
  }
  const uniqueDays = Array.from(new Set([...allDays, ...dayMap.keys()])).sort();
  const formattedByDay = uniqueDays.map((dayStr) => {
    const row = dayMap.get(dayStr);
    return {
      day: dayStr,
      expense: row ? Number(row.expense || 0) : 0,
      income: row ? Number(row.income || 0) : 0,
    };
  });

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
    byDay: formattedByDay,
    topNotes: topMerchants.rows.map((r) => ({
      note: r.note,
      total: Number(r.total),
      count: r.count,
    })),
  };
}

async function byMonth(userId, { year, walletId } = {}) {
  const y = Number.parseInt(year, 10) || new Date().getUTCFullYear();
  const start = `${y}-01-01T00:00:00Z`;
  const end = `${y + 1}-01-01T00:00:00Z`;
  
  let baseWhere;
  const params = [userId, start, end];
  if (walletId) {
    params.push(walletId);
    baseWhere = `t.is_deleted = FALSE
      AND t.wallet_id = $4
      AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
      AND t.occurred_at >= $2 AND t.occurred_at < $3`;
  } else {
    baseWhere = `t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at >= $2 AND t.occurred_at < $3`;
  }

  const r = await query(
    `SELECT to_char(date_trunc('month', occurred_at), 'YYYY-MM') AS month,
            SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving'))::numeric AS expense,
            SUM(amount) FILTER (WHERE type = 'income')::numeric  AS income
     FROM transactions t
     WHERE ${baseWhere}
     GROUP BY month ORDER BY month`,
    params
  );
  return r.rows.map((row) => ({
    month: row.month,
    expense: Number(row.expense || 0),
    income: Number(row.income || 0),
  }));
}

async function byCategory(userId, { from, to, range, walletId } = {}) {
  let start, end;
  if (range === 'week') {
    const now = new Date();
    start = new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString();
    end = now.toISOString();
  } else if (range === 'year') {
    const y = new Date().getUTCFullYear();
    start = `${y}-01-01T00:00:00Z`;
    end = `${y + 1}-01-01T00:00:00Z`;
  } else {
    const r = parseRange(from, to);
    start = r.start; end = r.end;
  }

  let baseWhere;
  const params = [userId, start, end];
  if (walletId) {
    params.push(walletId);
    baseWhere = `t.is_deleted = FALSE
      AND t.wallet_id = $4
      AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
      AND t.occurred_at BETWEEN $2 AND $3`;
  } else {
    baseWhere = `t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at BETWEEN $2 AND $3`;
  }

  const r = await query(
    `SELECT COALESCE(category_code, 'Others') AS category_code,
            SUM(amount)::numeric AS total,
            COUNT(*)::int AS count
     FROM transactions t
     WHERE ${baseWhere}
       AND type = 'expense'
       AND (category_code IS NULL OR category_code != 'Saving')
     GROUP BY COALESCE(category_code, 'Others')
     ORDER BY total DESC`,
    params
  );
  const total = r.rows.reduce((s, row) => s + Number(row.total), 0);
  return r.rows.map((row) => ({
    categoryCode: row.category_code,
    total: Number(row.total),
    count: row.count,
    percent: total > 0 ? Math.round((Number(row.total) / total) * 100) : 0,
  }));
}

module.exports = { dashboard, byMonth, byCategory };
