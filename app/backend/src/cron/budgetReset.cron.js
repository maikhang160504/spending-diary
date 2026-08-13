'use strict';

/**
 * budgetReset.cron.js
 *
 * Hai tác vụ định kỳ liên quan đến hạn mức ngân sách hàng tháng:
 *
 * A) Đầu mỗi tháng (ngày 1, 07:00):
 *    - Snapshot hạn mức + chi tiêu tháng vừa qua vào budget_monthly_snapshots
 *    - Reset start_date của mỗi hạn mức sang đầu tháng mới
 *    - Nếu tháng trước đã áp dụng gợi ý AI → dùng amount mới, không thì giữ nguyên
 *    - Xoá snapshot cũ hơn 6 tháng
 *
 * B) Tuần cuối tháng (ngày 24, 09:00):
 *    - Gửi push notification nhắc người dùng xem gợi ý AI cho tháng sau
 *    - Chưa áp dụng ngay — chờ đến ngày 1 tháng mới
 */

const cron = require('node-cron');
const { query, withTransaction } = require('../config/db');
const { dispatchUserNotification } = require('../services/notificationDispatch');
const logger = require('../config/logger');

// ── Helpers ────────────────────────────────────────────────────────────────

function getCurrentMonthStr(now = new Date()) {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

function getPrevMonthStr(now = new Date()) {
  const d = new Date(Date.UTC(now.getFullYear(), now.getMonth() - 1, 1));
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

function getNextMonthStr(now = new Date()) {
  const d = new Date(Date.UTC(now.getFullYear(), now.getMonth() + 1, 1));
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/**
 * Tính tổng chi tiêu của một budget trong một tháng (YYYY-MM).
 */
async function computeSpentForMonth(budget, monthStr) {
  const [y, m] = monthStr.split('-').map(Number);
  const from = new Date(Date.UTC(y, m - 1, 1)).toISOString();
  const to = new Date(Date.UTC(y, m, 1)).toISOString();

  const params = [budget.user_id, from, to];
  let where = `
    t.is_deleted = FALSE
    AND t.type = 'expense'
    AND t.wallet_id IN (
      SELECT w.id FROM wallets w
      JOIN wallet_members wm ON wm.wallet_id = w.id
      WHERE wm.user_id = $1 AND w.type = 'personal'
    )
    AND t.occurred_at >= $2
    AND t.occurred_at < $3
  `;

  if (budget.category_code) {
    params.push(budget.category_code);
    where += ` AND t.category_code = $${params.length}`;
  }
  if (budget.wallet_id) {
    params.push(budget.wallet_id);
    where += ` AND t.wallet_id = $${params.length}`;
  }

  const r = await query(
    `SELECT COALESCE(SUM(amount), 0)::numeric AS spent FROM transactions t WHERE ${where}`,
    params
  );
  return Number(r.rows[0].spent);
}

// ── Tác vụ A: Reset đầu tháng ─────────────────────────────────────────────

/**
 * Snapshot và reset hạn mức ngân sách cho một user.
 * @param {string} userId
 * @param {Date} now - thời điểm hiện tại (để test có thể truyền vào)
 */
async function snapshotAndResetForUser(userId, now = new Date()) {
  const currentMonthStr = getCurrentMonthStr(now);
  const prevMonthStr = getPrevMonthStr(now);
  const nextMonthStr = getNextMonthStr(now);

  // Lấy các hạn mức tháng đang active của user
  const budgetsRes = await query(
    `SELECT * FROM budgets
     WHERE user_id = $1
       AND period = 'month'
       AND is_active = TRUE`,
    [userId]
  );

  if (budgetsRes.rows.length === 0) return { snapshots: 0, resets: 0 };

  let snapshots = 0;
  let resets = 0;

  for (const b of budgetsRes.rows) {
    // Kiểm tra đã reset tháng này chưa (start_date đã là đầu tháng hiện tại)
    const startDateStr = b.start_date ? String(b.start_date).slice(0, 7) : null;
    if (startDateStr === currentMonthStr) {
      // Đã reset tháng này rồi — bỏ qua
      continue;
    }

    // 1. Tính chi tiêu tháng trước
    const spent = await computeSpentForMonth(b, prevMonthStr);

    // 2. Kiểm tra xem tháng trước có gợi ý AI được applied không
    let newAmountLimit = Number(b.amount_limit); // mặc định giữ nguyên
    let source = 'rollover';

    if (b.category_code) {
      const sugRes = await query(
        `SELECT suggested_amount
         FROM user_budget_suggestions
         WHERE user_id = $1
           AND category_code = $2
           AND target_month = $3
           AND status = 'applied'
         LIMIT 1`,
        [userId, b.category_code, currentMonthStr]
      );
      if (sugRes.rows.length > 0) {
        newAmountLimit = Number(sugRes.rows[0].suggested_amount);
        source = 'suggestion_applied';
      }
    }

    // 3. Tạo snapshot của tháng vừa qua
    try {
      await query(
        `INSERT INTO budget_monthly_snapshots
           (user_id, budget_id, category_code, month, amount_limit, spent, source)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (user_id, category_code, month)
         DO UPDATE SET
           amount_limit = EXCLUDED.amount_limit,
           spent = EXCLUDED.spent,
           source = EXCLUDED.source`,
        [userId, b.id, b.category_code, prevMonthStr, b.amount_limit, spent, source]
      );
      snapshots++;
    } catch (err) {
      logger.warn({ err: err.message, userId, categoryCode: b.category_code }, '[BudgetReset] snapshot failed');
    }

    // 4. Reset start_date sang đầu tháng hiện tại + cập nhật amount_limit nếu đổi
    await query(
      `UPDATE budgets
       SET start_date = $1::date,
           amount_limit = $2,
           updated_at = NOW()
       WHERE id = $3`,
      [`${currentMonthStr}-01`, newAmountLimit, b.id]
    );
    resets++;
  }

  // 5. Xoá snapshots cũ hơn 6 tháng
  const sixMonthsAgo = new Date(Date.UTC(now.getFullYear(), now.getMonth() - 6, 1));
  const cutoffMonth = getCurrentMonthStr(sixMonthsAgo);
  await query(
    `DELETE FROM budget_monthly_snapshots
     WHERE user_id = $1 AND month < $2`,
    [userId, cutoffMonth]
  );

  return { snapshots, resets };
}

/**
 * Chạy reset cho tất cả users.
 */
async function runMonthlyReset(now = new Date()) {
  logger.info('[BudgetReset] Starting monthly budget reset...');
  const usersRes = await query(`SELECT id FROM users WHERE is_deleted = FALSE OR is_deleted IS NULL`);
  let totalSnapshots = 0;
  let totalResets = 0;
  let errors = 0;

  for (const row of usersRes.rows) {
    try {
      const result = await snapshotAndResetForUser(row.id, now);
      totalSnapshots += result.snapshots;
      totalResets += result.resets;
    } catch (err) {
      errors++;
      logger.error({ err: err.message, userId: row.id }, '[BudgetReset] Error resetting user budgets');
    }
  }

  logger.info({ totalSnapshots, totalResets, errors }, '[BudgetReset] Monthly reset completed');
  return { totalSnapshots, totalResets, errors };
}

// ── Tác vụ B: Nhắc nhở tuần cuối tháng ───────────────────────────────────

/**
 * Gửi thông báo đến người dùng có hạn mức đang active để họ biết dùng gợi ý AI.
 */
async function runLastWeekReminder(now = new Date()) {
  logger.info('[BudgetReset] Running last-week-of-month budget reminder...');
  const nextMonth = getNextMonthStr(now);

  // Lấy danh sách users có hạn mức tháng đang active
  const usersRes = await query(
    `SELECT DISTINCT b.user_id
     FROM budgets b
     WHERE b.period = 'month'
       AND b.is_active = TRUE`
  );

  let notified = 0;

  for (const row of usersRes.rows) {
    try {
      // Đếm số hạn mức đang active
      const countRes = await query(
        `SELECT COUNT(*)::int AS cnt FROM budgets
         WHERE user_id = $1 AND period = 'month' AND is_active = TRUE`,
        [row.user_id]
      );
      const budgetCount = countRes.rows[0]?.cnt || 0;
      if (budgetCount === 0) continue;

      await dispatchUserNotification(row.user_id, {
        type: 'BUDGET_LAST_WEEK_REMINDER',
        payload: {
          title: '📊 Gợi ý ngân sách tháng tới đã sẵn sàng!',
          message: `Còn vài ngày nữa là sang tháng mới. Mimo đã phân tích ${budgetCount} hạn mức của bạn và sẵn sàng đề xuất ngân sách tháng ${nextMonth}. Xem ngay để chuẩn bị trước nhé!`,
          deepLink: '/limits',
        },
      });
      notified++;
    } catch (err) {
      logger.warn({ err: err.message, userId: row.user_id }, '[BudgetReset] Failed to send last-week reminder');
    }
  }

  logger.info({ notified }, '[BudgetReset] Last-week reminder completed');
  return { notified };
}

// ── Khởi tạo Cron ─────────────────────────────────────────────────────────

function initBudgetResetCron() {
  // A) Đầu tháng: chạy lúc 07:00 ngày 1 hàng tháng
  cron.schedule('0 7 1 * *', async () => {
    logger.info('[BudgetReset] Cron triggered: monthly reset (day 1)');
    try {
      await runMonthlyReset();
    } catch (err) {
      logger.error({ err: err.message }, '[BudgetReset] Monthly reset cron failed');
    }
  });

  // B) Tuần cuối: chạy lúc 09:00 ngày 24 hàng tháng
  cron.schedule('0 9 24 * *', async () => {
    logger.info('[BudgetReset] Cron triggered: last-week reminder (day 24)');
    try {
      await runLastWeekReminder();
    } catch (err) {
      logger.error({ err: err.message }, '[BudgetReset] Last-week reminder cron failed');
    }
  });

  logger.info('[BudgetReset] Cron jobs registered: monthly reset (day 1) + last-week reminder (day 24)');
}

module.exports = {
  initBudgetResetCron,
  runMonthlyReset,
  runLastWeekReminder,
  snapshotAndResetForUser, // exported for testing
};
