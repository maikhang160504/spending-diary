'use strict';

require('./config/env');

const app = require('./app');
const env = require('./config/env');
const logger = require('./config/logger');
const { ping, pool } = require('./config/db');
const { attachWsServer } = require('./services/wsHub');
const { startScheduler, stopScheduler } = require('./modules/recurring/recurring.scheduler');
const { startNotificationScheduler, stopNotificationScheduler } = require('./modules/fcm/notification.scheduler');
const { initFinancialToolsReminderCron } = require('./cron/financialToolsReminder.cron');
const { initDailyExpenseReminderCron } = require('./cron/dailyExpenseReminder.cron');
const { initBudgetResetCron } = require('./cron/budgetReset.cron');

async function start() {
  if (env.database.url) {
    const ok = await ping();
    if (!ok) {
      logger.warn('DB ping failed — service starts but some endpoints will error.');
    } else {
      logger.info('DB ping OK');
    }
  } else {
    logger.warn('DATABASE_URL not set — DB-backed routes will fail.');
  }

  const server = app.listen(env.port, () => {
    logger.info(
      { port: env.port, env: env.nodeEnv, docs: `http://localhost:${env.port}/docs` },
      'backend listening'
    );
    attachWsServer(server);
    startScheduler(); // Start checking for due recurring transaction rules
    startNotificationScheduler(); // Start checking for due dynamic story prompts
    initFinancialToolsReminderCron(); // Start checking for due savings, challenges & loans
    initDailyExpenseReminderCron(); // Start checking for daily expense reminders
    initBudgetResetCron();         // Monthly budget reset + last-week reminder
  });

  const shutdown = async (signal) => {
    logger.info({ signal }, 'shutting down');
    stopScheduler(); // Stop scheduler before closing DB connection pool
    stopNotificationScheduler(); // Stop notification scheduler
    server.close(() => {
      pool.end().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start().catch((err) => {
  logger.error({ err: err.stack || err.message }, 'failed to start');
  process.exit(1);
});
