'use strict';

const { pool } = require('../../config/db');
const logger = require('../../config/logger');
const { dispatchUserNotification } = require('../../services/notificationDispatch');
const templates = require('../ai/notification_templates.json');

/**
 * Determine the local time period based on GMT+7 hour.
 */
function getPeriodForHour(localHour) {
  if (localHour === 8) return 'morning';
  if (localHour === 12) return 'lunch';
  if (localHour === 19) return 'evening';
  if (localHour === 22) return 'night';
  return null;
}

/**
 * Get balance tier for a given total balance.
 */
function getBalanceLevel(balance) {
  if (balance < 500000) return 'empty';
  if (balance >= 5000000) return 'full';
  return 'normal';
}

/**
 * Periodic task to analyze context and send template notifications.
 */
async function checkAndDispatchStoryTriggers() {
  const vnTime = new Date(Date.now() + 7 * 3600000);
  const localHour = vnTime.getUTCHours();
  const period = getPeriodForHour(localHour);

  if (!period) {
    logger.debug(`[Notification Scheduler] Current hour ${localHour} (GMT+7) is not a trigger window. Skipping.`);
    return;
  }

  const localDateStr = vnTime.toISOString().split('T')[0];
  logger.info(`[Notification Scheduler] Checking triggers for period "${period}" on date "${localDateStr}"...`);

  const client = await pool.connect();
  try {
    // 1. Fetch users with active FCM tokens and their total balance
    const usersRes = await client.query(
      `SELECT u.id, u.email,
         COALESCE(
           (SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE -t.amount END)
            FROM transactions t
            INNER JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
            WHERE wm.user_id = u.id AND t.is_draft = FALSE),
           0
         ) AS total_balance
       FROM users u
       WHERE EXISTS (
         SELECT 1 FROM user_fcm_tokens uft WHERE uft.user_id = u.id
       )`
    );

    logger.debug(`[Notification Scheduler] Found ${usersRes.rows.length} candidate users with tokens.`);

    for (const user of usersRes.rows) {
      try {
        // 2. Check if already sent for this period today
        const logCheck = await client.query(
          `SELECT 1 FROM user_notification_logs 
           WHERE user_id = $1 AND sent_date = $2::date AND time_period = $3`,
          [user.id, localDateStr, period]
        );

        if (logCheck.rows.length > 0) {
          logger.debug({ userId: user.id, period }, '[Notification Scheduler] Already notified for this window today.');
          continue;
        }

        // 3. Map balance tier
        const balance = Number(user.total_balance);
        const level = getBalanceLevel(balance);
        const poolList = templates[period]?.[level];

        if (!poolList || poolList.length === 0) {
          continue;
        }

        // 4. Randomly select template
        const text = poolList[Math.floor(Math.random() * poolList.length)];

        // 5. Save log first (optimistic lock / prevent duplicates)
        try {
          await client.query(
            `INSERT INTO user_notification_logs (user_id, notification_type, time_period, sent_date)
             VALUES ($1, 'STORY_TRIGGER', $2, $3::date)`,
            [user.id, period, localDateStr]
          );
        } catch (dbErr) {
          // If conflict/unique constraint fails, ignore and skip to prevent double push
          logger.debug({ userId: user.id, period }, '[Notification Scheduler] Log insert conflict, skipping send.');
          continue;
        }

        // 6. Send push
        await dispatchUserNotification(user.id, {
          type: 'STORY_TRIGGER',
          payload: {
            title: 'SpendDiary',
            message: text,
            deepLink: '/chat',
          },
        });

        logger.info({ userId: user.id, period, level }, '[Notification Scheduler] Contextual push sent successfully');
      } catch (err) {
        logger.error({ userId: user.id, err: err.message }, '[Notification Scheduler] Failed to process user notification');
      }
    }
  } catch (err) {
    logger.error({ err: err.message }, '[Notification Scheduler] Check failed');
  } finally {
    client.release();
  }
}

/**
 * Simulate push trigger manually for testing/debugging.
 */
async function simulateUserPush(userId) {
  const vnTime = new Date(Date.now() + 7 * 3600000);
  const localHour = vnTime.getUTCHours();
  
  // If not in a standard hour window, fallback to evening templates for demo purposes
  let period = getPeriodForHour(localHour) || 'evening';
  
  const client = await pool.connect();
  try {
    const res = await client.query(
      `SELECT COALESCE(
         (SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE -t.amount END)
          FROM transactions t
          INNER JOIN wallet_members wm ON wm.wallet_id = t.wallet_id
          WHERE wm.user_id = $1 AND t.is_draft = FALSE),
         0
       ) AS total_balance`,
      [userId]
    );

    const balance = res.rows[0] ? Number(res.rows[0].total_balance) : 0;
    const level = getBalanceLevel(balance);
    const poolList = templates[period]?.[level] || templates['evening']['normal'];
    const text = poolList[Math.floor(Math.random() * poolList.length)];

    // Send immediately (ignore log checks for simulation)
    await dispatchUserNotification(userId, {
      type: 'STORY_TRIGGER',
      payload: {
        title: 'SpendDiary (Demo)',
        message: text,
        deepLink: '/chat',
      },
    });

    return { period, level, balance, message: text };
  } finally {
    client.release();
  }
}

let _intervalId = null;

function startNotificationScheduler(intervalMs = 1800000) { // Every 30 minutes
  if (_intervalId) return;
  
  // Run once shortly after start
  setTimeout(checkAndDispatchStoryTriggers, 10000);
  
  _intervalId = setInterval(checkAndDispatchStoryTriggers, intervalMs);
  logger.info(`[Notification Scheduler] Started. Checking every ${intervalMs / 1000}s.`);
}

function stopNotificationScheduler() {
  if (_intervalId) {
    clearInterval(_intervalId);
    _intervalId = null;
    logger.info('[Notification Scheduler] Stopped.');
  }
}

module.exports = {
  startNotificationScheduler,
  stopNotificationScheduler,
  checkAndDispatchStoryTriggers,
  simulateUserPush,
};
