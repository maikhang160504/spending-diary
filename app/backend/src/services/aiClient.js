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
      const status = err.response.status;
      logger.warn(
        { status, body: err.response.data, url: err.config?.url },
        'AI service responded with error'
      );
      throw new ApiError(
        status,
        status >= 500 ? 'upstream_error' : 'bad_request',
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
      const isRetryable = !err.statusCode || (
        err.statusCode >= 500 &&
        err.statusCode !== 503 &&
        err.statusCode !== 429 &&
        !String(err.message || '').toLowerCase().includes('high demand') &&
        !String(err.message || '').toLowerCase().includes('spikes in demand')
      );
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
      user_corrections: payload.user_corrections || null,
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
  const runLlm = options.run_llm ?? options.runLlm ?? false;
  return withRetry(async () => {
    const r = await client.post('/api/v1/nlu/infer', {
      text: lastUserMsg?.content || '',
      user_id: userId,
      run_llm: runLlm,
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

    const timeoutMs = env.ai.billOcrTimeoutMs;
    const r = await client.post('/api/v1/expense/from-bill', form, {
      headers: form.getHeaders(),
      timeout: timeoutMs,
    });
    logger.info(
      { filename, latency_ms: r.data?.latency_ms, backend: r.data?.ocr?.backend },
      'Bill OCR completed (sync expense/from-bill)'
    );
    return r.data;
  });
}

async function getPrompts() {
  const r = await client.get('/api/v1/nlu/prompts');
  return r.data;
}

async function savePrompts(payload) {
  const r = await client.post('/api/v1/nlu/prompts', payload);
  return r.data;
}

async function triggerTrain(target = 'local') {
  const r = await client.post('/api/v1/nlu/train', { target });
  return r.data;
}


async function getTrainStatus() {
  const r = await client.get('/api/v1/nlu/train/status');
  return r.data;
}

async function getInternalStatus() {
  const r = await client.get('/api/v1/nlu/internal/status');
  return r.data;
}

async function billPrelabel(fileBuffer, filename, contentType) {
  const form = new FormData();
  form.append('file', fileBuffer, {
    filename: filename || 'bill.jpg',
    contentType: contentType || 'image/jpeg',
  });
  const r = await client.post('/api/v1/bill-retrain/prelabel', form, {
    headers: form.getHeaders(),
    timeout: 300000,
  });
  return r.data;
}

async function billExportVerified(samples, triggerKaggle = false, kaggleJobType = 'pick_retrain', webhookUrl) {
  const r = await client.post('/api/v1/bill-retrain/export-verified', {
    samples,
    trigger_kaggle: triggerKaggle,
    kaggle_job_type: kaggleJobType,
    webhook_url: webhookUrl || undefined,
  });
  return r.data;
}

async function billKagglePlan(jobType) {
  const r = await client.post('/api/v1/bill-retrain/kaggle/plan', { job_type: jobType });
  return r.data;
}

async function billKaggleTrigger(jobType, webhookUrl, cloudUrl) {
  const r = await client.post('/api/v1/bill-retrain/kaggle/trigger', {
    job_type: jobType,
    webhook_url: webhookUrl || undefined,
    cloud_fallback_url: cloudUrl || undefined,
  });
  return r.data;
}

async function billKaggleJob(jobId) {
  const r = await client.get(`/api/v1/bill-retrain/kaggle/jobs/${jobId}`);
  return r.data;
}

async function billKaggleJobs(limit = 20) {
  const r = await client.get(`/api/v1/bill-retrain/kaggle/jobs?limit=${limit}`);
  return r.data;
}

async function billKaggleDeploy(source, jobType, batchId) {
  const r = await client.post('/api/v1/bill-retrain/kaggle/deploy', {
    source,
    job_type: jobType,
    batch_id: batchId,
  });
  return r.data;
}

async function billGoldenEval() {
  const r = await client.get('/api/v1/bill-retrain/golden-eval');
  return r.data;
}

async function syncBillKaggle(body = {}) {
  const r = await client.post('/api/v1/bill-retrain/kaggle/sync', body, { timeout: 900000 });
  return r.data;
}

async function reloadModels(scope = 'ocr') {
  const r = await client.post('/api/v1/internal/reload-models', { scope }, { timeout: 300000 });
  return r.data;
}

async function getNluTrainHistory() {
  const r = await client.get('/api/v1/nlu/train/history');
  return r.data;
}

async function getNluModelMeta() {
  const r = await client.get('/api/v1/nlu/model-meta');
  return r.data;
}

async function syncNluKaggle(body = {}) {
  const r = await client.post('/api/v1/nlu/train/kaggle/sync', body, { timeout: 900000 });
  return r.data;
}

async function syncNluEncoderKaggle(body = {}) {
  const r = await client.post('/api/v1/nlu/train/kaggle/encoder/sync', body, { timeout: 900000 });
  return r.data;
}

async function resumeNluKaggle() {
  const r = await client.post('/api/v1/nlu/train/kaggle/resume', {}, { timeout: 30000 });
  return r.data;
}

async function trainEncoderKaggle() {
  const r = await client.post('/api/v1/nlu/train/kaggle/encoder', {}, { timeout: 30000 });
  return r.data;
}

async function getNluInferenceBackend() {
  const r = await client.get('/api/v1/nlu/inference-backend');
  return r.data;
}

async function setNluInferenceBackend(backend) {
  const r = await client.post('/api/v1/nlu/inference-backend', { backend }, { timeout: 30000 });
  return r.data;
}

async function getNluKaggleJobs(limit = 20) {
  const r = await client.get(`/api/v1/nlu/train/kaggle/jobs?limit=${limit}`);
  return r.data;
}

async function getNluKaggleJob(jobId) {
  const r = await client.get(`/api/v1/nlu/train/kaggle/jobs/${jobId}`);
  return r.data;
}

module.exports = {
  health,
  inferText,
  ocrImage,
  expenseFromText,
  expenseFromBill,
  aiChat,
  getPrompts,
  savePrompts,
  triggerTrain,
  getTrainStatus,
  getInternalStatus,
  billPrelabel,
  billExportVerified,
  billKagglePlan,
  billKaggleTrigger,
  billKaggleJob,
  billKaggleJobs,
  billKaggleDeploy,
  billGoldenEval,
  syncBillKaggle,
  reloadModels,
  getNluTrainHistory,
  getNluModelMeta,
  syncNluKaggle,
  syncNluEncoderKaggle,
  resumeNluKaggle,
  trainEncoderKaggle,
  getNluInferenceBackend,
  setNluInferenceBackend,
  getNluKaggleJobs,
  getNluKaggleJob,
};


