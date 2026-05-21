'use strict';

class ApiError extends Error {
  constructor(statusCode, code, message, details = undefined) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;
  }

  static badRequest(message, details) {
    return new ApiError(400, 'bad_request', message, details);
  }

  static unauthorized(message = 'Unauthorized', details) {
    return new ApiError(401, 'unauthorized', message, details);
  }

  static forbidden(message = 'Forbidden', details) {
    return new ApiError(403, 'forbidden', message, details);
  }

  static notFound(message = 'Not found', details) {
    return new ApiError(404, 'not_found', message, details);
  }

  static conflict(message, details) {
    return new ApiError(409, 'conflict', message, details);
  }

  static validation(details) {
    return new ApiError(422, 'validation_error', 'Validation failed', details);
  }

  static upstream(message, details) {
    return new ApiError(502, 'upstream_error', message, details);
  }
}

module.exports = ApiError;
