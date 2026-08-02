'use strict';

const { query } = require('../config/db');
const logger = require('../config/logger');

const DEFAULT_SETTINGS = {
  ocr_weight: 0.75,
  nlu_threshold: 0.85,
  date_fallback: 'transaction',
  llm_temperature: 0.7,
  llm_top_k: 40,
  budget_alert: 80,
  category_surge: 25,
  daily_vol: 5,
  prioritize_user_typing: true,
};

let cachedSettings = null;
let lastFetchTime = 0;
const CACHE_TTL_MS = 30000; // 30 seconds

async function initSettingsTable() {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS system_settings (
        key VARCHAR(255) PRIMARY KEY,
        value JSONB NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Seed defaults if not present
    for (const [key, val] of Object.entries(DEFAULT_SETTINGS)) {
      await query(`
        INSERT INTO system_settings (key, value)
        VALUES ($1, $2::jsonb)
        ON CONFLICT (key) DO NOTHING;
      `, [key, JSON.stringify(val)]);
    }
  } catch (err) {
    logger.warn({ err: err.message }, 'Failed to initialize system_settings table');
  }
}

async function getSettings(forceRefresh = false) {
  const now = Date.now();
  if (!forceRefresh && cachedSettings && (now - lastFetchTime < CACHE_TTL_MS)) {
    return { ...cachedSettings };
  }

  try {
    const result = await query('SELECT key, value FROM system_settings');
    const raw = {};
    for (const r of result.rows) {
      raw[r.key] = r.value;
    }

    const settings = {
      ocrWeight: raw.ocr_weight !== undefined ? parseFloat(raw.ocr_weight) : DEFAULT_SETTINGS.ocr_weight,
      nluThreshold: raw.nlu_threshold !== undefined ? parseFloat(raw.nlu_threshold) : DEFAULT_SETTINGS.nlu_threshold,
      dateFallback: raw.date_fallback !== undefined ? String(raw.date_fallback) : DEFAULT_SETTINGS.date_fallback,
      llmTemperature: raw.llm_temperature !== undefined ? parseFloat(raw.llm_temperature) : DEFAULT_SETTINGS.llm_temperature,
      llmTopK: raw.llm_top_k !== undefined ? parseInt(raw.llm_top_k, 10) : DEFAULT_SETTINGS.llm_top_k,
      budgetAlert: raw.budget_alert !== undefined ? parseInt(raw.budget_alert, 10) : DEFAULT_SETTINGS.budget_alert,
      categorySurge: raw.category_surge !== undefined ? parseInt(raw.category_surge, 10) : DEFAULT_SETTINGS.category_surge,
      dailyVol: raw.daily_vol !== undefined ? parseInt(raw.daily_vol, 10) : DEFAULT_SETTINGS.daily_vol,
      prioritizeUserTyping: raw.prioritize_user_typing !== undefined ? Boolean(raw.prioritize_user_typing) : DEFAULT_SETTINGS.prioritize_user_typing,
    };

    cachedSettings = settings;
    lastFetchTime = now;
    return { ...settings };
  } catch (err) {
    logger.warn({ err: err.message }, 'Failed to fetch system_settings, using defaults');
    return {
      ocrWeight: DEFAULT_SETTINGS.ocr_weight,
      nluThreshold: DEFAULT_SETTINGS.nlu_threshold,
      dateFallback: DEFAULT_SETTINGS.date_fallback,
      llmTemperature: DEFAULT_SETTINGS.llm_temperature,
      llmTopK: DEFAULT_SETTINGS.llm_top_k,
      budgetAlert: DEFAULT_SETTINGS.budget_alert,
      categorySurge: DEFAULT_SETTINGS.category_surge,
      dailyVol: DEFAULT_SETTINGS.daily_vol,
      prioritizeUserTyping: DEFAULT_SETTINGS.prioritize_user_typing,
    };
  }
}

async function updateSettings(updates = {}) {
  const mapping = {
    ocrWeight: 'ocr_weight',
    nluThreshold: 'nlu_threshold',
    dateFallback: 'date_fallback',
    llmTemperature: 'llm_temperature',
    llmTopK: 'llm_top_k',
    budgetAlert: 'budget_alert',
    categorySurge: 'category_surge',
    dailyVol: 'daily_vol',
    prioritizeUserTyping: 'prioritize_user_typing',
  };

  for (const [camelKey, dbKey] of Object.entries(mapping)) {
    if (updates[camelKey] !== undefined) {
      await query(`
        INSERT INTO system_settings (key, value)
        VALUES ($1, $2::jsonb)
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
      `, [dbKey, JSON.stringify(updates[camelKey])]);
    }
  }

  // Invalidate cache and fetch fresh values
  return getSettings(true);
}

module.exports = {
  initSettingsTable,
  getSettings,
  updateSettings,
  DEFAULT_SETTINGS,
};
