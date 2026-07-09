'use strict';

const { pool } = require('../../config/db');
const logger = require('../../config/logger');
const txService = require('../transactions/transactions.service');
const { dispatchUserNotification } = require('../../services/notificationDispatch');

function calculateNextOccurrence(currentDateStr, frequency) {
  const date = new Date(currentDateStr);
  if (frequency === 'daily') {
    date.setUTCDate(date.getUTCDate() + 1);
  } else if (frequency === 'weekly') {
    date.setUTCDate(date.getUTCDate() + 7);
  } else if (frequency === 'monthly') {
    date.setUTCMonth(date.getUTCMonth() + 1);
  }
  return date.toISOString();
}

async function checkAndProcessRecurring() {
  logger.debug('[Recurring Scheduler] Running check...');
  const client = await pool.connect();
  try {
    // 1. Get all active rules that are due
    const rulesRes = await client.query(
      `SELECT * FROM recurring_rules 
       WHERE is_active = TRUE 
         AND next_occurrence <= NOW()`
    );

    if (rulesRes.rows.length === 0) {
      return;
    }

    logger.info(`[Recurring Scheduler] Found ${rulesRes.rows.length} due recurring rules.`);

    for (const rule of rulesRes.rows) {
      try {
        logger.info({ ruleId: rule.id }, '[Recurring Scheduler] Processing rule');

        // Create transaction payload
        const payload = {
          walletId: rule.wallet_id,
          amount: Number(rule.amount),
          type: rule.type,
          categoryCode: rule.category_code,
          note: rule.note || 'Giao dịch định kỳ',
          source: 'recurring',
          occurredAt: new Date(rule.next_occurrence).toISOString(),
          isDraft: false,
        };

        // 2. Create actual transaction via txService (which wraps story and budget checks)
        await txService.create(rule.user_id, payload);

        // 3. Compute next occurrence date
        const newNext = calculateNextOccurrence(rule.next_occurrence, rule.frequency);

        // 4. Update the rule next occurrence
        await client.query(
          `UPDATE recurring_rules 
           SET next_occurrence = $1::timestamptz, updated_at = NOW() 
           WHERE id = $2`,
          [newNext, rule.id]
        );

        // 5. Send WebSocket real-time notification + Push Notification
        const isExpense = rule.type === 'expense';
        const amountStr = `${isExpense ? '-' : '+'}${Number(rule.amount).toLocaleString('vi-VN')} đ`;
        const description = rule.note || rule.category_code || 'Giao dịch định kỳ';
        
        await dispatchUserNotification(rule.user_id, {
          type: 'RECURRING_ALERT',
          payload: {
            title: isExpense
                ? 'Giao dịch chi tiêu định kỳ tự động 💸'
                : 'Giao dịch thu nhập định kỳ tự động 💰',
            message: `Hệ thống đã tự động ghi nhận khoản ${isExpense ? 'chi' : 'thu'} "${description}" trị giá ${amountStr} vào ví của bạn.`,
            deepLink: '/',
          },
        });

        logger.info({ ruleId: rule.id, newNext }, '[Recurring Scheduler] Rule processed successfully');
      } catch (err) {
        logger.error({ ruleId: rule.id, err: err.stack || err.message }, '[Recurring Scheduler] Error processing rule');
      }
    }
  } catch (err) {
    logger.error({ err: err.stack || err.message }, '[Recurring Scheduler] Check failed');
  } finally {
    client.release();
  }
}

let _intervalId = null;

function startScheduler(intervalMs = 3600000) { // Run every hour by default
  if (_intervalId) return;
  
  // Run once immediately on start
  setImmediate(checkAndProcessRecurring);
  
  _intervalId = setInterval(checkAndProcessRecurring, intervalMs);
  logger.info(`[Recurring Scheduler] Scheduler started. Checking every ${intervalMs / 1000}s.`);
}

function stopScheduler() {
  if (_intervalId) {
    clearInterval(_intervalId);
    _intervalId = null;
    logger.info('[Recurring Scheduler] Scheduler stopped.');
  }
}

module.exports = { startScheduler, stopScheduler, checkAndProcessRecurring };
