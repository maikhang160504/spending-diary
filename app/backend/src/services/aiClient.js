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

async function expenseFromText(payload) {
  return withRetry(async () => {
    const r = await client.post('/api/v1/nlu/infer', {
      text: payload.text,
      profile: payload.profile || null,
      run_llm: true,
      user_id: payload.user_id,
      emotion: payload.emotion,
    });
    const nlu = r.data;
    return {
      extracted: {
        amount:      nlu.amount_spent || nlu.amount || 0,
        category:    nlu.category    || 'Other',
        note:        nlu.clean_content || payload.text,
        confidence:  nlu.intent_confidence ?? nlu.confidence ?? 0,
        record_type: nlu.record_type || 'Expense',
      },
      nlu,
      requires_category_selection: !nlu.category,
    };
  });
}

async function aiChat(messages, userId, options = {}) {
  const lastUserMsg = [...messages].reverse().find((m) => m.role === 'user');
  return withRetry(async () => {
    const r = await client.post('/api/v1/nlu/infer', {
      text: lastUserMsg?.content || '',
      user_id: userId,
      run_llm: true,
      ...options,
    });
    return r.data;
  });
}

async function ocrImage() {
  throw ApiError.upstream('OCR chưa được triển khai', { code: 'OCR_NOT_IMPLEMENTED' });
}

async function expenseFromBill(fileBuffer, filename, userId, contentType) {
  return withRetry(async () => {
    const form = new FormData();
    form.append('file', fileBuffer, {
      filename: filename || 'bill.jpg',
      contentType: contentType || 'image/jpeg',
    });
    if (userId) {
      form.append('user_id', String(userId));
    }

    const r = await client.post('/api/v1/expense/from-bill', form, {
      headers: form.getHeaders(),
    });
    return r.data;
  });
}

module.exports = { health, inferText, ocrImage, expenseFromText, expenseFromBill, aiChat };
