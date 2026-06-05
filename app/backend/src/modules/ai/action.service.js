'use strict';

const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const statsService = require('../stats/stats.service');
const budgetsService = require('../budgets/budgets.service');
const goalsService = require('../goals/goals.service');
const settingsService = require('../settings/settings.service');
const txService = require('../transactions/transactions.service');
const suggestionService = require('../budgets/suggestion.service');

const REPORT_TYPES = new Set(['REPORT', 'REPORT_GENERAL', 'REPORT_COMPARE', 'REPORT_INCOME', 'REPORT_SAVINGS']);

const VI_CATEGORY_MAP = {
  'an uong': 'Food',
  'ca phe': 'Food',
  'di lai': 'Transport',
  'mua sam': 'Shopping',
  'giai tri': 'Entertainment',
  'dien nuoc': 'Housing',
  'hoc phi': 'Education',
  'y te': 'Health',
  'nha cua': 'Housing',
};

const TONE_MAP = {
  'hai huoc': 'funny',
  'vui ve': 'funny',
  'de thuong': 'gentle',
  'dong cam': 'gentle',
  'nghiem tuc': 'serious',
  'cham choc': 'sarcastic',
  'dan doi': 'strict',
  'strict': 'strict',
};

function isReportAction(actionType) {
  if (!actionType) return false;
  const upper = String(actionType).toUpperCase();
  return REPORT_TYPES.has(upper) || upper.includes('REPORT');
}

function _norm(s) {
  return (s || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function resolveCategoryCode(categoryCode, actionDetails) {
  if (categoryCode) return categoryCode;
  const target = actionDetails?.target;
  if (!target) return null;
  const key = _norm(String(target));
  if (VI_CATEGORY_MAP[key]) return VI_CATEGORY_MAP[key];
  if (/^[A-Z][a-zA-Z]+$/.test(String(target))) return String(target);
  return null;
}

function resolveAmount(payload, actionDetails) {
  const raw = payload.amount ?? payload.actionParam ?? actionDetails?.value;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** Fallback JS time parser when NLU did not return time_range. */
function inferTimeRangeFromText(text) {
  const t = _norm(text);
  const now = new Date();
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
  const endOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);
  const mondayOf = (d) => {
    const s = startOfDay(d);
    const day = s.getDay();
    const diff = day === 0 ? 6 : day - 1;
    s.setDate(s.getDate() - diff);
    return s;
  };
  const fmt = (d) => d.toISOString();
  const label = (prefix, from, to) => {
    const pad = (n) => String(n).padStart(2, '0');
    const f = `${pad(from.getDate())}/${pad(from.getMonth() + 1)}`;
    const t2 = `${pad(to.getDate())}/${pad(to.getMonth() + 1)}/${to.getFullYear()}`;
    return `${prefix} (${f} - ${t2})`;
  };

  if (/\btuan nay\b/.test(t)) {
    const from = mondayOf(now);
    return { period_label: label('Tuần này', from, now), from: fmt(from), to: fmt(endOfDay(now)), granularity: 'week' };
  }
  if (/\bthang nay\b/.test(t)) {
    const from = new Date(now.getFullYear(), now.getMonth(), 1);
    return { period_label: label('Tháng này', from, now), from: fmt(from), to: fmt(endOfDay(now)), granularity: 'month' };
  }
  if (/\bhom nay\b/.test(t)) {
    const from = startOfDay(now);
    const pad = (n) => String(n).padStart(2, '0');
    return {
      period_label: `Hôm nay (${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()})`,
      from: fmt(from),
      to: fmt(endOfDay(now)),
      granularity: 'day',
    };
  }
  if (/\b7 ngay\b/.test(t)) {
    const from = startOfDay(now);
    from.setDate(from.getDate() - 6);
    return { period_label: label('7 ngày qua', from, now), from: fmt(from), to: fmt(endOfDay(now)), granularity: 'rolling_7d' };
  }
  const from = new Date(now.getFullYear(), now.getMonth(), 1);
  return { period_label: label('Tháng này', from, now), from: fmt(from), to: fmt(endOfDay(now)), granularity: 'month' };
}

function getVietnameseDayOfWeek(dateStr) {
  const days = ['Chủ Nhật', 'thứ Hai', 'thứ Ba', 'thứ Tư', 'thứ Năm', 'thứ Sáu', 'thứ Bảy'];
  const d = new Date(dateStr);
  return days[d.getDay()];
}

const VI_CATEGORY_LABELS = {
  // Legacy / NLU Category Codes
  'Food': 'ăn uống',
  'Transport': 'đi lại',
  'Housing': 'nhà cửa',
  'Others': 'tiêu dùng khác',

  // Official category.json names & translations
  'Food & Drink': 'Ăn uống',
  'Transportation': 'Di Chuyển',
  'Shopping': 'Mua sắm',
  'Entertainment': 'Giải trí',
  'Health': 'Sức khỏe',
  'Education': 'Giáo dục',
  'Beauty': 'Làm đẹp',
  'Housing': 'Nhà ở',
  'Social': 'Xã hội',
  'Business': 'Kinh doanh',
  'Bonus': 'Thưởng',
  'Charity': 'Từ thiện',
  'Essentials': 'Đồ dùng thiết yếu',
  'Debt': 'Nợ',
  'Investment': 'Đầu tư',
  'Saving': 'Tiết kiệm',
  'Other': 'Khác',
  'Salary': 'Lương',
};

function getCategoryLabelVi(catCode) {
  return VI_CATEGORY_LABELS[catCode] || catCode || 'chi tiêu';
}

function getPreviousPeriodRange(fromStr, toStr, granularity) {
  const from = new Date(fromStr);
  const to = new Date(toStr);
  const prevFrom = new Date(from);
  const prevTo = new Date(to);

  if (granularity === 'week') {
    prevFrom.setDate(prevFrom.getDate() - 7);
    prevTo.setDate(prevTo.getDate() - 7);
  } else if (granularity === 'day') {
    prevFrom.setDate(prevFrom.getDate() - 1);
    prevTo.setDate(prevTo.getDate() - 1);
  } else if (granularity === 'month') {
    prevFrom.setMonth(prevFrom.getMonth() - 1);
    prevTo.setMonth(prevTo.getMonth() - 1);
  } else {
    const diffMs = to.getTime() - from.getTime();
    prevFrom.setTime(prevFrom.getTime() - diffMs);
    prevTo.setTime(prevTo.getTime() - diffMs);
  }
  return { from: prevFrom.toISOString(), to: prevTo.toISOString() };
}

async function getHighestTransactions(userId, from, to) {
  const values = [userId, from, to];
  const sql = `
    SELECT t.id, t.amount, t.note, t.category_code, t.occurred_at
    FROM transactions t
    WHERE t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at BETWEEN $2 AND $3
      AND t.type = 'expense'
      AND (t.category_code IS NULL OR t.category_code != 'Saving')
    ORDER BY t.amount DESC
    LIMIT 3
  `;
  const res = await query(sql, values);
  return res.rows.map((row) => ({
    id: row.id,
    amount: Number(row.amount),
    note: row.note || getCategoryLabelVi(row.category_code),
    categoryCode: row.category_code,
    occurredAt: row.occurred_at,
  }));
}

async function getHighestTransactionOnDay(userId, dayStr) {
  const startOfDay = `${dayStr}T00:00:00.000Z`;
  const endOfDay = `${dayStr}T23:59:59.999Z`;
  const values = [userId, startOfDay, endOfDay];
  const sql = `
    SELECT t.note, t.category_code, t.amount
    FROM transactions t
    WHERE t.is_deleted = FALSE
      AND t.wallet_id IN (
        SELECT w.id FROM wallets w
        JOIN wallet_members wm ON wm.wallet_id = w.id
        WHERE wm.user_id = $1 AND w.type = 'personal'
      )
      AND t.occurred_at BETWEEN $2 AND $3
      AND t.type = 'expense'
      AND (t.category_code IS NULL OR t.category_code != 'Saving')
    ORDER BY t.amount DESC
    LIMIT 1
  `;
  const res = await query(sql, values);
  if (res.rows.length > 0) {
    const row = res.rows[0];
    return {
      note: row.note,
      categoryCode: row.category_code,
      amount: Number(row.amount),
    };
  }
  return null;
}

async function executeReport(userId, { timeRange, categoryCode, reportKind, text } = {}) {
  const range = timeRange || inferTimeRangeFromText(text || '');
  const dash = await statsService.dashboard(userId, { from: range.from, to: range.to });
  const kind = reportKind || detectReportKind(text, null);

  let byCategory = dash.byCategory || [];
  if (categoryCode) {
    byCategory = byCategory.filter((c) => c.categoryCode === categoryCode);
  }

  const totalExpense = dash.totals?.expense ?? 0;
  const totalIncome = dash.totals?.income ?? 0;
  const txCount = dash.totals?.countExpense ?? 0;
  const catTotal = byCategory.reduce((s, c) => s + c.total, 0);

  const enriched = byCategory.map((c) => ({
    categoryCode: c.categoryCode,
    total: c.total,
    count: c.count,
    percent: catTotal > 0 ? Math.round((c.total / catTotal) * 100) : 0,
  }));

  // Determine report sub-type (general, highest, cycle, compare)
  const normText = _norm(text || '');
  let subType = 'general';
  if (/\b(cao nhat|dat nhat|ton tien nhat|to nhat|nhieu nhat|lon nhat)\b/.test(normText)) {
    subType = 'highest';
  } else if (/\b(so sanh|nhom|moi nguoi|sinh vien khac|dong trang lua|cung nhom|hon ai|thua ai)\b/.test(normText)) {
    subType = 'compare';
  } else if (range.granularity === 'week' || /\b(tuan|chu ky)\b/.test(normText)) {
    subType = 'cycle';
  }

  // 1. Calculate previous period comparison
  let comparePercent = 0;
  const prevRange = getPreviousPeriodRange(range.from, range.to, range.granularity);
  try {
    const prevDash = await statsService.dashboard(userId, { from: prevRange.from, to: prevRange.to });
    const prevExpense = prevDash.totals?.expense ?? 0;
    if (prevExpense > 0) {
      comparePercent = Math.round(((totalExpense - prevExpense) / prevExpense) * 100);
    }
  } catch (err) {
    console.error('Failed to query previous period stats:', err);
  }

  // 2. Fetch monthly budget limit
  let limitAmount = null;
  let limitProgress = null;
  try {
    const budgets = await budgetsService.list(userId);
    const budget = budgets.find(
      (b) =>
        b.period === 'month' &&
        (b.categoryCode || null) === (categoryCode || null)
    );
    if (budget) {
      limitAmount = Number(budget.amountLimit);
      limitProgress = limitAmount > 0 ? Number(((totalExpense / limitAmount) * 100).toFixed(1)) : 0;
    }
  } catch (err) {
    console.error('Failed to query budgets:', err);
  }

  // 3. Fetch highest transactions in this period
  let highestTransactions = [];
  try {
    highestTransactions = await getHighestTransactions(userId, range.from, range.to);
  } catch (err) {
    console.error('Failed to query highest transactions:', err);
  }

  // 4. Fetch peak day and its highest transaction
  let peakDay = null;
  const days = dash.byDay || [];
  if (days.length > 0) {
    let maxDay = null;
    let maxExpense = -1;
    for (const d of days) {
      if (d.expense > maxExpense) {
        maxExpense = d.expense;
        maxDay = d;
      }
    }
    if (maxDay && maxDay.expense > 0) {
      const dayOfWeek = getVietnameseDayOfWeek(maxDay.day);
      let txInfo = null;
      try {
        txInfo = await getHighestTransactionOnDay(userId, maxDay.day);
      } catch (err) {
        console.error('Failed to query peak day highest transaction:', err);
      }
      peakDay = {
        day: maxDay.day,
        day_of_week: dayOfWeek,
        amount: maxDay.expense,
        category: txInfo ? txInfo.categoryCode : null,
        note: txInfo ? (txInfo.note || getCategoryLabelVi(txInfo.categoryCode)) : null,
      };
    }
  }

  // 5. Fetch peer spending benchmark comparison
  let peerBenchmark = null;
  const targetCategory = categoryCode || (enriched[0]?.categoryCode) || 'Food';
  try {
    const settingsRes = await query(
      'SELECT age_group, job_type FROM user_settings WHERE user_id = $1',
      [userId]
    );
    const ageGroup = settingsRes.rows[0]?.age_group;
    const jobType = settingsRes.rows[0]?.job_type;
    
    if (ageGroup && jobType) {
      const benchmarkRes = await query(
        `SELECT avg_amount, p80_amount 
         FROM group_spending_benchmarks 
         WHERE age_group = $1 
           AND job_type = $2 
           AND category_id = $3 
           AND period = $4`,
        [ageGroup, jobType, targetCategory, range.granularity === 'week' ? 'week' : 'month']
      );
      if (benchmarkRes.rows.length > 0) {
        peerBenchmark = {
          age_group: ageGroup,
          job_type: jobType,
          avg_amount: Number(benchmarkRes.rows[0].avg_amount),
          p80_amount: Number(benchmarkRes.rows[0].p80_amount),
          target_category: targetCategory,
        };
      }
    }
  } catch (err) {
    console.error('Failed to query peer benchmark:', err);
  }

  const payload = {
    kind: 'report',
    report_kind: kind,
    report_sub_type: subType,
    period_label: range.period_label,
    total_expense: totalExpense,
    total_income: totalIncome,
    transaction_count: txCount,
    by_category: enriched.slice(0, 8),
    by_day: days,
    range: dash.range,
    compare_percent: comparePercent,
    limit_amount: limitAmount,
    limit_progress: limitProgress,
    highest_transactions: highestTransactions,
    peak_day: peakDay,
    peer_benchmark: peerBenchmark,
  };
  payload.message = buildReportStory(payload);
  return payload;
}

async function executeSetLimit(userId, payload) {
  const actionDetails = payload.actionDetails || {};
  const amount = resolveAmount(payload, actionDetails);
  if (!amount) throw ApiError.badRequest('Thiếu số tiền hạn mức.');

  const categoryCode = resolveCategoryCode(payload.categoryCode, actionDetails);
  const walletId = payload.walletId || null;
  const today = new Date().toISOString().slice(0, 10);

  const budgets = await budgetsService.list(userId);
  const existing = budgets.find(
    (b) =>
      b.period === 'month' &&
      (b.categoryCode || null) === (categoryCode || null) &&
      (!walletId || b.walletId === walletId)
  );

  const verb = (actionDetails.verb || 'SET').toUpperCase();
  let newLimit = amount;
  let operatorMsg = '';

  if (verb === 'ADD') {
    newLimit = (existing ? Number(existing.amountLimit) : 0) + amount;
    operatorMsg = `cộng thêm ${formatVnd(amount)}đ vào`;
  } else if (verb === 'SUB') {
    newLimit = Math.max(0, (existing ? Number(existing.amountLimit) : 0) - amount);
    operatorMsg = `giảm bớt ${formatVnd(amount)}đ từ`;
  } else {
    newLimit = amount;
    operatorMsg = `${existing ? 'cập nhật' : 'đặt'} thành ${formatVnd(amount)}đ cho`;
  }

  let budget;
  let action = 'created';
  if (existing) {
    budget = await budgetsService.update(userId, existing.id, { amountLimit: newLimit });
    action = 'updated';
  } else {
    budget = await budgetsService.create(userId, {
      walletId,
      categoryCode: categoryCode || undefined,
      period: 'month',
      amountLimit: newLimit,
      startDate: today,
    });
  }

  const catLabel = categoryCode || 'tổng';
  return {
    kind: 'limit',
    action,
    budget,
    categoryCode,
    amount: newLimit,
    message: `✅ Đã ${operatorMsg} hạn mức ${catLabel} (hạn mức mới: ${formatVnd(newLimit)}đ/tháng).`,
  };
}

async function executeSetGoal(userId, payload) {
  const actionDetails = payload.actionDetails || {};
  const amount = resolveAmount(payload, actionDetails);
  if (!amount) throw ApiError.badRequest('Thiếu số tiền mục tiêu.');

  const goal = await goalsService.create(userId, {
    walletId: payload.walletId || undefined,
    name: payload.goalName || 'Mục tiêu tiết kiệm',
    targetAmount: amount,
    emoji: '🎯',
  });

  return {
    kind: 'goal',
    goal,
    message: `✅ Đã tạo mục tiêu "${goal.name || payload.goalName || 'Mục tiêu'}" — ${formatVnd(amount)}đ.`,
  };
}

async function executeDeleteLastRecord(userId) {
  const list = await txService.listForUser(userId, { pageSize: 1 });
  if (!list.items?.length) throw ApiError.notFound('Không có giao dịch để xóa.');

  const tx = list.items[0];
  await txService.remove(userId, tx.id);

  return {
    kind: 'delete',
    transactionId: tx.id,
    amount: Number(tx.amount),
    note: tx.note,
    categoryCode: tx.categoryCode,
    message: `✅ Đã xóa giao dịch gần nhất${tx.note ? `: ${tx.note}` : ''} (${formatVnd(tx.amount)}đ).`,
  };
}

async function executeSetTone(userId, payload) {
  let style = payload.verbalStyle;
  if (!style && payload.text) {
    const t = _norm(payload.text);
    for (const [key, val] of Object.entries(TONE_MAP)) {
      if (t.includes(key)) {
        style = val;
        break;
      }
    }
    const details = payload.actionDetails || {};
    if (!style && details.style) {
      style = TONE_MAP[_norm(details.style)] || 'funny';
    }
  }
  style = style || 'funny';
  await settingsService.update(userId, { verbalStyle: style });

  const labels = { funny: 'hài hước', gentle: 'dễ thương', serious: 'nghiêm túc', sarcastic: 'châm chọc', strict: 'dạn dòi' };
  return {
    kind: 'tone',
    verbalStyle: style,
    message: `✅ Mimo sẽ nói chuyện theo giọng ${labels[style] || style}.`,
  };
}

async function executeSearch(userId, payload) {
  const q = (payload.query || payload.text || '').trim();
  const minAmount = payload.minAmount ? Number(payload.minAmount) : null;
  const categoryCode = resolveCategoryCode(payload.categoryCode, payload.actionDetails);
  const limit = Math.min(Number(payload.limit) || 5, 10);

  const values = [userId];
  let where = `t.is_deleted = FALSE
    AND t.wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)`;

  if (categoryCode) {
    values.push(categoryCode);
    where += ` AND t.category_code = $${values.length}`;
  }
  if (minAmount && minAmount > 0) {
    values.push(minAmount);
    where += ` AND t.amount >= $${values.length}`;
  }
  if (q) {
    values.push(`%${q.slice(0, 80)}%`);
    where += ` AND (t.note ILIKE $${values.length} OR t.category_code ILIKE $${values.length})`;
  }

  values.push(limit);
  const r = await query(
    `SELECT t.id, t.amount, t.note, t.category_code, t.occurred_at, t.type
     FROM transactions t
     WHERE ${where}
     ORDER BY t.occurred_at DESC
     LIMIT $${values.length}`,
    values
  );

  const items = r.rows.map((row) => ({
    id: row.id,
    amount: Number(row.amount),
    note: row.note,
    categoryCode: row.category_code,
    type: row.type,
    occurredAt: row.occurred_at,
  }));

  return {
    kind: 'search',
    items,
    total: items.length,
    message:
      items.length > 0
        ? `🔍 Tìm thấy ${items.length} giao dịch phù hợp.`
        : '🔍 Không tìm thấy giao dịch nào phù hợp.',
  };
}

async function executeAction(userId, payload) {
  const type = String(payload.actionType || '').toUpperCase();

  if (isReportAction(type)) {
    return executeReport(userId, payload);
  }
  if (type.includes('LIMIT') || type === 'SET_LIMIT') {
    return executeSetLimit(userId, payload);
  }
  if (type.includes('GOAL')) {
    return executeSetGoal(userId, payload);
  }
  if (type.includes('DELETE')) {
    return executeDeleteLastRecord(userId);
  }
  if (type.includes('TONE')) {
    return executeSetTone(userId, payload);
  }
  if (type.includes('SEARCH')) {
    return executeSearch(userId, payload);
  }
  if (type.includes('SUGGEST') || type === 'SUGGEST_BUDGET') {
    return executeSuggestBudget(userId, payload);
  }
  if (type === 'SETTING' || type === 'SYSTEM_SETTING') {
    return { kind: 'navigate', navigate: 'settings', message: '⚙️ Mở màn hình cài đặt.' };
  }

  throw ApiError.badRequest(`Action type chưa hỗ trợ: ${type}`);
}

async function executeSuggestBudget(userId, payload) {
  // Determine target month (default: next month)
  const now = new Date();
  const nextM = now.getMonth() + 2;
  const nextY = nextM > 12 ? now.getFullYear() + 1 : now.getFullYear();
  const targetMonth = payload.targetMonth || `${nextY}-${String(nextM > 12 ? 1 : nextM).padStart(2, '0')}`;

  // Try to get existing suggestions, generate on-demand if none
  let suggestions = await suggestionService.getSuggestions(userId, targetMonth);
  if (suggestions.length === 0) {
    await suggestionService.generateForUser(userId, targetMonth);
    suggestions = await suggestionService.getSuggestions(userId, targetMonth);
  }

  const story = suggestionService.buildSuggestionStory(suggestions, targetMonth);

  return {
    kind: 'budget_suggestion',
    targetMonth,
    suggestions: suggestions.map((s) => ({
      categoryCode: s.categoryCode,
      suggestedAmount: s.suggestedAmount,
      baseSpending: s.baseSpending,
      reason: s.reason,
    })),
    totalSuggested: suggestions.reduce((sum, s) => sum + s.suggestedAmount, 0),
    message: story,
    apply_action: { type: 'APPLY_BUDGET_SUGGESTION', targetMonth },
  };
}

function formatVnd(n) {
  return Number(n || 0).toLocaleString('vi-VN');
}

function buildReportStory(actionResult) {
  if (!actionResult) return 'Không có dữ liệu trong kỳ này.';
  const {
    period_label,
    total_expense,
    total_income,
    transaction_count,
    by_category,
    report_kind,
    report_sub_type,
    compare_percent,
    limit_amount,
    limit_progress,
    highest_transactions,
    peak_day,
    peer_benchmark,
  } = actionResult;

  if (report_kind === 'income') {
    let story = `${period_label}: tổng thu nhập ${formatVnd(total_income)}đ`;
    if (total_expense > 0) story += `, chi tiêu ${formatVnd(total_expense)}đ`;
    return story + '.';
  }
  if (report_kind === 'savings') {
    return `${period_label}: tiền gửi/rút — thu ${formatVnd(total_income)}đ, chi ${formatVnd(total_expense)}đ.`;
  }

  const periodUnit = period_label.toLowerCase().includes('tuần') ? 'tuần' : 'tháng';

  // 1. Kịch bản So sánh đồng trang lứa (Peer Comparison)
  if (report_sub_type === 'compare') {
    if (peer_benchmark) {
      const diffVal = total_expense - peer_benchmark.avg_amount;
      const diffPercent = Math.round((Math.abs(diffVal) / peer_benchmark.avg_amount) * 100);
      const comparisonWord = diffVal >= 0 ? 'cao hơn' : 'thấp hơn';
      return `Nè bạn ơi, ${period_label.toLowerCase()} bạn đã chi ${formatVnd(total_expense)}đ cho mục ${getCategoryLabelVi(peer_benchmark.target_category)} rồi đó. Trông thì bình thường nhưng con số này đang ${comparisonWord} ${diffPercent}% so với mức trung bình của nhóm ${peer_benchmark.age_group} làm nghề ${peer_benchmark.job_type} (${formatVnd(peer_benchmark.avg_amount)}đ) rồi nè! Thử tự nấu ăn nhiều hơn hoặc cân nhắc điều chỉnh lại xem sao nha!`;
    } else {
      return `${period_label}: bạn tiêu tổng cộng ${formatVnd(total_expense)}đ. Hiện tại chưa có dữ liệu nhóm tương đồng của bạn để so sánh.`;
    }
  }

  // 2. Kịch bản 2: Báo cáo Chi tiêu cao nhất
  if (report_sub_type === 'highest') {
    if (!highest_transactions || highest_transactions.length === 0) {
      return `${period_label}: không tìm thấy khoản chi tiêu nào để xếp hạng.`;
    }
    const top1 = highest_transactions[0];
    const top2 = highest_transactions[1];

    let story = `Quán quân 'đốt ví' ${period_label.toLowerCase()} gọi tên khoản: ${top1.note} hết ${formatVnd(top1.amount)}đ vào ${getVietnameseDayOfWeek(top1.occurredAt)}.`;
    if (top2) {
      story += ` Á quân là vụ ${top2.note} hết ${formatVnd(top2.amount)}đ.`;
      const combinedPercent = Math.round(((top1.amount + top2.amount) / (total_expense || 1)) * 100);
      story += ` Hai khoản này đã chiếm ${combinedPercent > 100 ? 100 : combinedPercent}% chi tiêu ${periodUnit} của bạn rồi!`;
    } else {
      const top1Percent = Math.round((top1.amount / (total_expense || 1)) * 100);
      story += ` Khoản này chiếm ${top1Percent > 100 ? 100 : top1Percent}% chi tiêu ${periodUnit} của bạn rồi!`;
    }
    return story;
  }

  // 3. Kịch bản 3: Báo cáo Chi tiêu theo chu kỳ
  if (report_sub_type === 'cycle') {
    let story = `${period_label} bạn tiêu tổng cộng ${formatVnd(total_expense)}đ.`;
    if (peak_day) {
      story += ` Nhìn chung chi tiêu các ngày khá ổn định, nhưng ${peak_day.day_of_week} bùng nổ nhất với hơn ${formatVnd(peak_day.amount)}đ cho ${peak_day.note || 'chi tiêu'} đấy nhé!`;
    } else {
      story += ` Chi tiêu các ngày trong tuần diễn ra đều đặn.`;
    }
    return story;
  }

  // 4. Kịch bản 1: Báo cáo Tổng chi tiêu (General)
  let story = `Tính đến hôm nay, bạn đã tiêu tổng cộng ${formatVnd(total_expense)}đ rồi nè.`;
  
  if (compare_percent !== 0) {
    story += ` Tốc độ tiêu xài đang ${compare_percent >= 0 ? 'nhanh' : 'chậm'} hơn ${Math.abs(compare_percent)}% so với cùng kỳ ${periodUnit} trước đó nha`;
  } else {
    story += ` Tốc độ tiêu xài tương đương cùng kỳ ${periodUnit} trước đó nha`;
  }

  if (limit_amount) {
    story += `, đã chạm mức ${limit_progress}% của hạn mức tháng (${formatVnd(limit_amount)}đ)`;
  }
  story += `. Tém tém lại thôi!`;
  return story;
}

function detectReportKind(text, actionType) {
  const t = _norm(text || '');
  const upper = String(actionType || '').toUpperCase();
  if (upper.includes('INCOME') || /\b(tong thu nhap|thu nhap|tong thu)\b/.test(t)) return 'income';
  if (upper.includes('SAVING') || /\b(tien gui|tong tien gui|gui tien|tien rut|tong tien rut|rut tien)\b/.test(t)) return 'savings';
  return 'expense';
}

function buildActionSignature(actionType, extra = {}) {
  const type = String(actionType || 'UNKNOWN').toUpperCase();
  if (extra.granularity) return `${type}|${extra.granularity}`;
  if (type.includes('LIMIT')) return `${type}|${extra.categoryCode || 'all'}|${extra.amount || 0}`;
  if (type.includes('DELETE')) return `${type}|last`;
  if (type.includes('GOAL')) return `${type}|${extra.amount || 0}`;
  if (type.includes('SEARCH')) return `${type}|${extra.query || 'all'}`;
  if (type.includes('TONE')) return `${type}|${extra.verbalStyle || 'any'}`;
  return `${type}|default`;
}

function needsConfirm(actionType) {
  const t = String(actionType || '').toUpperCase();
  if (t.includes('REPORT')) return false;
  if (t.includes('SUGGEST')) return false;
  if (t === 'SETTING' || t === 'SYSTEM_SETTING') return false;
  return (
    t.includes('LIMIT') ||
    t.includes('DELETE') ||
    t.includes('GOAL') ||
    t.includes('TONE') ||
    t.includes('SEARCH')
  );
}

function actionPreviewLabel(actionType, { amount, categoryCode } = {}) {
  const t = String(actionType || '').toUpperCase();
  const amt = amount ? `${formatVnd(amount)}đ` : null;
  const cat = categoryCode || null;
  if (t.includes('SUGGEST')) return 'Gợi ý hạn mức thông minh';
  if (t.includes('LIMIT')) return `Đặt hạn mức${cat ? ` ${cat}` : ''}${amt ? `: ${amt}` : ''}`;
  if (t.includes('DELETE')) return 'Xóa giao dịch gần nhất';
  if (t.includes('GOAL')) return `Tạo mục tiêu${amt ? ` ${amt}` : ''}`;
  if (t.includes('TONE')) return 'Đổi giọng nói Mimo';
  if (t.includes('SEARCH')) return 'Tìm kiếm giao dịch';
  if (t.includes('SETTING')) return 'Mở cài đặt';
  return actionType;
}

module.exports = {
  isReportAction,
  inferTimeRangeFromText,
  executeReport,
  executeSetLimit,
  executeSetGoal,
  executeDeleteLastRecord,
  executeSetTone,
  executeSearch,
  executeSuggestBudget,
  executeAction,
  buildReportStory,
  detectReportKind,
  buildActionSignature,
  needsConfirm,
  actionPreviewLabel,
  resolveCategoryCode,
  resolveAmount,
};
