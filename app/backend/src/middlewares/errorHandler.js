'use strict';

const ApiError = require('../utils/ApiError');
const logger = require('../config/logger');

// eslint-disable-next-line no-unused-vars
function notFound(req, res, next) {
  res.status(404).json({
    success: false,
    error: {
      code: 'not_found',
      message: `Route ${req.method} ${req.originalUrl} not found.`,
    },
  });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      error: { code: err.code, message: err.message, details: err.details },
    });
  }
  // JSON body-parser errors
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      error: { code: 'invalid_json', message: 'Body is not valid JSON.' },
    });
  }
  // Multer size errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      success: false,
      error: { code: 'payload_too_large', message: 'File too large.' },
    });
  }
  logger.error({ err: { message: err.message, stack: err.stack } }, 'unhandled error');
  res.status(500).json({
    success: false,
    error: { code: 'internal_error', message: 'Internal server error.' },
  });
}

module.exports = { notFound, errorHandler };
