'use strict';

const axios = require('axios');
const FormData = require('form-data');

const env = require('../config/env');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

const http = require('http');
const https = require('https');

const httpAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 100,
  maxFreeSockets: 10,
  timeout: 60000,
});

const httpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 100,
  maxFreeSockets: 10,
  timeout: 60000,
});

const client = axios.create({
  baseURL: env.ai.url,
  timeout: env.ai.timeoutMs,
  headers: env.ai.apiKey ? { 'X-API-Key': env.ai.apiKey } : undefined,
  httpAgent,
  httpsAgent,
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

const cacheStore = new Map();

function withCache(ttlMs, fn) {
  return async (...args) => {
    const key = fn.name + JSON.stringify(args);
    const now = Date.now();
    const cached = cacheStore.get(key);
    if (cached && cached.expiresAt > now) {
      return cached.promise;
    }
    const promise = fn(...args);
    cacheStore.set(key, { promise, expiresAt: now + ttlMs });
    promise.catch(() => {
      cacheStore.delete(key);
    });
    return promise;
  };
}

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
      run_llm: payload.run_llm ?? true,
      user_id: payload.user_id,
      emotion: payload.emotion,
      user_corrections: payload.user_corrections || null,
      temperature: payload.temperature,
      top_k: payload.top_k,
    });
    const nlu = r.data;
    const nlgResponse = nlu.nlg_response || nlu.llm_json?.response || nlu.response || null;
    const nlgEmotion = nlu.mimo_emotion || nlu.llm_emotion || nlu.mascot_mood || 'Happy';
    return {
      extracted: {
        amount:      nlu.amount_spent || nlu.amount || 0,
        category:    nlu.category    || 'Other',
        note:        nlu.clean_content || payload.text,
        confidence:  nlu.intent_confidence ?? nlu.confidence ?? 0,
        record_type: nlu.record_type || 'Expense',
      },
      nlu,
      nlg: {
        response: nlgResponse,
        emotion: nlgEmotion,
      },
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
  for (const key of cacheStore.keys()) {
    if (key.startsWith('getTrainStatus')) {
      cacheStore.delete(key);
    }
  }
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

async function billModalTrigger(numEpochs = 30, learningRate = 0.00002) {
  for (const key of cacheStore.keys()) {
    if (key.startsWith('getTrainStatus')) {
      cacheStore.delete(key);
    }
  }
  const r = await client.post('/api/v1/bill-retrain/modal/trigger', {
    num_epochs: numEpochs,
    learning_rate: learningRate,
  });
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

async function getNluBenchmarkResults() {
  const r = await client.get('/api/v1/nlu/benchmark/results');
  return r.data;
}

async function triggerNluBenchmark() {
  const r = await client.post('/api/v1/nlu/benchmark/run');
  return r.data;
}

async function getLlmTrainHistory() {
  const r = await client.get('/api/v1/nlu/train/llm-history');
  return r.data;
}

async function getOcrTrainHistory() {
  const r = await client.get('/api/v1/bill-retrain/ocr-history');
  return r.data;
}

async function triggerLlmFinetune(epochs = 3, lr = 0.0002, batchSize = 4) {
  for (const key of cacheStore.keys()) {
    if (key.startsWith('getTrainStatus')) {
      cacheStore.delete(key);
    }
  }
  const r = await client.post('/api/v1/nlu/train/llm-trigger', null, {
    params: { epochs, lr, batch_size: batchSize }
  });
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

const healthCached = withCache(5000, health);
const getTrainStatusCached = withCache(3000, getTrainStatus);
async function testPrompt(payload) {
  return withRetry(async () => {
    const r = await client.post('/api/v1/nlu/test-prompt', payload);
    return r.data;
  });
}

const getNluTrainHistoryCached = withCache(5000, getNluTrainHistory);
const getNluModelMetaCached = withCache(5000, getNluModelMeta);
const getNluBenchmarkResultsCached = withCache(5000, getNluBenchmarkResults);
const getLlmTrainHistoryCached = withCache(5000, getLlmTrainHistory);
const getOcrTrainHistoryCached = withCache(5000, getOcrTrainHistory);
const getNluInferenceBackendCached = withCache(5000, getNluInferenceBackend);
const inferTextCached = withCache(3000, inferText);
const expenseFromTextCached = withCache(3000, expenseFromText);

module.exports = {
  health: healthCached,
  inferText: inferTextCached,
  ocrImage,
  expenseFromText: expenseFromTextCached,
  expenseFromBill,
  aiChat,
  getPrompts,
  savePrompts,
  testPrompt,
  triggerTrain,
  getTrainStatus: getTrainStatusCached,
  getInternalStatus,
  billPrelabel,
  billExportVerified,
  billGoldenEval,
  billModalTrigger,
  reloadModels,
  getNluTrainHistory: getNluTrainHistoryCached,
  getNluModelMeta: getNluModelMetaCached,
  getNluInferenceBackend: getNluInferenceBackendCached,
  setNluInferenceBackend,
  getNluBenchmarkResults: getNluBenchmarkResultsCached,
  triggerNluBenchmark,
  getLlmTrainHistory: getLlmTrainHistoryCached,
  getOcrTrainHistory: getOcrTrainHistoryCached,
  triggerLlmFinetune,
};



