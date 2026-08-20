'use strict';

const cron = require('node-cron');
const { query } = require('../config/db');
const { dispatchUserNotification } = require('../services/notificationDispatch');
const logger = require('../config/logger');

function initLoanReminderCron() {
  cron.schedule('0 8 * * *', async () => {
    try {
      logger.info('Running loan reminder cronjob');
      const res = await query(`
        SELECT l.*, u.id as user_id
        FROM loans l
        JOIN users u ON l.user_id = u.id
        WHERE l.status = 'active'
          AND l.due_date = CURRENT_DATE
          AND l.paid_amount < l.amount
      `);
      
      if (res.rowCount === 0) {
        logger.info('No loans due today.');
        return;
      }
      logger.info(`Found ${res.rowCount} loans due today.`);
      
      for (const loan of res.rows) {
        const typeLabel = loan.type === 'lend' ? 'thu nợ' : 'trả nợ';
        const formattedAmount = Number(loan.amount - loan.paid_amount).toLocaleString('vi-VN');
        const title = `Đến hạn ${typeLabel}`;
        const message = `Khoản vay với ${loan.contact_name || 'người vay'} số tiền ${formattedAmount}đ đã đến hạn hôm nay.`;
        
        await dispatchUserNotification(loan.user_id, {
          type: 'LOAN_REMINDER',
          payload: {
            title,
            message,
            deepLink: '/app/settings',
          },
        }).catch(err => {
          logger.error({ err: err.message, userId: loan.user_id }, 'Failed to send loan reminder push notification');
        });
      }
    } catch (err) {
      logger.error({ err: err.message }, 'Error in loanReminder cronjob');
    }
  });
}

module.exports = { initLoanReminderCron };

