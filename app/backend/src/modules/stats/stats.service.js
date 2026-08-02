'use strict';

const { query } = require('../../config/db');

function parseRange(from, to) {
  const now = new Date();
  let start;
  if (from) {
    start = typeof from === 'string' && from.length === 10
      ? new Date(`${from}T00:00:00.000Z`)
      : new Date(from);
  } else {
    start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  }

  let end;
  if (to) {
    end = typeof to === 'string' && to.length === 10
      ? new Date(`${to}T23:59:59.999Z`)
      : new Date(to);
  } else {
    end = now;
  }
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
    `SELECT CASE WHEN category_code IS NULL OR LOWER(category_code) IN ('other', 'others') THEN 'Other' ELSE category_code END AS category_code,
            SUM(amount)::numeric AS total,
            COUNT(*)::int AS count
     FROM transactions t WHERE ${baseWhere} AND type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')
     GROUP BY 1
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
      countExpense: Number(total.rows[0].count_expense || 0),
      countIncome: Number(total.rows[0].count_income || 0),
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
    baseWhere = `
      t.is_deleted = FALSE
      AND t.wallet_id = $4
      AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
      AND t.occurred_at >= $2 AND t.occurred_at < $3`;
  } else {
    baseWhere = `
      t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at >= $2 AND t.occurred_at < $3`;
  }

  const r = await query(
    `SELECT
       to_char(date_trunc('month', occurred_at), 'YYYY-MM') AS month,
       COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND (category_code IS NULL OR category_code != 'Saving')), 0)::numeric AS expense,
       COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0)::numeric  AS income
     FROM transactions t
     WHERE ${baseWhere}
     GROUP BY 1
     ORDER BY 1`,
    params
  );

  const months = [];
  const map = new Map(r.rows.map((row) => [row.month, row]));
  for (let m = 1; m <= 12; m++) {
    const key = `${y}-${String(m).padStart(2, '0')}`;
    const row = map.get(key);
    months.push({
      month: key,
      expense: row ? Number(row.expense) : 0,
      income: row ? Number(row.income) : 0,
      net: row ? Number(row.income) - Number(row.expense) : 0,
    });
  }
  return months;
}

async function byCategory(userId, { from, to, range, walletId, type = 'expense' } = {}) {
  let start, end;
  if (from || to) {
    const r = parseRange(from, to);
    start = r.start;
    end = r.end;
  } else if (range === 'week') {
    const now = new Date();
    start = new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString();
    end = now.toISOString();
  } else if (range === 'year') {
    const y = new Date().getUTCFullYear();
    start = `${y}-01-01T00:00:00Z`;
    end = `${y + 1}-01-01T00:00:00Z`;
  } else {
    const r = parseRange(from, to);
    start = r.start;
    end = r.end;
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

  const txType = (type === 'income') ? 'income' : 'expense';

  const r = await query(
    `SELECT CASE WHEN category_code IS NULL OR LOWER(category_code) IN ('other', 'others') THEN 'Other' ELSE category_code END AS category_code,
            SUM(amount)::numeric AS total,
            COUNT(*)::int AS count
     FROM transactions t
     WHERE ${baseWhere}
       AND type = '${txType}'
       AND (category_code IS NULL OR category_code != 'Saving')
     GROUP BY 1
     ORDER BY total DESC`,
    params
  );
  const total = r.rows.reduce((s, row) => s + Number(row.total), 0);
  return r.rows.map((row) => ({
    categoryCode: row.category_code,
    total: Number(row.total),
    amount: Number(row.total),
    count: row.count,
    percent: total > 0 ? Math.round((Number(row.total) / total) * 100) : 0,
  }));
}

async function getMoMComparison(userId, { walletId } = {}) {
  let walletClause = '';
  const params = [userId];
  if (walletId) {
    params.push(walletId);
    walletClause = 'AND t.wallet_id = $2 AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)';
  } else {
    walletClause = `AND t.wallet_id IN (
      SELECT w.id FROM wallets w
      JOIN wallet_members wm ON wm.wallet_id = w.id
      WHERE wm.user_id = $1 AND w.type = 'personal'
    )`;
  }

  const queryStr = `
    WITH this_month AS (
      SELECT COALESCE(category_code, 'Others') AS category_code,
             SUM(amount)::numeric AS total
      FROM transactions t
      WHERE t.is_deleted = FALSE
        AND t.type = 'expense'
        AND (category_code IS NULL OR category_code != 'Saving')
        AND date_trunc('month', t.occurred_at) = date_trunc('month', NOW())
        ${walletClause}
      GROUP BY 1
    ),
    last_month AS (
      SELECT COALESCE(category_code, 'Others') AS category_code,
             SUM(amount)::numeric AS total
      FROM transactions t
      WHERE t.is_deleted = FALSE
        AND t.type = 'expense'
        AND (category_code IS NULL OR category_code != 'Saving')
        AND date_trunc('month', t.occurred_at) = date_trunc('month', NOW() - INTERVAL '1 month')
        ${walletClause}
      GROUP BY 1
    )
    SELECT
      COALESCE(tm.category_code, lm.category_code) AS category_code,
      COALESCE(tm.total, 0) AS this_month_total,
      COALESCE(lm.total, 0) AS last_month_total
    FROM this_month tm
    FULL OUTER JOIN last_month lm ON tm.category_code = lm.category_code
    ORDER BY this_month_total DESC, last_month_total DESC
  `;

  const r = await query(queryStr, params);
  return r.rows.map(row => ({
    categoryCode: row.category_code,
    thisMonth: Number(row.this_month_total),
    lastMonth: Number(row.last_month_total),
  }));
}

async function getCumulativeVsBudget(userId, { walletId, timeRange = 'month', periodOffset = 0 } = {}) {
  let budgetQuery, txQuery;
  const now = new Date();

  let startDate, endDate;
  if (timeRange === 'week') {
    const currentDay = now.getUTCDay();
    const diffToMonday = currentDay === 0 ? -6 : 1 - currentDay;
    const startOfWeek = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + diffToMonday - 7 * periodOffset));
    startDate = startOfWeek;
    endDate = new Date(Date.UTC(startDate.getUTCFullYear(), startDate.getUTCMonth(), startDate.getUTCDate() + 6));
  } else {
    startDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - periodOffset, 1));
    endDate = new Date(Date.UTC(startDate.getUTCFullYear(), startDate.getUTCMonth() + 1, 0));
  }

  const startDateStr = startDate.toISOString().split('T')[0];
  const endDateStr = endDate.toISOString().split('T')[0];

  if (walletId) {
    budgetQuery = query(
      `SELECT 
         CASE 
           WHEN COALESCE(SUM(CASE WHEN category_code IS NULL THEN amount_limit ELSE 0 END), 0) > 0 
           THEN SUM(CASE WHEN category_code IS NULL THEN amount_limit ELSE 0 END)
           ELSE COALESCE(SUM(amount_limit), 0)
         END::numeric AS total_limit
       FROM budgets
       WHERE user_id = $1
         AND (wallet_id = $2 OR wallet_id IS NULL)
         AND is_active = TRUE
         AND start_date <= $3
         AND (end_date IS NULL OR end_date >= $4)`,
      [userId, walletId, endDateStr, startDateStr]
    );

    txQuery = query(
      `SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
              SUM(amount)::numeric AS daily_amount
       FROM transactions t
       WHERE t.is_deleted = FALSE
         AND t.type = 'expense'
         AND (category_code IS NULL OR category_code != 'Saving')
         AND t.wallet_id = $1
         AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $2)
         AND t.occurred_at >= $3::timestamp
         AND t.occurred_at < $4::timestamp + interval '1 day'
       GROUP BY day ORDER BY day`,
      [walletId, userId, startDateStr, endDateStr]
    );
  } else {
    budgetQuery = query(
      `SELECT 
         CASE 
           WHEN COALESCE(SUM(CASE WHEN category_code IS NULL THEN amount_limit ELSE 0 END), 0) > 0 
           THEN SUM(CASE WHEN category_code IS NULL THEN amount_limit ELSE 0 END)
           ELSE COALESCE(SUM(amount_limit), 0)
         END::numeric AS total_limit
       FROM budgets
       WHERE user_id = $1
         AND (wallet_id IN (
           SELECT w.id FROM wallets w
           JOIN wallet_members wm ON wm.wallet_id = w.id
           WHERE wm.user_id = $1 AND w.type = 'personal'
         ) OR wallet_id IS NULL)
         AND is_active = TRUE
         AND start_date <= $2
         AND (end_date IS NULL OR end_date >= $3)`,
      [userId, endDateStr, startDateStr]
    );

    txQuery = query(
      `SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
              SUM(amount)::numeric AS daily_amount
       FROM transactions t
       WHERE t.is_deleted = FALSE
         AND t.type = 'expense'
         AND (category_code IS NULL OR category_code != 'Saving')
         AND t.wallet_id IN (
           SELECT w.id FROM wallets w
           JOIN wallet_members wm ON wm.wallet_id = w.id
           WHERE wm.user_id = $1 AND w.type = 'personal'
         )
         AND t.occurred_at >= $2::timestamp
         AND t.occurred_at < $3::timestamp + interval '1 day'
       GROUP BY day ORDER BY day`,
      [userId, startDateStr, endDateStr]
    );
  }

  const [budgetRes, txRes] = await Promise.all([budgetQuery, txQuery]);
  let limit = Number(budgetRes.rows[0]?.total_limit || 0);

  if (timeRange === 'week') {
    const daysInMonth = new Date(startDate.getUTCFullYear(), startDate.getUTCMonth() + 1, 0).getUTCDate();
    limit = Math.round(limit * (7 / daysInMonth));
  }

  const allDays = generateDateRange(startDate.toISOString(), endDate.toISOString());
  const amountMap = new Map(txRes.rows.map(r => [r.day, Number(r.daily_amount)]));

  let cumulative = 0;
  const dailyCumulative = allDays.map(dayStr => {
    const dailySpend = amountMap.get(dayStr) || 0;
    cumulative += dailySpend;
    return {
      day: dayStr,
      amount: dailySpend,
      cumulative,
    };
  });

  return {
    limit,
    dailyCumulative,
  };
}

module.exports = { dashboard, byMonth, byCategory, getMoMComparison, getCumulativeVsBudget };
