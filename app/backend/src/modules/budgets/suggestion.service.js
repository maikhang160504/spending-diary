'use strict';

const { query, withTransaction } = require('../../config/db');
const budgetsService = require('./budgets.service');

// ── Canonical Category Mapping ──────────────────────────────────────────────
function canonicalCategoryCode(code) {
  if (!code) return 'Other';
  const clean = String(code).trim();
  const lower = clean.toLowerCase();
  if (lower === 'food & drink' || lower === 'food' || lower === 'ăn uống') return 'Food';
  if (lower === 'transportation' || lower === 'transport' || lower === 'di chuyển') return 'Transport';
  if (lower === 'shopping & services' || lower === 'shopping' || lower === 'mua sắm') return 'Shopping';
  if (lower === 'entertainment' || lower === 'giải trí') return 'Entertainment';
  if (lower === 'housing & utilities' || lower === 'housing' || lower === 'nhà ở' || lower === 'nhà ở / hóa đơn') return 'Housing';
  if (lower === 'essentials' || lower === 'nhu yếu phẩm') return 'Essentials';
  if (lower === 'health' || lower === 'y tế') return 'Health';
  if (lower === 'education' || lower === 'giáo dục') return 'Education';
  if (lower === 'social' || lower === 'quà tặng' || lower === 'quà tặng / xã hội') return 'Social';
  if (lower === 'beauty' || lower === 'làm đẹp') return 'Beauty';
  if (lower === 'other' || lower === 'others' || lower === 'khác') return 'Other';
  return clean;
}

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

function normalizeMonth(monthStr) {
  if (!monthStr || typeof monthStr !== 'string') {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    return `${y}-${m}`;
  }
  const clean = monthStr.trim();
  const match = clean.match(/^(\d{4})-(\d{1,2})/);
  if (match) {
    const y = match[1];
    const m = match[2].padStart(2, '0');
    return `${y}-${m}`;
  }
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

function getHolidayFactor(targetMonth) {
  const norm = normalizeMonth(targetMonth);
  const m = parseInt(norm.split('-')[1], 10);
  return HOLIDAY_FACTORS[m] || 1.00;
}

/**
 * Hệ số mùa vụ cụ thể từng danh mục theo đặc thù sự kiện của tháng.
 * Tránh tăng bừa bãi các danh mục không liên quan (ví dụ tháng 9 chỉ tăng Education/Essentials, không tăng Entertainment).
 */
function getCategoryHolidayFactor(categoryCode, targetMonth) {
  const norm = normalizeMonth(targetMonth);
  const m = parseInt(norm.split('-')[1], 10);
  const cat = canonicalCategoryCode(categoryCode);

  // Tháng 1, 2: Tết Nguyên Đán
  if (m === 1 || m === 2) {
    if (cat === 'Shopping' || cat === 'Social') return 1.30;
    if (cat === 'Food' || cat === 'Entertainment') return 1.15;
    return 1.00;
  }
  // Tháng 3: Sau Tết (thắt lưng buộc bụng)
  if (m === 3) {
    if (cat === 'Shopping' || cat === 'Social' || cat === 'Entertainment') return 0.90;
    return 1.00;
  }
  // Tháng 9: Tựu trường / Khai giảng (chỉ áp dụng sách vở, học phí, đồng phục)
  if (m === 9) {
    if (cat === 'Education') return 1.25;
    if (cat === 'Essentials') return 1.10;
    return 1.00;
  }
  // Tháng 12: Giáng sinh / Tết Dương lịch
  if (m === 12) {
    if (cat === 'Shopping' || cat === 'Social') return 1.20;
    if (cat === 'Entertainment' || cat === 'Food') return 1.10;
    return 1.00;
  }

  return 1.00;
}

/**
 * Làm tròn chuẩn số tiền VND đến hàng chục nghìn (10.000đ) cho hạn mức ngân sách:
 * Ví dụ: 765.801đ -> 770.000đ, 377.047đ -> 380.000đ, 339.500đ -> 340.000đ, 2.165.466đ -> 2.170.000đ
 */
function roundToStandardVnd(amount) {
  if (!amount || amount <= 0) return 50000;
  const num = Math.round(Number(amount));
  return Math.max(10000, Math.round(num / 10000) * 10000);
}

function getSavingRate(categoryCode, peerExceeded) {
  const cat = canonicalCategoryCode(categoryCode);
  if (ESSENTIAL_CATEGORIES.has(cat)) return 0.00;
  if (!DISCRETIONARY_CATEGORIES.has(cat)) return 0.00;
  // Nếu user vượt peer benchmark → cắt 10%, không vượt → cắt 5%
  return peerExceeded ? 0.10 : 0.05;
}

function isHolidayMonth(monthStr) {
  const norm = normalizeMonth(monthStr);
  const m = parseInt(norm.split('-')[1], 10);
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
 * Generate the 3 historical months relative to targetMonth.
 * Luôn bao gồm tháng hiện tại (month 0) để lấy số liệu chi tiêu thực tế mới nhất.
 */
function getPrev3Months(targetMonth) {
  const norm = normalizeMonth(targetMonth);
  const [y, m] = norm.split('-').map(Number);
  const now = new Date();
  const currentMonthStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  let baseYear = y;
  let baseMonth = m;
  if (norm >= currentMonthStr) {
    const [cy, cm] = currentMonthStr.split('-').map(Number);
    baseYear = cy;
    baseMonth = cm;
  }

  const months = [];
  months.push(`${baseYear}-${String(baseMonth).padStart(2, '0')}`);

  for (let i = 1; i <= 2; i++) {
    const d = new Date(Date.UTC(baseYear, baseMonth - 1 - i, 1));
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
  const norm = normalizeMonth(monthStr);
  const [y, m] = norm.split('-').map(Number);
  const fromDate = new Date(Date.UTC(y, m - 1, 1));
  const toDate = new Date(Date.UTC(y, m, 1)); // exclusive end
  const from = !isNaN(fromDate.getTime()) ? fromDate.toISOString() : new Date().toISOString();
  const to = !isNaN(toDate.getTime()) ? toDate.toISOString() : new Date().toISOString();
  return { from, to };
}

// ── Core Algorithm ───────────────────────────────────────────────────

/**
 * Fetch monthly category spending for a user in a given month.
 * Với tháng hiện tại (isCurrentMonth = true), LUÔN LUÔN query trực tiếp bảng transactions để lấy số liệu mới nhất.
 * Với các tháng trước, ưu tiên đọc từ budget_monthly_snapshots, fallback về transactions.
 * Returns Map<categoryCode, { total, amounts: number[] }>
 */
async function fetchMonthlySpending(userId, monthStr, isCurrentMonth = false) {
  if (!isCurrentMonth) {
    const snapshotRes = await query(
      `SELECT category_code, amount_limit, spent
       FROM budget_monthly_snapshots
       WHERE user_id = $1 AND month = $2`,
      [userId, monthStr]
    );

    if (snapshotRes.rows.length > 0) {
      const map = new Map();
      for (const row of snapshotRes.rows) {
        const cat = canonicalCategoryCode(row.category_code);
        const spent = Number(row.spent);
        if (spent > 0) {
          map.set(cat, { total: spent, amounts: [spent], limit: Number(row.amount_limit || 0) });
        }
      }
      if (map.size > 0) return map;
    }
  }

  // Fallback hoặc tháng hiện tại: query trực tiếp từ transactions
  const { from, to } = monthRange(monthStr);
  const r = await query(
    `SELECT category_code, amount::numeric
     FROM transactions t
     WHERE t.is_deleted = FALSE
       AND t.type = 'expense'
       AND (t.is_draft = FALSE OR t.is_draft IS NULL)
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
    const cat = canonicalCategoryCode(row.category_code);
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
       AND (t.is_draft = FALSE OR t.is_draft IS NULL)
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
 */
function denoiseCategory(categoryCode, amounts, monthStr) {
  if (amounts.length < 3) {
    return amounts.reduce((a, b) => a + b, 0);
  }

  const cat = canonicalCategoryCode(categoryCode);
  const holiday = isHolidayMonth(monthStr);
  if (holiday && (cat === 'Shopping' || cat === 'Social')) {
    return amounts.reduce((a, b) => a + b, 0);
  }

  const mean = amounts.reduce((a, b) => a + b, 0) / amounts.length;
  const sd = stddev(amounts);
  const threshold = mean + 3 * sd;

  let total = 0;
  for (const a of amounts) {
    if (a <= threshold || sd === 0) {
      total += a;
    }
  }
  return total;
}

/**
 * Step 2: Compute base spending using Weighted Moving Average.
 * monthlyTotals: [month0_current, month1_prev, month2_prev2]
 */
function computeBaseSpending(monthlyTotals) {
  const available = monthlyTotals.filter((v) => v !== null && v !== undefined && typeof v === 'number');
  if (available.length === 0) return null;

  const m0 = available[0] || 0;
  const m1 = available[1] || 0;
  const m2 = available[2] || 0;

  if (m0 === 0 && m1 === 0 && m2 === 0) return 0;

  if (m0 > 0) {
    if (m1 > 0 && m2 > 0) return m0 * 0.5 + m1 * 0.3 + m2 * 0.2;
    if (m1 > 0) return m0 * 0.65 + m1 * 0.35;
    return m0;
  }

  // Nếu tháng hiện tại chi tiêu = 0, lấy trung bình quá khứ có điều chỉnh giảm phản ánh xu hướng
  if (m1 > 0 && m2 > 0) return (m1 * 0.6 + m2 * 0.4) * 0.7;
  if (m1 > 0) return m1 * 0.7;
  return 0;
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
 * Step 2c: Budget Variance Calibration (Điều chỉnh theo lịch sử hạn mức tháng trước).
 */
function computeVarianceAdjustment(lastMonthSpent, lastMonthLimit, isFixedCost = false) {
  if (!lastMonthLimit || lastMonthLimit <= 0) {
    return { adjustment: 0, reasonText: null, variance: 0 };
  }

  const variance = lastMonthSpent - lastMonthLimit;
  if (variance === 0) {
    return { adjustment: 0, reasonText: null, variance: 0 };
  }

  const alpha = isFixedCost ? 0.20 : 0.35; // Hệ số điều chỉnh khi vượt hạn mức
  const beta = isFixedCost ? 0.15 : 0.25;  // Hệ số điều chỉnh khi dưới hạn mức

  if (variance > 0) {
    const adjustment = Math.round(variance * alpha);
    return {
      adjustment,
      variance,
      reasonText: `tăng ${formatVnd(adjustment)}đ do vượt hạn mức tháng trước (${formatVnd(lastMonthSpent)}đ/${formatVnd(lastMonthLimit)}đ)`,
    };
  } else {
    const adjustment = Math.round(variance * beta);
    return {
      adjustment,
      variance,
      reasonText: `giảm ${formatVnd(Math.abs(adjustment))}đ do chi tiêu dưới hạn mức tháng trước (${formatVnd(lastMonthSpent)}đ/${formatVnd(lastMonthLimit)}đ)`,
    };
  }
}

/**
 * Main: Compute suggestions for a single user.
 * Tính toán chính xác dựa trên số đã chi, tình trạng vượt/tiết kiệm ngân sách tháng hiện tại.
 */
async function computeSuggestionsForUser(userId, targetMonth) {
  const normTarget = normalizeMonth(targetMonth);
  const prevMonths = getPrev3Months(normTarget);
  const baseHolidayFactor = getHolidayFactor(normTarget);

  // Fetch spending data for 3 historical months (month 0 is current month)
  const monthlyData = [];
  for (let i = 0; i < prevMonths.length; i++) {
    const m = prevMonths[i];
    const isCurrent = (i === 0);
    const data = await fetchMonthlySpending(userId, m, isCurrent);
    monthlyData.push({ month: m, data });
  }

  // Fetch user's active budgets and map by canonical code
  const activeBudgets = await budgetsService.list(userId);
  const activeBudgetLimitMap = new Map();
  for (const b of activeBudgets) {
    if (b.categoryCode) {
      const canonical = canonicalCategoryCode(b.categoryCode);
      activeBudgetLimitMap.set(canonical, Number(b.amountLimit));
      activeBudgetLimitMap.set(b.categoryCode, Number(b.amountLimit));
    }
  }

  // Collect all active categories or categories with current month spending
  const allCats = new Set();
  for (const b of activeBudgets) {
    if (b.categoryCode && b.categoryCode !== '__TOTAL__') {
      allCats.add(canonicalCategoryCode(b.categoryCode));
    }
  }
  const currentMonthData = monthlyData[0]?.data;
  if (currentMonthData) {
    for (const [cat, val] of currentMonthData.entries()) {
      if (val && val.total > 0) {
        allCats.add(canonicalCategoryCode(cat));
      }
    }
  }

  // Fallback if no data and no active budgets
  if (allCats.size === 0) {
    const fallback = await computeFallbackFromPeer(userId, normTarget, baseHolidayFactor);
    return fallback.map(s => ({
      ...s,
      suggested_amount: roundToStandardVnd(s.suggested_amount),
      base_spending: roundToStandardVnd(s.base_spending),
    }));
  }

  const rawSuggestions = [];

  for (const cat of allCats) {
    // Collect denoised totals for each of the 3 months
    const totals = prevMonths.map((m, i) => {
      const catData = monthlyData[i].data.get(cat);
      if (!catData) return 0;
      return denoiseCategory(cat, catData.amounts, m);
    });

    const currentSpent = totals[0] || 0; // Chi tiêu thực tế tháng hiện tại
    const baseAvg = computeBaseSpending(totals) || 0; // Chi tiêu trung bình
    const currentLimit = activeBudgetLimitMap.get(cat) || 0; // Hạn mức đang đặt tháng này
    const catHolidayFactor = getCategoryHolidayFactor(cat, normTarget);

    let rawSuggested = 0;
    let reason = '';
    const roundedCurrentSpent = roundToStandardVnd(currentSpent);
    const roundedLimit = roundToStandardVnd(currentLimit);

    if (currentLimit > 0) {
      // ═══════════════════════════════════════════════════════════════════════
      // TRƯỜNG HỢP 1: DANH MỤC ĐÃ CÓ HẠN MỨC ĐANG HOẠT ĐỘNG
      // ═══════════════════════════════════════════════════════════════════════
      if (currentSpent > currentLimit) {
        // A) VƯỢT HẠN MỨC THÁNG HIỆN TẠI (Ví dụ vượt 200%):
        const overAmount = currentSpent - currentLimit;
        const roundedOver = roundToStandardVnd(overAmount);
        const overPercent = Math.round((overAmount / currentLimit) * 100);

        // Gợi ý tăng hạn mức lên sát thực tế + 10% biên an toàn * hệ số lễ (nếu có)
        rawSuggested = Math.max(currentSpent * 1.10, currentLimit + overAmount) * catHolidayFactor;
        const finalSuggested = roundToStandardVnd(rawSuggested);

        reason = `Tháng này đã chi ${formatVnd(roundedCurrentSpent)}đ (vượt hạn mức ${formatVnd(roundedOver)}đ - ${overPercent}%), đề xuất tăng lên ${formatVnd(finalSuggested)}đ cho tháng sau để bám sát nhu cầu thực tế`;
      } else if (currentSpent > 0) {
        // B) TIÊU TRONG HẠN MỨC (0 < currentSpent <= currentLimit):
        const savedAmount = currentLimit - currentSpent;
        const roundedSaved = roundToStandardVnd(savedAmount);
        const usedRatio = currentSpent / currentLimit;

        if (usedRatio >= 0.75) {
          // Dùng sát hạn mức (75% - 100%) -> Duy trì ổn định theo hạn mức hiện tại * hệ số lễ
          rawSuggested = currentLimit * catHolidayFactor;
          const finalSuggested = roundToStandardVnd(rawSuggested);
          reason = `Tháng này đã chi ${formatVnd(roundedCurrentSpent)}đ (tiết kiệm ${formatVnd(roundedSaved)}đ so với hạn mức), duy trì hạn mức ${formatVnd(finalSuggested)}đ cho tháng sau`;
        } else {
          // Tiết kiệm rất tốt (< 75%) -> Đề xuất tối ưu hạ nhẹ hạn mức để tăng tỷ lệ tiết kiệm
          rawSuggested = Math.max(currentSpent * 1.25, currentLimit * 0.85) * catHolidayFactor;
          const finalSuggested = roundToStandardVnd(rawSuggested);
          reason = `Tháng này đã chi ${formatVnd(roundedCurrentSpent)}đ (tiết kiệm ${formatVnd(roundedSaved)}đ), đề xuất tối ưu ${formatVnd(finalSuggested)}đ cho tháng sau`;
        }
      } else {
        // C) CHƯA DÙNG ĐỒNG NÀO (currentSpent === 0):
        // KHÔNG tăng hạn mức ảo theo ngày lễ nếu không có nhu cầu sử dụng! Giữ nguyên hạn mức hiện tại.
        rawSuggested = currentLimit;
        const finalSuggested = roundToStandardVnd(rawSuggested);
        reason = `Chưa phát sinh chi tiêu tháng này, giữ nguyên hạn mức ${formatVnd(finalSuggested)}đ cho tháng sau`;
      }
    } else {
      // ═══════════════════════════════════════════════════════════════════════
      // TRƯỜNG HỢP 2: DANH MỤC CHƯA ĐẶT HẠN MỨC
      // ═══════════════════════════════════════════════════════════════════════
      if (currentSpent > 0) {
        rawSuggested = currentSpent * 1.10 * catHolidayFactor;
        const finalSuggested = roundToStandardVnd(rawSuggested);
        reason = `Chi tiêu thực tế tháng này ${formatVnd(roundedCurrentSpent)}đ, đề xuất hạn mức ${formatVnd(finalSuggested)}đ cho tháng sau`;
      } else if (baseAvg > 0) {
        const roundedAvg = roundToStandardVnd(baseAvg);
        rawSuggested = baseAvg * catHolidayFactor;
        const finalSuggested = roundToStandardVnd(rawSuggested);
        reason = `Chi tiêu trung bình ${formatVnd(roundedAvg)}đ/tháng, đề xuất hạn mức ${formatVnd(finalSuggested)}đ cho tháng sau`;
      } else {
        continue;
      }
    }

    const finalSuggestedAmount = roundToStandardVnd(rawSuggested);
    const baseSpendingDisplay = roundToStandardVnd(currentSpent > 0 ? currentSpent : (currentLimit > 0 ? currentLimit : baseAvg));

    rawSuggestions.push({
      category_code: cat,
      suggested_amount: finalSuggestedAmount,
      base_spending: baseSpendingDisplay,
      income_factor: 1.0,
      saving_rate: 0.0,
      holiday_factor: Math.round(catHolidayFactor * 100) / 100,
      reason,
    });
  }

  // Sắp xếp theo số tiền gợi ý giảm dần
  rawSuggestions.sort((a, b) => b.suggested_amount - a.suggested_amount);

  return rawSuggestions;
}

/**
 * Fallback: user has no spending history → use peer benchmarks.
 */
async function computeFallbackFromPeer(userId, targetMonth, holidayFactor) {
  const normTarget = normalizeMonth(targetMonth);
  const settingsRes = await query(
    'SELECT age_group, job_type FROM user_settings WHERE user_id = $1',
    [userId]
  );
  const rawAge = settingsRes.rows[0]?.age_group || '23-30 tuổi';
  const rawJob = settingsRes.rows[0]?.job_type || 'Văn phòng';

  // Normalize to seed group labels
  const ageGroup = rawAge.includes('tuổi') ? rawAge : `${rawAge} tuổi`;
  const jobType = (rawJob === 'office' || rawJob === 'van_phong') ? 'Văn phòng'
                : (rawJob === 'student' || rawJob === 'sinh_vien') ? 'Sinh viên'
                : (rawJob === 'freelance' || rawJob === 'freelancer') ? 'Freelancer'
                : (rawJob === 'business' || rawJob === 'kinh_doanh') ? 'Kinh doanh'
                : rawJob;

  const benchRes = await query(
    `SELECT category_id, avg_amount::numeric FROM group_spending_benchmarks
     WHERE age_group = $1 AND job_type = $2 AND period = 'month'`,
    [ageGroup, jobType]
  );

  return benchRes.rows.map(row => {
    const avg = roundToStandardVnd(Number(row.avg_amount));
    const catHolidayFactor = getCategoryHolidayFactor(row.category_id, normTarget);
    const suggested = roundToStandardVnd(avg * catHolidayFactor);
    return {
      category_code: canonicalCategoryCode(row.category_id),
      suggested_amount: suggested,
      base_spending: avg,
      income_factor: 1.0,
      saving_rate: 0.0,
      holiday_factor: catHolidayFactor,
      reason: `Dựa trên mức chi tiêu trung bình nhóm ${ageGroup} - ${jobType}`,
    };
  });
}

// ── Persistence ──────────────────────────────────────────────────────

/**
 * Save suggestions to DB (upsert).
 */
async function saveSuggestions(userId, targetMonth, suggestions) {
  const normTarget = normalizeMonth(targetMonth);
  await withTransaction(async (client) => {
    await client.query(
      `DELETE FROM user_budget_suggestions WHERE user_id = $1 AND target_month = $2`,
      [userId, normTarget]
    );
    for (const s of suggestions) {
      const cat = canonicalCategoryCode(s.category_code || s.categoryCode);
      await client.query(
        `INSERT INTO user_budget_suggestions
           (user_id, target_month, category_code, suggested_amount,
            base_spending, income_factor, saving_rate, holiday_factor, reason, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')`,
        [
          userId, normTarget, cat, s.suggested_amount,
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
  const normTarget = normalizeMonth(targetMonth);
  const r = await query(
    `SELECT * FROM user_budget_suggestions
     WHERE user_id = $1 AND target_month = $2
     ORDER BY suggested_amount DESC`,
    [userId, normTarget]
  );
  return r.rows.map((row) => ({
    id: row.id,
    categoryCode: canonicalCategoryCode(row.category_code),
    suggestedAmount: roundToStandardVnd(row.suggested_amount),
    baseSpending: roundToStandardVnd(row.base_spending),
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
  const normTarget = normalizeMonth(targetMonth);
  const suggestions = await getSuggestions(userId, normTarget);
  if (suggestions.length === 0) return { applied: 0, budgets: [] };

  const today = new Date().toISOString().slice(0, 10);
  const budgets = [];

  for (const s of suggestions) {
    const overrideVal = overrides[s.categoryCode];
    if (overrideVal === -1 || overrideVal === null || overrideVal === false) {
      continue; // Bỏ qua không áp dụng gợi ý này
    }
    const amount = overrideVal !== undefined ? Number(overrideVal) : s.suggestedAmount;
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
    [userId, normTarget]
  );

  return { applied: budgets.length, budgets };
}

/**
 * Dismiss suggestions for a month.
 */
async function dismissSuggestions(userId, targetMonth) {
  const normTarget = normalizeMonth(targetMonth);
  await query(
    `UPDATE user_budget_suggestions SET status = 'dismissed', updated_at = NOW()
     WHERE user_id = $1 AND target_month = $2`,
    [userId, normTarget]
  );
}

/**
 * Generate + save suggestions for a single user (called by batch or on-demand).
 */
async function generateForUser(userId, targetMonth) {
  const normTarget = normalizeMonth(targetMonth);
  const suggestions = await computeSuggestionsForUser(userId, normTarget);
  if (suggestions.length > 0) {
    await saveSuggestions(userId, normTarget, suggestions);
  }
  return suggestions;
}

/**
 * Batch job: generate suggestions for ALL active users.
 * Intended to run via cron or manual trigger.
 */
async function generateBatch(targetMonth) {
  const normTarget = normalizeMonth(targetMonth);
  const usersRes = await query('SELECT id FROM users');
  let count = 0;
  for (const row of usersRes.rows) {
    try {
      const suggestions = await generateForUser(row.id, normTarget);
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

  const totalSuggested = roundToStandardVnd(suggestions.reduce((s, v) => s + (v.suggestedAmount || v.suggested_amount || 0), 0));
  const totalBase = roundToStandardVnd(suggestions.reduce((s, v) => s + (v.baseSpending || v.base_spending || 0), 0));
  const diff = totalBase - totalSuggested;

  const now = new Date();
  const currentMonthStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const normTarget = normalizeMonth(targetMonth);
  const targetMonthNum = parseInt(normTarget.split('-')[1], 10);
  const monthText = normTarget === currentMonthStr ? 'tháng này' : `tháng ${targetMonthNum}`;

  let story = '';
  if (diff > 0) {
    story = `MiMo đã phân tích chi tiêu tháng này của bạn và đề xuất tổng hạn mức thông minh: ${formatVnd(totalSuggested)}đ cho ${monthText} (giúp bạn tối ưu tiết kiệm thêm ${formatVnd(diff)}đ mà vẫn thoải mái sinh hoạt 🐷).`;
  } else if (diff < 0) {
    story = `Do ${monthText} có dịp lễ / chi tiêu mùa vụ nên MiMo đã linh hoạt đề xuất ngân sách: ${formatVnd(totalSuggested)}đ (tăng ${formatVnd(Math.abs(diff))}đ để bạn thoải mái chi tiêu 🎉).`;
  } else {
    story = `MiMo gợi ý tổng hạn mức ${monthText}: ${formatVnd(totalSuggested)}đ — phù hợp với nhịp chi tiêu thực tế hiện tại 👍.`;
  }

  // Top 3 categories
  const top3 = suggestions.slice(0, 3);
  const details = top3.map((s) => `${s.categoryCode || s.category_code}: ${formatVnd(roundToStandardVnd(s.suggestedAmount || s.suggested_amount))}đ`).join(' | ');
  story += `\n\nChi tiết: ${details}`;

  story += '\n\nBạn có muốn áp dụng ngay không?';
  return story;
}

// ── Exports ──────────────────────────────────────────────────────────

module.exports = {
  // Core algorithm (exported for testing)
  canonicalCategoryCode,
  computeSuggestionsForUser,
  computeFallbackFromPeer,
  computeBaseSpending,
  computeVarianceAdjustment,
  computeIncomeFactor,
  denoiseCategory,
  getHolidayFactor,
  getCategoryHolidayFactor,
  getSavingRate,
  getPrev3Months,
  isHolidayMonth,
  stddev,
  roundToStandardVnd,
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
