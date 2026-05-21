'use strict';

const logger = require('../config/logger');

module.exports = function requestLogger(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - start) / 1_000_000;
    logger.info(
      {
        request_id: req.id,
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        latency_ms: Math.round(ms),
        user_id: req.user?.id,
      },
      'request'
    );
  });
  next();
};
