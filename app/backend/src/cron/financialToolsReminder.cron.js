'use strict';

const cron = require('node-cron');
const { query } = require('../config/db');
const { dispatchUserNotification } = require('../services/notificationDispatch');
const logger = require('../config/logger');

function formatMoney(amount) {
  return Number(amount || 0).toLocaleString('vi-VN');
}

function formatDate(dateVal) {
  if (!dateVal) return '';
  const d = new Date(dateVal);
  return `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
}

/**
 * Kiểm tra và gửi thông báo cho Tiết kiệm, Thử thách, Vay mượn
 */
async function runFinancialToolsReminders() {
  const stats = {
    savingAlerts: 0,
    challengeAlerts: 0,
    loanAlerts: 0,
  };

  try {
    // -------------------------------------------------------------------------
    // 1. NHẮC NHỞ TIẾT KIỆM & THỬ THÁCH SẮP ĐẾN HẠN HOẶC ĐẾN HẠN
    // -------------------------------------------------------------------------
    const goalsRes = await query(`
      SELECT g.*,
             COALESCE(g.type, 'personal') as goal_type
      FROM goals g
      WHERE g.status = 'active'
        AND g.deadline IS NOT NULL
        AND g.deadline >= CURRENT_DATE
        AND g.deadline <= CURRENT_DATE + INTERVAL '7 days'
    `);

    for (const goal of goalsRes.rows) {
      const isChallenge = goal.goal_type === 'challenge';
      const daysLeft = Math.round((new Date(goal.deadline) - new Date()) / (1000 * 60 * 60 * 24));

      // Chỉ thông báo vào các mốc: 7 ngày, 3 ngày, 1 ngày, hoặc 0 ngày (đúng hạn)
      if (![7, 3, 1, 0].includes(daysLeft)) continue;

      const target = Number(goal.target_amount) || 1;
      const current = Number(goal.current_amount) || 0;
      const pct = Math.min(100, Math.round((current / target) * 100));

      if (isChallenge) {
        // Gửi thông báo cho tất cả thành viên trong thử thách
        const membersRes = await query(`
          SELECT gm.*, u.id as user_id
          FROM goal_members gm
          JOIN users u ON gm.user_id = u.id
          WHERE gm.goal_id = $1
        `, [goal.id]);

        for (const m of membersRes.rows) {
          const myAmount = Number(m.current_amount || 0);
          const myPct = Math.min(100, Math.round((myAmount / target) * 100));
          const timeText = daysLeft === 0 ? 'hôm nay' : `còn ${daysLeft} ngày nữa`;
          const title = `Thử thách tiết kiệm sắp kết thúc 🏁`;
          const message = `Thử thách "${goal.name}" sẽ kết thúc ${timeText} (${formatDate(goal.deadline)}). Bạn đã đạt ${myPct}% (${formatMoney(myAmount)}đ). Hãy bứt phá ngay!`;

          await dispatchUserNotification(m.user_id, {
            type: 'CHALLENGE_REMINDER',
            payload: {
              title,
              message,
              deepLink: `/app/goals/${goal.id}`,
            },
          }).catch((err) => {
            logger.error({ err: err.message, userId: m.user_id }, 'Failed sending challenge reminder');
          });
          stats.challengeAlerts++;
        }
      } else {
        // Tiết kiệm cá nhân / nhóm tiết kiệm
        const timeText = daysLeft === 0 ? 'hôm nay' : `còn ${daysLeft} ngày nữa`;
        const title = `Mục tiêu tiết kiệm sắp đến hạn 🎯`;
        const message = `Mục tiêu "${goal.name}" đến hạn ${timeText} (${formatDate(goal.deadline)}). Tiến độ hiện tại: ${pct}% (${formatMoney(current)} / ${formatMoney(target)}đ).`;

        await dispatchUserNotification(goal.user_id, {
          type: 'GOAL_REMINDER',
          payload: {
            title,
            message,
            deepLink: `/app/goals/${goal.id}`,
          },
        }).catch((err) => {
          logger.error({ err: err.message, userId: goal.user_id }, 'Failed sending goal reminder');
        });
        stats.savingAlerts++;
      }
    }

    // -------------------------------------------------------------------------
    // 2. NHẮC NHỞ KHOẢN VAY / MƯỢN (LOANS)
    // -------------------------------------------------------------------------
    const loansRes = await query(`
      SELECT l.*, u.id as user_id
      FROM loans l
      JOIN users u ON l.user_id = u.id
      WHERE l.status = 'active'
        AND l.paid_amount < l.amount
        AND (
          (l.due_date >= CURRENT_DATE AND l.due_date <= CURRENT_DATE + INTERVAL '2 days')
          OR (l.reminder_date IS NOT NULL AND l.reminder_date::date = CURRENT_DATE AND l.is_reminded = FALSE)
        )
    `);

    for (const loan of loansRes.rows) {
      const typeLabel = loan.type === 'lend' ? 'thu nợ' : 'trả nợ';
      const remaining = Number(loan.amount - loan.paid_amount);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const due = new Date(loan.due_date);
      due.setHours(0, 0, 0, 0);
      const diffDays = Math.round((due - today) / (1000 * 60 * 60 * 24));

      const isDueToday = diffDays === 0;
      const isDueTomorrow = diffDays === 1;

      const title = isDueToday
          ? `Đến hạn ${typeLabel} hôm nay 🔔`
          : isDueTomorrow
          ? `Sắp đến hạn ${typeLabel} ngày mai ⏳`
          : `Sắp đến hạn ${typeLabel} (còn 2 ngày) ⏳`;
      const timeStr = isDueToday ? 'hôm nay' : isDueTomorrow ? 'vào ngày mai' : 'sau 2 ngày nữa';
      const message = `Khoản ${typeLabel} với ${loan.contact_name || 'người liên hệ'} số tiền ${formatMoney(remaining)}đ sẽ đến hạn ${timeStr} (${formatDate(loan.due_date)}).`;

      await dispatchUserNotification(loan.user_id, {
        type: 'LOAN_REMINDER',
        payload: {
          title,
          message,
          deepLink: '/app/settings',
        },
      }).catch((err) => {
        logger.error({ err: err.message, userId: loan.user_id }, 'Failed sending loan reminder');
      });

      if (loan.reminder_date && !loan.is_reminded) {
        await query(`UPDATE loans SET is_reminded = TRUE WHERE id = $1`, [loan.id]).catch(() => {});
      }

      stats.loanAlerts++;
    }

    logger.info(stats, 'Finished running financial tools reminders');
  } catch (err) {
    logger.error({ err: err.message }, 'Error in runFinancialToolsReminders');
  }

  return stats;
}

function initFinancialToolsReminderCron() {
  // Chạy lúc 08:00 mỗi ngày
  cron.schedule('0 8 * * *', async () => {
    logger.info('Running daily financial tools reminder cron');
    await runFinancialToolsReminders();
  });
}

module.exports = {
  initFinancialToolsReminderCron,
  runFinancialToolsReminders,
};
