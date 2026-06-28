'use strict';

const path = require('path');
const dotenv = require('dotenv');

const ROOT = path.resolve(__dirname, '..', '..');
dotenv.config({ path: path.join(ROOT, '.env') });

function int(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
}

function bool(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: int(process.env.PORT, 4000),
  logLevel: process.env.LOG_LEVEL || 'info',
  rootDir: ROOT,

  database: {
    url:
      process.env.DATABASE_URL ||
      process.env.cluster_connect || // fallback to the variable already in .env
      null,
    ssl: (() => {
      const raw = (process.env.DATABASE_SSL || '').toLowerCase();
      if (!raw || raw === 'false' || raw === '0' || raw === 'off') return false;
      if (raw === 'no-verify' || raw === 'norejectunauthorized') {
        return { rejectUnauthorized: false };
      }
      // Cockroach cloud requires SSL.
      return true;
    })(),
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    accessTtl: int(process.env.JWT_ACCESS_TTL, 15 * 60),
    refreshTtl: int(process.env.JWT_REFRESH_TTL, 30 * 24 * 3600),
  },

  ai: {
    url: process.env.AI_SERVICE_URL || 'http://localhost:8000',
    apiKey: process.env.AI_SERVICE_API_KEY || null,
    timeoutMs: int(process.env.AI_SERVICE_TIMEOUT_MS, 15000),
    /** Bill OCR (Paddle+VietOCR+PICK) — often 60–180s on CPU/GPU */
    billOcrTimeoutMs: int(process.env.BILL_OCR_TIMEOUT_MS, 300000),
    /** Max concurrent bill OCR jobs on backend (CPU: 2 thường nhanh hơn 5) */
    billOcrConcurrency: int(process.env.BILL_OCR_CONCURRENCY, 2),
  },

  r2: {
    accountId: process.env.R2_ACCOUNT_ID || process.env.cloudflare_account_id || null,
    accessKeyId:
      process.env.R2_ACCESS_KEY_ID || process.env.cloudflare_access_key_id || null,
    secretAccessKey:
      process.env.R2_SECRET_ACCESS_KEY ||
      process.env.cloudflare_secret_access_key ||
      null,
    bucket:
      process.env.R2_BUCKET || process.env.cloudflare_bucket_name || 'spending-stories',
    region: process.env.R2_REGION || process.env.cloudflare_bucket_region || 'auto',
    publicBaseUrl:
      process.env.R2_PUBLIC_BASE_URL ||
      process.env.cloudflare_bucket_url_public ||
      null,
    presignExpires: int(process.env.R2_PRESIGN_EXPIRES, 3600),
  },

  cors: {
    origins: (process.env.CORS_ORIGINS || '*')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  },

  seed: {
    email: process.env.SEED_DEMO_USER_EMAIL || null,
    password: process.env.SEED_DEMO_USER_PASSWORD || null,
    username: process.env.SEED_DEMO_USER_NAME || 'Demo User',
  },

  google: {
    clientId: process.env.GOOGLE_CLIENT_ID || null,
  },

  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID || null,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL || null,
    privateKey: process.env.FIREBASE_PRIVATE_KEY || null,
  },

  isProd: process.env.NODE_ENV === 'production',
};

module.exports = env;
