'use strict';

const cron = require('node-cron');
const { query } = require('../config/db');
const { notifyUser } = require('../services/notificationDispatch');
const logger = require('../config/logger');

/**
 * Logic Notification:
 * - Chạy vào lúc 20:00 hằng ngày (cron: '0 20 * * *').
 * - Truy vấn danh sách các user chưa phát sinh bất kỳ giao dịch (transaction) nào trong ngày hiện tại.
 * - Gửi thông báo (Push Notification / FCM) nhắc nhở user nhập chi tiêu qua hàm notifyUser.
 */
function initDailyExpenseReminderCron() {
  cron.schedule('0 20 * * *', async () => {
    try {
      logger.info('Running daily expense reminder cronjob');
      
      // Query tìm các user KHÔNG có giao dịch nào được tạo vào ngày hôm nay
      const res = await query(`
        SELECT id as user_id, username
        FROM users u
        WHERE u.is_active = true
          AND NOT EXISTS (
            SELECT 1
            FROM transactions t
            JOIN wallets w ON t.wallet_id = w.id
            JOIN wallet_members wm ON w.id = wm.wallet_id
            WHERE wm.user_id = u.id
              AND DATE(t.transaction_date) = CURRENT_DATE
          )
      `);
      
      if (res.rowCount === 0) {
        logger.info('Tất cả user active đều đã nhập chi tiêu hôm nay.');
        return;
      }
      logger.info(`Có ${res.rowCount} user chưa nhập chi tiêu hôm nay.`);
      
      for (const user of res.rows) {
        const title = 'Đừng quên ghi chép chi tiêu nhé!';
        const body = `Chào ${user.username || 'bạn'}, hôm nay bạn chưa ghi chép khoản chi tiêu nào. Hãy dành 1 phút cập nhật để SpendAI giúp bạn quản lý tài chính tốt hơn nhé!`;
        
        await notifyUser(user.user_id, {
          notification: { title, body },
          data: { type: 'DAILY_EXPENSE_REMINDER' }
        }).catch(err => {
          logger.error({ err, userId: user.user_id }, 'Lỗi khi gửi push notification nhắc nhập chi tiêu');
        });
      }
    } catch (err) {
      logger.error({ err }, 'Error in dailyExpenseReminder cronjob');
    }
  });
}

module.exports = { initDailyExpenseReminderCron };
