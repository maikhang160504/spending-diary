'use strict';

const { query, withTransaction } = require('../../config/db');
const budgetsService = require('./budgets.service');

// ── Holiday Factor Lookup ────────────────────────────────────────────
// Hệ số mùa vụ theo tháng đích (tháng tiếp theo mà gợi ý áp dụng)
const HOLIDAY_FACTORS = {
  1:  1.20,  // Trước Tết — mua sắm Tết bắt đầu
  2:  1.50,  // Tết Nguyên Đán — quà cáp, du lịch, lì xì
  3:  0.85,  // Sau Tết — thắt lưng buộc bụng
  9:  1.15,  // Khai giảng — học phí, sách vở
  12: 1.25,  // Giáng sinh + Tết Dương lịch
};

// Danh mục "lãng phí" có thể gợi ý cắt giảm 5-10%
const DISCRETIONARY_CATEGORIES = new Set([
  'Entertainment', 'Shopping', 'Social', 'Beauty', 'Other',
]);

// Danh mục thiết yếu — không gợi ý cắt giảm
const ESSENTIAL_CATEGORIES = new Set([
  'Food', 'Housing', 'Transport', 'Essentials', 'Education', 'Health',
]);

// Danh mục phi định kỳ — flag outlier khi denoising (trừ tháng lễ)
const NON_RECURRING_CATEGORIES = new Set([
  'Health', 'Investment', 'Debt',
]);

// Tháng có chi tiêu Shopping/Social cao hợp lệ (không flag outlier cho chúng)
const HOLIDAY_MONTHS = new Set([1, 2, 12]);

// ── Helpers ──────────────────────────────────────────────────────────

function getHolidayFactor(targetMonth) {
  // targetMonth = '2026-07' → extract month number
  const m = parseInt(targetMonth.split('-')[1], 10);
  return HOLIDAY_FACTORS[m] || 1.00;
}

function getSavingRate(categoryCode, peerExceeded) {
  if (ESSENTIAL_CATEGORIES.has(categoryCode)) return 0.00;
  if (!DISCRETIONARY_CATEGORIES.has(categoryCode)) return 0.00;
  // Nếu user vượt peer benchmark → cắt 10%, không vượt → cắt 5%
  return peerExceeded ? 0.10 : 0.05;
}

function isHolidayMonth(monthStr) {
  const m = parseInt(monthStr.split('-')[1], 10);
  return HOLIDAY_MONTHS.has(m);
}

/**
 * Calculate standard deviation for an array of numbers.
 */
function stddev(arr) {
  if (arr.length < 2) return 0;
  const mean = arr.reduce((a, b) => a + b, 0) / arr.length;
  const variance = arr.reduce((s, v) => s + (v - mean) ** 2, 0) / arr.length;
  return Math.sqrt(variance);
}

/**
 * Generate the 3 previous month strings (YYYY-MM) relative to targetMonth.
 * E.g. targetMonth='2026-07' → ['2026-06', '2026-05', '2026-04']
 */
function getPrev3Months(targetMonth) {
  const [y, m] = targetMonth.split('-').map(Number);
  const months = [];
  for (let i = 1; i <= 3; i++) {
    const d = new Date(Date.UTC(y, m - 1 - i, 1));
    const my = d.getUTCFullYear();
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    months.push(`${my}-${mm}`);
  }
  return months;
}

/**
 * Get the month range for a YYYY-MM string.
 * Returns { from, to } as ISO strings.
 */
function monthRange(monthStr) {
  const [y, m] = monthStr.split('-').map(Number);
  const from = new Date(Date.UTC(y, m - 1, 1)).toISOString();
  const to = new Date(Date.UTC(y, m, 1)).toISOString(); // exclusive end
  return { from, to };
}

// ── Core Algorithm ───────────────────────────────────────────────────

/**
 * Fetch monthly category spending for a user in a given month.
 * Returns Map<categoryCode, { total, transactions: number[] }>
 */
async function fetchMonthlySpending(userId, monthStr) {
  const { from, to } = monthRange(monthStr);
  const r = await query(
    `SELECT category_code, amount::numeric
     FROM transactions t
     WHERE t.is_deleted = FALSE
       AND t.type = 'expense'
       AND (t.category_code IS NULL OR t.category_code != 'Saving')
       AND t.wallet_id IN (
         SELECT w.id FROM wallets w
         JOIN wallet_members wm ON wm.wallet_id = w.id
         WHERE wm.user_id = $1 AND w.type = 'personal'
       )
       AND t.occurred_at >= $2
       AND t.occurred_at < $3`,
    [userId, from, to]
  );

  const map = new Map();
  for (const row of r.rows) {
    const cat = row.category_code || 'Other';
    if (!map.has(cat)) map.set(cat, { total: 0, amounts: [] });
    const entry = map.get(cat);
    const amt = Number(row.amount);
    entry.total += amt;
    entry.amounts.push(amt);
  }
  return map;
}

/**
 * Fetch total income for a user in a given month.
 */
async function fetchMonthlyIncome(userId, monthStr) {
  const { from, to } = monthRange(monthStr);
  const r = await query(
    `SELECT COALESCE(SUM(amount), 0)::numeric AS total
     FROM transactions t
     WHERE t.is_deleted = FALSE
       AND t.type = 'income'
       AND t.wallet_id IN (
         SELECT w.id FROM wallets w
         JOIN wallet_members wm ON wm.wallet_id = w.id
         WHERE wm.user_id = $1 AND w.type = 'personal'
       )
       AND t.occurred_at >= $2
       AND t.occurred_at < $3`,
    [userId, from, to]
  );
  return Number(r.rows[0].total);
}

/**
 * Step 1: Denoising — remove outliers > 3σ (except during holiday months).
 * Returns filtered total per category.
 */
function denoiseCategory(categoryCode, amounts, monthStr) {
  if (amounts.length < 3) {
    // Not enough data for statistical filtering
    return amounts.reduce((a, b) => a + b, 0);
  }

  const holiday = isHolidayMonth(monthStr);

  // In holiday months, don't filter Shopping/Social — they're legitimate spikes
  if (holiday && (categoryCode === 'Shopping' || categoryCode === 'Social')) {
    return amounts.reduce((a, b) => a + b, 0);
  }

  // Non-recurring categories always filtered regardless
  const mean = amounts.reduce((a, b) => a + b, 0) / amounts.length;
  const sd = stddev(amounts);
  const threshold = mean + 3 * sd;

  let total = 0;
  for (const a of amounts) {
    if (a <= threshold || sd === 0) {
      total += a;
    }
    // else: outlier, excluded
  }
  return total;
}

/**
 * Step 2: Compute base spending (B) using Weighted Moving Average.
 * Weights: most recent month × 0.5, previous × 0.3, oldest × 0.2
 */
function computeBaseSpending(monthlyTotals) {
  // monthlyTotals: [most_recent, previous, oldest] — already denoised
  const weights = [0.5, 0.3, 0.2];
  const available = monthlyTotals.filter((v) => v !== null && v !== undefined);

  if (available.length === 0) return null;
  if (available.length === 1) return available[0];
  if (available.length === 2) {
    // 2 months: 60/40 split
    return available[0] * 0.6 + available[1] * 0.4;
  }

  let sum = 0;
  for (let i = 0; i < 3; i++) {
    sum += (available[i] || 0) * weights[i];
  }
  return sum;
}

/**
 * Step 2b: Compute Income Factor (I).
 * Compares recent income trend. Capped between 0.7 and 1.0.
 */
function computeIncomeFactor(incomes) {
  // incomes: [most_recent, previous, oldest]
  const valid = incomes.filter((v) => v > 0);
  if (valid.length < 2) return 1.0; // Not enough data

  const recent = valid[0];
  const older = valid.slice(1).reduce((a, b) => a + b, 0) / (valid.length - 1);

  if (older === 0) return 1.0;
  const ratio = recent / older;
  return Math.max(0.7, Math.min(1.0, ratio));
}

/**
 * Main: Compute suggestions for a single user.
 */
async function computeSuggestionsForUser(userId, targetMonth) {
  const prevMonths = getPrev3Months(targetMonth);
  const holidayFactor = getHolidayFactor(targetMonth);

  // Fetch spending data for 3 previous months
  const monthlyData = [];
  for (const m of prevMonths) {
    const data = await fetchMonthlySpending(userId, m);
    monthlyData.push({ month: m, data });
  }

  // Fetch incomes for 3 previous months
  const incomes = [];
  for (const m of prevMonths) {
    const income = await fetchMonthlyIncome(userId, m);
    incomes.push(income);
  }

  // Fetch user's active budgets and restrict suggestions to those categories
  const activeBudgets = await budgetsService.list(userId);
  const activeCats = new Set(activeBudgets.map(b => b.categoryCode).filter(Boolean));

  // Collect all unique categories across 3 months (restricted to active budgets)
  const allCats = new Set();
  for (const { data } of monthlyData) {
    for (const cat of data.keys()) {
      if (activeCats.has(cat)) {
        allCats.add(cat);
      }
    }
  }

  // If user has no data at all, fallback to peer benchmark (filtered by active budgets)
  if (allCats.size === 0) {
    const fallback = await computeFallbackFromPeer(userId, targetMonth, holidayFactor);
    return fallback.filter(s => activeCats.has(s.category_code));
  }

  const incomeFactor = computeIncomeFactor(incomes);

  // Fetch peer benchmarks for comparison
  let peerBenchmarks = new Map();
  try {
    const settingsRes = await query(
      'SELECT age_group, job_type FROM user_settings WHERE user_id = $1',
      [userId]
    );
    const ageGroup = settingsRes.rows[0]?.age_group;
    const jobType = settingsRes.rows[0]?.job_type;
    if (ageGroup && jobType) {
      const benchRes = await query(
        `SELECT category_id, avg_amount::numeric FROM group_spending_benchmarks
         WHERE age_group = $1 AND job_type = $2 AND period = 'month'`,
        [ageGroup, jobType]
      );
      for (const row of benchRes.rows) {
        peerBenchmarks.set(row.category_id, Number(row.avg_amount));
      }
    }
  } catch (_) { /* peer data optional */ }

  const suggestions = [];

  for (const cat of allCats) {
    // Collect denoised totals per month
    const totals = prevMonths.map((m, i) => {
      const catData = monthlyData[i].data.get(cat);
      if (!catData) return 0;
      return denoiseCategory(cat, catData.amounts, m);
    });

    const baseSpending = computeBaseSpending(totals);
    if (baseSpending === null || baseSpending <= 0) continue;

    // Check if user exceeded peer benchmark last month
    const peerAvg = peerBenchmarks.get(cat);
    const peerExceeded = peerAvg ? totals[0] > peerAvg : false;

    const savingRate = getSavingRate(cat, peerExceeded);

    const suggested = Math.round(baseSpending * incomeFactor * (1 - savingRate) * holidayFactor);

    // Build reason text
    let reason = `Dựa trên chi tiêu trung bình ${formatVnd(Math.round(baseSpending))}đ/tháng`;
    if (savingRate > 0) {
      reason += `, giảm ${Math.round(savingRate * 100)}% để tiết kiệm`;
    }
    if (holidayFactor !== 1.0) {
      const adj = holidayFactor > 1 ? 'tăng' : 'giảm';
      reason += `, ${adj} ${Math.round(Math.abs(holidayFactor - 1) * 100)}% theo mùa lễ`;
    }
    if (peerExceeded) {
      reason += ` (đang cao hơn nhóm tương đồng)`;
    }

    suggestions.push({
      category_code: cat,
      suggested_amount: suggested,
      base_spending: Math.round(baseSpending),
      income_factor: Math.round(incomeFactor * 1000) / 1000,
      saving_rate: Math.round(savingRate * 1000) / 1000,
      holiday_factor: Math.round(holidayFactor * 1000) / 1000,
      reason,
    });
  }

  // ── 50/30/20 Financial Calibration & Dynamic Adjustments ──
  const NEEDS_CATEGORIES = new Set(['Food', 'Transport', 'Housing', 'Essentials', 'Education', 'Health']);
  const WANTS_CATEGORIES = new Set(['Shopping', 'Entertainment', 'Beauty', 'Social', 'Other', 'Others']);

  let userIncome = incomes.reduce((a, b) => a + b, 0) / (incomes.filter(v => v > 0).length || 1);
  if (userIncome <= 0) {
    try {
      const settingsRes = await query('SELECT income_amount::numeric FROM user_settings WHERE user_id = $1', [userId]);
      if (settingsRes.rows[0]?.income_amount) {
        userIncome = Number(settingsRes.rows[0].income_amount);
      }
    } catch (_) {}
    if (userIncome <= 0) {
      userIncome = 10000000; // Fallback 10M VND
    }
  }

  let initialNeedsSum = 0;
  let initialWantsSum = 0;
  let initialSavingsSum = 0;

  for (const s of suggestions) {
    if (NEEDS_CATEGORIES.has(s.category_code)) {
      initialNeedsSum += s.suggested_amount;
    } else if (WANTS_CATEGORIES.has(s.category_code)) {
      initialWantsSum += s.suggested_amount;
    } else {
      initialSavingsSum += s.suggested_amount;
    }
  }

  let isDynamicAdjusted = false;
  let needsLimit = userIncome * 0.50;
  let wantsLimit = userIncome * 0.30;
  let savingsLimit = userIncome * 0.20;

  // Dynamic calibration when essential needs exceed 50%
  if (initialNeedsSum > needsLimit) {
    isDynamicAdjusted = true;
    const minSavingsTarget = Math.max(0, userIncome - initialNeedsSum - (initialWantsSum * 0.50));
    needsLimit = initialNeedsSum;
    wantsLimit = initialWantsSum * 0.50;
    savingsLimit = minSavingsTarget;
  }

  const needsScale = initialNeedsSum > needsLimit ? (needsLimit / initialNeedsSum) : 1.0;
  const wantsScale = initialWantsSum > wantsLimit ? (wantsLimit / initialWantsSum) : 1.0;
  const savingsScale = initialSavingsSum > savingsLimit ? (savingsLimit / initialSavingsSum) : 1.0;

  for (const s of suggestions) {
    let scale = 1.0;
    let ruleName = '';
    if (NEEDS_CATEGORIES.has(s.category_code)) {
      scale = needsScale;
      ruleName = isDynamicAdjusted ? 'Thiết yếu thực tế' : 'Thiết yếu 50%';
    } else if (WANTS_CATEGORIES.has(s.category_code)) {
      scale = wantsScale;
      ruleName = isDynamicAdjusted ? 'Linh hoạt điều chỉnh (giảm 50%)' : 'Linh hoạt 30%';
    } else {
      scale = savingsScale;
      ruleName = isDynamicAdjusted ? 'Tích lũy tối thiểu' : 'Tích lũy 20%';
    }

    if (scale < 1.0) {
      s.suggested_amount = Math.round(s.suggested_amount * scale);
      s.reason += ` (Tối ưu 50/30/20 nhóm ${ruleName}: giảm ${Math.round((1 - scale) * 100)}%)`;
    }
  }

  return suggestions;
}

/**
 * Fallback: user has no spending history → use peer benchmarks.
 */
async function computeFallbackFromPeer(userId, targetMonth, holidayFactor) {
  const settingsRes = await query(
    'SELECT age_group, job_type FROM user_settings WHERE user_id = $1',
    [userId]
  );
  const ageGroup = settingsRes.rows[0]?.age_group;
  const jobType = settingsRes.rows[0]?.job_type;
  if (!ageGroup || !jobType) return [];

  const benchRes = await query(
    `SELECT category_id, avg_amount::numeric, p80_amount::numeric
     FROM group_spending_benchmarks
     WHERE age_group = $1 AND job_type = $2 AND period = 'month'`,
    [ageGroup, jobType]
  );

  return benchRes.rows.map((row) => {
    const avg = Number(row.avg_amount);
    const suggested = Math.round(avg * holidayFactor);
    return {
      category_code: row.category_id,
      suggested_amount: suggested,
      base_spending: avg,
      income_factor: 1.0,
      saving_rate: 0.0,
      holiday_factor: holidayFactor,
      reason: `Dựa trên mức chi tiêu trung bình nhóm ${ageGroup} - ${jobType}`,
    };
  });
}

// ── Persistence ──────────────────────────────────────────────────────

/**
 * Save suggestions to DB (upsert).
 */
async function saveSuggestions(userId, targetMonth, suggestions) {
  await withTransaction(async (client) => {
    for (const s of suggestions) {
      await client.query(
        `INSERT INTO user_budget_suggestions
           (user_id, target_month, category_code, suggested_amount,
            base_spending, income_factor, saving_rate, holiday_factor, reason, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
         ON CONFLICT (user_id, target_month, category_code)
         DO UPDATE SET suggested_amount = EXCLUDED.suggested_amount,
                       base_spending = EXCLUDED.base_spending,
                       income_factor = EXCLUDED.income_factor,
                       saving_rate = EXCLUDED.saving_rate,
                       holiday_factor = EXCLUDED.holiday_factor,
                       reason = EXCLUDED.reason,
                       status = 'pending',
                       updated_at = NOW()`,
        [
          userId, targetMonth, s.category_code, s.suggested_amount,
          s.base_spending, s.income_factor, s.saving_rate, s.holiday_factor,
          s.reason,
        ]
      );
    }
  });
}

/**
 * Read suggestions for a user+month.
 */
async function getSuggestions(userId, targetMonth) {
  const r = await query(
    `SELECT * FROM user_budget_suggestions
     WHERE user_id = $1 AND target_month = $2
     ORDER BY suggested_amount DESC`,
    [userId, targetMonth]
  );
  return r.rows.map((row) => ({
    id: row.id,
    categoryCode: row.category_code,
    suggestedAmount: Number(row.suggested_amount),
    baseSpending: Number(row.base_spending),
    incomeFactor: Number(row.income_factor),
    savingRate: Number(row.saving_rate),
    holidayFactor: Number(row.holiday_factor),
    reason: row.reason,
    status: row.status,
  }));
}

/**
 * 1-Click Apply: create budgets from suggestions.
 * Optional `overrides` map: { categoryCode: newAmount }
 */
async function applySuggestions(userId, targetMonth, overrides = {}) {
  const suggestions = await getSuggestions(userId, targetMonth);
  if (suggestions.length === 0) return { applied: 0, budgets: [] };

  const today = new Date().toISOString().slice(0, 10);
  const budgets = [];

  for (const s of suggestions) {
    const amount = overrides[s.categoryCode] || s.suggestedAmount;
    const budget = await budgetsService.create(userId, {
      categoryCode: s.categoryCode,
      period: 'month',
      amountLimit: amount,
      startDate: today,
    });
    budgets.push(budget);
  }

  // Mark suggestions as applied
  await query(
    `UPDATE user_budget_suggestions SET status = 'applied', updated_at = NOW()
     WHERE user_id = $1 AND target_month = $2`,
    [userId, targetMonth]
  );

  return { applied: budgets.length, budgets };
}

/**
 * Dismiss suggestions for a month.
 */
async function dismissSuggestions(userId, targetMonth) {
  await query(
    `UPDATE user_budget_suggestions SET status = 'dismissed', updated_at = NOW()
     WHERE user_id = $1 AND target_month = $2`,
    [userId, targetMonth]
  );
}

/**
 * Generate + save suggestions for a single user (called by batch or on-demand).
 */
async function generateForUser(userId, targetMonth) {
  const suggestions = await computeSuggestionsForUser(userId, targetMonth);
  if (suggestions.length > 0) {
    await saveSuggestions(userId, targetMonth, suggestions);
  }
  return suggestions;
}

/**
 * Batch job: generate suggestions for ALL active users.
 * Intended to run via cron or manual trigger.
 */
async function generateBatch(targetMonth) {
  const usersRes = await query('SELECT id FROM users');
  let count = 0;
  for (const row of usersRes.rows) {
    try {
      const suggestions = await generateForUser(row.id, targetMonth);
      if (suggestions.length > 0) count++;
    } catch (err) {
      console.error(`Failed to generate suggestions for user ${row.id}:`, err.message);
    }
  }
  return { usersProcessed: usersRes.rows.length, usersWithSuggestions: count };
}

// ── Format helpers ───────────────────────────────────────────────────

function formatVnd(n) {
  return Number(n || 0).toLocaleString('vi-VN');
}

/**
 * Build a MiMo-style story from suggestions.
 */
function buildSuggestionStory(suggestions, targetMonth) {
  if (!suggestions || suggestions.length === 0) {
    return 'Chưa có đủ dữ liệu để gợi ý hạn mức cho tháng tới. Hãy tiếp tục ghi chép chi tiêu nhé!';
  }

  const totalSuggested = suggestions.reduce((s, v) => s + v.suggestedAmount, 0);
  const totalBase = suggestions.reduce((s, v) => s + v.baseSpending, 0);
  const diff = totalBase - totalSuggested;

  let story = '';
  if (diff > 0) {
    story = `MiMo đã phân tích chi tiêu gần đây và thiết kế riêng cho bạn một Hạn mức thông minh: ${formatVnd(totalSuggested)}đ cho tháng tới (giúp bạn tiết kiệm thêm ${formatVnd(diff)}đ mà vẫn ăn ngon mặc đẹp 🐷).`;
  } else if (diff < 0) {
    story = `Tháng tới có dịp lễ nên MiMo đã nới rộng ngân sách cho bạn: ${formatVnd(totalSuggested)}đ (tăng ${formatVnd(Math.abs(diff))}đ so với bình thường để bạn thoải mái vui chơi 🎉).`;
  } else {
    story = `MiMo gợi ý hạn mức tháng tới: ${formatVnd(totalSuggested)}đ — giữ nguyên nhịp chi tiêu ổn định hiện tại 👍.`;
  }

  // Top 3 categories
  const top3 = suggestions.slice(0, 3);
  const details = top3.map((s) => `${s.categoryCode}: ${formatVnd(s.suggestedAmount)}đ`).join(' | ');
  story += `\n\nChi tiết: ${details}`;

  story += '\n\nBạn có muốn áp dụng ngay không?';
  return story;
}

// ── Exports ──────────────────────────────────────────────────────────

module.exports = {
  // Core algorithm (exported for testing)
  computeSuggestionsForUser,
  computeFallbackFromPeer,
  computeBaseSpending,
  computeIncomeFactor,
  denoiseCategory,
  getHolidayFactor,
  getSavingRate,
  getPrev3Months,
  isHolidayMonth,
  stddev,
  // Persistence
  saveSuggestions,
  getSuggestions,
  applySuggestions,
  dismissSuggestions,
  generateForUser,
  generateBatch,
  // Formatting
  buildSuggestionStory,
  formatVnd,
};
