'use strict';

const pino = require('pino');
const env = require('./env');

const isDev = env.nodeEnv !== 'production';

const logger = pino({
  level: env.logLevel,
  base: { service: 'moneystory-backend' },
  transport: isDev
    ? {
        target: 'pino-pretty',
        options: { colorize: true, translateTime: 'SYS:HH:MM:ss.l' },
      }
    : undefined,
});

module.exports = logger;
