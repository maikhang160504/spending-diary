'use strict';

const axios = require('axios');
const FormData = require('form-data');

const env = require('../config/env');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

const client = axios.create({
  baseURL: env.ai.url,
  timeout: env.ai.timeoutMs,
  headers: env.ai.apiKey ? { 'X-API-Key': env.ai.apiKey } : undefined,
});

client.interceptors.response.use(
  (r) => r,
  (err) => {
    if (err.response) {
      logger.warn(
        { status: err.response.status, body: err.response.data, url: err.config?.url },
        'AI service responded with error'
      );
      throw ApiError.upstream(
        err.response.data?.error?.message || 'AI service error',
        err.response.data
      );
    }
    logger.error({ msg: err.message, url: err.config?.url }, 'AI service unreachable');
    throw ApiError.upstream('AI service unreachable', { code: err.code });
  }
);

/**
 * Retry wrapper with exponential backoff.
 * Retries on network errors and 5xx responses.
 */
async function withRetry(fn, { retries = 2, baseDelayMs = 300 } = {}) {
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const isRetryable = !err.statusCode || err.statusCode >= 500;
      if (!isRetryable || attempt === retries) throw err;
      const delay = baseDelayMs * Math.pow(2, attempt);
      logger.info({ attempt: attempt + 1, delay }, 'Retrying AI call...');
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw lastErr;
}

async function health() {
  const r = await client.get('/health');
  return r.data;
}

async function inferText(payload) {
  return withRetry(async () => {
    const r = await client.post('/api/v1/nlu/infer', payload);
    return r.data;
  });
}

async function ocrImage(buffer, filename = 'bill.jpg', mime = 'image/jpeg') {
  const form = new FormData();
  form.append('file', buffer, { filename, contentType: mime });
  const r = await client.post('/api/v1/ocr/image', form, {
    headers: { ...form.getHeaders() },
    maxContentLength: Infinity,
    maxBodyLength: Infinity,
  });
  return r.data;
}

async function expenseFromText(payload) {
  return withRetry(async () => {
    const r = await client.post('/api/v1/expense/from-text', payload);
    return r.data;
  });
}

async function aiChat(messages, userId, options = {}) {
  return withRetry(async () => {
    const r = await client.post('/api/v1/chat', {
      messages,
      user_id: userId,
      ...options,
    });
    return r.data;
  });
}

async function expenseFromBill(buffer, filename = 'bill.jpg', userId = undefined, mime = 'image/jpeg') {
  const form = new FormData();
  form.append('file', buffer, { filename, contentType: mime });
  if (userId) form.append('user_id', userId);
  const r = await client.post('/api/v1/expense/from-bill', form, {
    headers: { ...form.getHeaders() },
    maxContentLength: Infinity,
    maxBodyLength: Infinity,
  });
  return r.data;
}

module.exports = { health, inferText, ocrImage, expenseFromText, expenseFromBill, aiChat };
