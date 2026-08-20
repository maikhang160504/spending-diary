'use strict';

const cron = require('node-cron');
const { query } = require('../config/db');
const { dispatchUserNotification } = require('../services/notificationDispatch');
const logger = require('../config/logger');

/**
 * Logic Notification:
 * - Chạy vào lúc 20:00 hằng ngày (cron: '0 20 * * *').
 * - Truy vấn danh sách các user chưa phát sinh bất kỳ giao dịch (transaction) nào trong ngày hiện tại.
 * - Gửi thông báo (Push Notification / FCM / WebSocket) nhắc nhở user nhập chi tiêu qua hàm dispatchUserNotification.
 */
async function runDailyExpenseReminder() {
  logger.info('Running daily expense reminder cronjob');

  // Query tìm các user KHÔNG có giao dịch nào được tạo vào ngày hôm nay (giờ VN)
  const res = await query(`
    SELECT u.id as user_id, u.username
    FROM users u
    WHERE u.is_active = true
      AND NOT EXISTS (
        SELECT 1
        FROM transactions t
        JOIN wallets w ON t.wallet_id = w.id
        JOIN wallet_members wm ON w.id = wm.wallet_id
        WHERE wm.user_id = u.id
          AND t.is_deleted = false
          AND (t.is_draft = false OR t.is_draft IS NULL)
          AND (t.occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
      )
  `);

  if (res.rowCount === 0) {
    logger.info('Tất cả user active đều đã nhập chi tiêu hôm nay.');
    return { sent: 0 };
  }
  logger.info(`Có ${res.rowCount} user chưa nhập chi tiêu hôm nay.`);

  let sentCount = 0;
  for (const user of res.rows) {
    const title = 'Đừng quên ghi chép chi tiêu nhé!';
    const message = `Chào ${user.username || 'bạn'}, hôm nay bạn chưa ghi chép khoản chi tiêu nào. Hãy dành 1 phút cập nhật để SpendAI giúp bạn quản lý tài chính tốt hơn nhé!`;

    await dispatchUserNotification(user.user_id, {
      type: 'DAILY_EXPENSE_REMINDER',
      payload: {
        title,
        message,
        deepLink: '/app/transactions/create',
      },
    }).catch((err) => {
      logger.error({ err: err.message, userId: user.user_id }, 'Lỗi khi gửi push notification nhắc nhập chi tiêu');
    });
    sentCount++;
  }
  return { sent: sentCount };
}

function initDailyExpenseReminderCron() {
  cron.schedule('0 20 * * *', async () => {
    try {
      await runDailyExpenseReminder();
    } catch (err) {
      logger.error({ err: err.message }, 'Error in dailyExpenseReminder cronjob');
    }
  });
}

module.exports = {
  initDailyExpenseReminderCron,
  runDailyExpenseReminder,
};

