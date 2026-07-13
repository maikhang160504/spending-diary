'use strict';

const aiClient = require('../../services/aiClient');
const r2Client = require('../../services/r2Client');
const { query } = require('../../config/db');
const txService = require('../transactions/transactions.service');
const actionService = require('./action.service');
const ApiError = require('../../utils/ApiError');
const logger = require('../../config/logger');
const weatherService = require('../weather/weather.service');
const { normalizeMascotMood, pickMimoEmotionFromNlu } = require('../../utils/mascotMood');
const {
  resolveCategoryCorrectionKeyword,
  resolveKeywordFromOcrPayload,
  isInvalidPersonalizationKeyword,
} = require('../../utils/billPersonalization');
const env = require('../../config/env');
const path = require('path');

class Semaphore {
  constructor(maxConcurrency) {
    this.maxConcurrency = maxConcurrency;
    this.currentConcurrency = 0;
    this.queue = [];
  }

  async acquire() {
    if (this.currentConcurrency < this.maxConcurrency) {
      this.currentConcurrency++;
      return;
    }
    return new Promise((resolve) => {
      this.queue.push(resolve);
    });
  }

  release() {
    this.currentConcurrency--;
    if (this.queue.length > 0) {
      this.currentConcurrency++;
      const next = this.queue.shift();
      next();
    }
  }

  async run(fn) {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }
}

const ocrSemaphore = new Semaphore(env.ai.billOcrConcurrency);
const walletProfileCache = new Map();
const userCorrectionsCache = new Map();

async function _getSystemSettings() {
  try {
    const result = await query('SELECT key, value FROM system_settings');
    const settings = {};
    for (const r of result.rows) {
      settings[r.key] = r.value;
    }
    return {
      ocrWeight: settings.ocr_weight !== undefined ? parseFloat(settings.ocr_weight) : 0.75,
      nluThreshold: settings.nlu_threshold !== undefined ? parseFloat(settings.nlu_threshold) : 0.85,
      dateFallback: settings.date_fallback !== undefined ? String(settings.date_fallback) : 'transaction',
    };
  } catch (err) {
    logger.warn({ err: err.message }, 'Failed to fetch system settings, using defaults');
    return {
      ocrWeight: 0.75,
      nluThreshold: 0.85,
      dateFallback: 'transaction',
    };
  }
}

function parseBillDate(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return null;
  const cleaned = dateStr.trim().replace(/\s+/g, ' ');
  
  const dmyMatch = cleaned.match(/^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})/);
  if (dmyMatch) {
    const day = parseInt(dmyMatch[1], 10);
    const month = parseInt(dmyMatch[2], 10) - 1;
    const year = parseInt(dmyMatch[3], 10);
    
    const timeMatch = cleaned.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/);
    if (timeMatch) {
      const hour = parseInt(timeMatch[1], 10);
      const min = parseInt(timeMatch[2], 10);
      const sec = timeMatch[3] ? parseInt(timeMatch[3], 10) : 0;
      const date = new Date(year, month, day, hour, min, sec);
      if (!isNaN(date.getTime())) return date;
    } else {
      const date = new Date(year, month, day, 12, 0, 0);
      if (!isNaN(date.getTime())) return date;
    }
  }

  const ymdMatch = cleaned.match(/^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})/);
  if (ymdMatch) {
    const year = parseInt(ymdMatch[1], 10);
    const month = parseInt(ymdMatch[2], 10) - 1;
    const day = parseInt(ymdMatch[3], 10);
    
    const timeMatch = cleaned.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/);
    if (timeMatch) {
      const hour = parseInt(timeMatch[1], 10);
      const min = parseInt(timeMatch[2], 10);
      const sec = timeMatch[3] ? parseInt(timeMatch[3], 10) : 0;
      const date = new Date(year, month, day, hour, min, sec);
      if (!isNaN(date.getTime())) return date;
    } else {
      const date = new Date(year, month, day, 12, 0, 0);
      if (!isNaN(date.getTime())) return date;
    }
  }

  const d = new Date(cleaned);
  if (!isNaN(d.getTime())) return d;
  return null;
}

async function _resolveWalletId(userId) {
  try {
    const r = await query(
      `SELECT wallet_id FROM wallet_members WHERE user_id = $1 LIMIT 1`,
      [userId]
    );
    return r.rows[0]?.wallet_id || null;
  } catch (_) {
    return null;
  }
}

async function _enrichNluWithAction(userId, payload, response) {
  if (response.intent !== 'Action') return response;

  const actionType = response.action_type;
  
  if (actionType === 'SUGGEST_BUDGET') {
    try {
      const suggestionService = require('../budgets/suggestion.service');
      const now = new Date();
      let m = now.getMonth() + 2;
      let y = now.getFullYear();
      if (m > 12) { m = 1; y += 1; }
      const targetMonth = `${y}-${String(m).padStart(2, '0')}`;
      
      let suggestions = await suggestionService.getSuggestions(userId, targetMonth);
      if (suggestions.length === 0) {
        await suggestionService.generateForUser(userId, targetMonth);
        suggestions = await suggestionService.getSuggestions(userId, targetMonth);
      }
      const story = suggestionService.buildSuggestionStory(suggestions, targetMonth);
      
      const displayEmotion = 'Thinking';
      response.gemini_json = response.gemini_json || {};
      response.gemini_json.story = story;
      response.gemini_json.mimo_emotion = displayEmotion;
      response.gemini_json.emotion = displayEmotion;
      response.mimo_emotion = displayEmotion;
      response.nlg_response = story;
      response.action_result = { suggestions };
      
      await logAi(userId, 'action_executed', { text: payload.text, actionType }, { suggestions }, { backend: response.backend });
      return response;
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'action suggest budget execution failed');
      return response;
    }
  }

  if (actionType === 'SEARCH_RECORD') {
    try {
      const actionResult = await actionService.executeAction(userId, {
        actionType,
        text: payload.text || response.text || '',
        actionDetails: response.action_details,
      });
      response.action_result = actionResult;
      let story = actionResult.message;

      const runLlm = Boolean(payload.runLlm || payload.run_llm || response.gemini_json || response.llama_json);
      if (runLlm) {
        try {
          let nlgPersona = payload.nlgPersona || payload.emotion;
          if (!nlgPersona && userId) {
            const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
            const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
            nlgPersona = mapVerbalStyleToNlgPersona(verbalStyle);
          }
          const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
          const secondPayload = {
            text: payload.text || response.text || '',
            profile: {
              ...(payload.profile || {}),
              action_facts: actionResult,
            },
            run_llm: true,
            nlg_persona: nlgPersona || null,
            emotion: nlgPersona || null,
            user_id: userId,
            user_corrections: userCorrections,
          };
          const secondRes = await aiClient.inferText(secondPayload);
          const secondStory = secondRes.gemini_json?.response || secondRes.gemini_json?.story || secondRes.nlg_response;
          if (secondStory) {
            story = secondStory;
            response.gemini_json = secondRes.gemini_json || response.gemini_json;
            response.llama_json = secondRes.llama_json || response.llama_json;
          }
        } catch (err) {
          logger.error({ err: err.message, userId }, 'Second LLM call for search failed');
        }
      }

      const displayEmotion = pickMimoEmotionFromNlu(response, 'Action');
      response.gemini_json = response.gemini_json || {};
      response.gemini_json.mimo_emotion = displayEmotion;
      response.gemini_json.emotion = displayEmotion;
      response.mimo_emotion = displayEmotion;
      response.nlg_response = story || response.nlg_response;
      response.gemini_json.story = story || response.gemini_json.story;

      await logAi(userId, 'action_executed', { text: payload.text, actionType }, actionResult, { backend: response.backend });
      return response;
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'action search execution failed');
      return response;
    }
  }

  if (['SET_TONE', 'SYSTEM_SETTING', 'SET_USERNAME', 'SET_ALERT'].includes(actionType)) {
    try {
      const actionResult = await actionService.executeAction(userId, {
        actionType,
        text: payload.text || response.text || '',
        actionDetails: response.action_details,
        verbalStyle: response.verbal_style,
        theme: response.theme,
        username: response.username,
        slots: response,
      });
      response.action_result = actionResult;

      // Handle settings updated push for TONE
      if (actionType === 'SET_TONE' && actionResult.changed && actionResult.verbalStyle) {
        const { sendToUser } = require('../../services/wsHub');
        sendToUser(userId, { type: 'settings_updated', verbal_style: actionResult.verbalStyle });
      }

      let story = actionResult.message;
      const runLlm = Boolean(payload.runLlm || payload.run_llm || response.gemini_json || response.llama_json);
      if (runLlm) {
        try {
          let nlgPersona = payload.nlgPersona || payload.emotion;
          if (!nlgPersona && userId) {
            const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
            const verbalStyle = settingsRes.rows[0]?.verbal_style || 'dui_de';
            nlgPersona = mapVerbalStyleToNlgPersona(verbalStyle);
          }
          const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
          const secondPayload = {
            text: payload.text || response.text || '',
            profile: {
              ...(payload.profile || {}),
              action_facts: actionResult,
            },
            run_llm: true,
            nlg_persona: nlgPersona || null,
            emotion: nlgPersona || null,
            user_id: userId,
            user_corrections: userCorrections,
          };
          const secondRes = await aiClient.inferText(secondPayload);
          const secondStory = secondRes.gemini_json?.response || secondRes.gemini_json?.story || secondRes.nlg_response;
          if (secondStory) {
            story = secondStory;
            response.gemini_json = secondRes.gemini_json || response.gemini_json;
            response.llama_json = secondRes.llama_json || response.llama_json;
          }
        } catch (err) {
          logger.error({ err: err.message, userId }, `Second LLM call for ${actionType} failed`);
        }
      }

      const displayEmotion = pickMimoEmotionFromNlu(response, 'Action');
      response.gemini_json = response.gemini_json || {};
      response.gemini_json.mimo_emotion = displayEmotion;
      response.gemini_json.emotion = displayEmotion;
      response.mimo_emotion = displayEmotion;
      response.nlg_response = story || response.nlg_response;
      response.gemini_json.story = story || response.gemini_json.story;

      await logAi(userId, 'action_executed', { text: payload.text, actionType }, actionResult, { backend: response.backend });
      return response;
    } catch (err) {
      logger.warn({ err: err.message, userId }, `action ${actionType} execution failed`);
      return response;
    }
  }

  if (!actionService.isReportAction(actionType)) return response;

  const timeRange =
    response.time_range ||
    actionService.inferTimeRangeFromText(payload.text || response.text || '');

  try {
    const reportKind = actionService.detectReportKind(payload.text || response.text || '', actionType);
    const actionResult = await actionService.executeReport(userId, {
      timeRange,
      categoryCode: actionService.resolveCategoryCode(
        response.category,
        response.action_details,
        payload.text || response.text || ''
      ),
      reportKind,
      text: payload.text || response.text || '',
      actionDetails: response.action_details,
    });
    let story = actionService.buildReportStory(actionResult);

    const runLlm = Boolean(payload.runLlm || payload.run_llm || response.gemini_json || response.llama_json);
    if (runLlm) {
      try {
        let nlgPersona = payload.nlgPersona || payload.emotion;
        if (!nlgPersona && userId) {
          const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
          const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
          nlgPersona = mapVerbalStyleToNlgPersona(verbalStyle);
        }
        const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
        const secondPayload = {
          text: payload.text || response.text || '',
          profile: {
            ...(payload.profile || {}),
            action_facts: actionResult,
          },
          run_llm: true,
          nlg_persona: nlgPersona || null,
          emotion: nlgPersona || null,
          user_id: userId,
          user_corrections: userCorrections,
        };
        const secondRes = await aiClient.inferText(secondPayload);
        const secondStory = secondRes.gemini_json?.response || secondRes.gemini_json?.story || secondRes.nlg_response;
        if (secondStory) {
          story = secondStory;
          response.gemini_json = secondRes.gemini_json || response.gemini_json;
          response.llama_json = secondRes.llama_json || response.llama_json;
        }
      } catch (err) {
        logger.error({ err: err.message, userId }, 'Second LLM call for report narrative failed, falling back to static story');
      }
    }

    response.time_range = timeRange;
    response.action_result = actionResult;
    response.action_signature = actionService.buildActionSignature(actionType, timeRange);

    const displayEmotion = pickMimoEmotionFromNlu(response, 'Action');
    response.gemini_json = response.gemini_json || {};
    response.gemini_json.story = story;
    response.gemini_json.mimo_emotion = displayEmotion;
    response.gemini_json.emotion = displayEmotion;
    response.mimo_emotion = displayEmotion;
    response.llm_emotion = displayEmotion;
    response.mascot_mood = displayEmotion;
    response.nlg_response = story;

    await logAi(userId, 'action_executed', { text: payload.text, actionType, timeRange }, actionResult, {
      backend: response.backend,
    });
  } catch (err) {
    logger.warn({ err: err.message, userId, actionType }, 'action report execution failed');
  }

  return response;
}

async function logAi(userId, flow, input, output, extra = {}) {
  try {
    await query(
      `INSERT INTO ai_logs (user_id, flow, request_input, response_output, backend, latency_ms, confidence, error)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        userId || null,
        flow,
        input || {},
        output || {},
        extra.backend || null,
        extra.latency_ms || null,
        extra.confidence || null,
        extra.error || null,
      ]
    );
  } catch (err) {
    logger.warn({ err: err.message }, 'failed to write ai_log');
  }
}

function mapVerbalStyleToNlgPersona(style) {
  const mapping = {
    dui_de: 'dui_de',
    dan_doi: 'dan_doi',
    kho_tinh: 'kho_tinh',
    ngot_ngao: 'ngot_ngao',
  };
  return mapping[style] || 'dui_de';
}

/** @deprecated use mapVerbalStyleToNlgPersona */
const mapVerbalStyleToEmotion = mapVerbalStyleToNlgPersona;

async function nluInfer(userId, payload) {
  let nlgPersona = payload.nlgPersona || payload.emotion;
  if (!nlgPersona && userId) {
    try {
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      nlgPersona = mapVerbalStyleToNlgPersona(verbalStyle);
    } catch (_) {}
  }

  let profile = payload.profile || null;
  if (!profile && userId) {
    const walletId = await _resolveWalletId(userId);
    if (walletId) {
      profile = await _fetchWalletProfile(userId, walletId);
    }
  }

  const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
  const aiPayload = {
    text: payload.text,
    profile: profile || null,
    run_llm: Boolean(payload.runLlm),
    nlg_persona: nlgPersona || null,
    emotion: nlgPersona || null,
    user_id: userId,
    user_corrections: userCorrections,
  };
  try {
    let response = await aiClient.inferText(aiPayload);
    response = await _enrichNluWithAction(userId, payload, response);
    await logAi(userId, 'nlu', aiPayload, response, {
      backend: response.backend,
      latency_ms: response.latency_ms,
      confidence: response.intent_confidence,
    });
    return response;
  } catch (err) {
    await logAi(userId, 'nlu', aiPayload, null, { error: err.message });
    throw err;
  }
}

async function _fetchWalletProfile(userId, walletId) {
  if (!walletId) return null;
  const now = Date.now();
  const cacheKey = `${userId}:${walletId}`;
  const cached = walletProfileCache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.data;
  }

  try {
    const [walletRes, catRes, spendRes] = await Promise.all([
      query(
        `SELECT b.amount_limit AS budget_total,
                GREATEST(0, b.amount_limit - COALESCE(SUM(t.amount) FILTER (WHERE t.type='expense'), 0)) AS budget_remain,
                w.type AS wallet_type,
                (SELECT COUNT(*)::int FROM wallet_members WHERE wallet_id = w.id) AS member_count
         FROM wallets w
         LEFT JOIN budgets b ON b.wallet_id = w.id AND b.period = 'monthly'
                             AND date_trunc('month', NOW()) BETWEEN b.start_date AND COALESCE(b.end_date, 'infinity'::date)
         LEFT JOIN transactions t ON t.wallet_id = w.id AND t.is_deleted = FALSE AND t.type = 'expense'
                                  AND date_trunc('month', t.occurred_at) = date_trunc('month', NOW())
         WHERE w.id = $1
         GROUP BY b.amount_limit, w.type, w.id`,
        [walletId]
      ),
      query(
        `WITH month_total AS (
           SELECT COALESCE(SUM(amount) FILTER (WHERE type='expense' AND is_deleted = FALSE
             AND date_trunc('month', occurred_at) = date_trunc('month', NOW())), 1) AS total
           FROM transactions WHERE wallet_id = $1
         )
         SELECT t.category_code,
                COUNT(t.id) FILTER (WHERE t.occurred_at >= NOW() - INTERVAL '7 days') AS frequency_week,
                ROUND(AVG(t.amount)) AS avg_amount,
                SUM(t.amount) AS month_total,
                ROUND(100.0 * SUM(t.amount) / NULLIF(mt.total, 0)) AS pct
         FROM transactions t, month_total mt
         WHERE t.wallet_id = $1 AND t.type = 'expense' AND t.is_deleted = FALSE
           AND date_trunc('month', t.occurred_at) = date_trunc('month', NOW())
           AND t.category_code IS NOT NULL
         GROUP BY t.category_code, mt.total
         ORDER BY month_total DESC
         LIMIT 8`,
        [walletId]
      ),
      query(
        `SELECT
           COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND occurred_at >= date_trunc('day', NOW())), 0)::numeric AS spent_today,
           COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND occurred_at >= date_trunc('week', NOW())), 0)::numeric AS spent_week,
           COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND occurred_at >= date_trunc('month', NOW())), 0)::numeric AS spent_month,
           COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND occurred_at >= date_trunc('month', NOW() - INTERVAL '1 month') AND occurred_at < date_trunc('month', NOW())), 0)::numeric AS spent_last_month
         FROM transactions
         WHERE wallet_id = $1 AND is_deleted = FALSE`,
         [walletId]
      ),
    ]);

    const category_stats = {};
    for (const row of catRes.rows) {
      category_stats[row.category_code] = {
        frequency_week: Number(row.frequency_week) || 0,
        avg_amount:     Number(row.avg_amount) || 0,
        month_total:    Number(row.month_total) || 0,
        pct:            Number(row.pct) || 0,
      };
    }

    if (walletRes.rows[0]) {
      const row = walletRes.rows[0];
      
      const nowDt = new Date();
      // Shift to UTC+7 for local Vietnamese time context
      const localTime = new Date(nowDt.getTime() + 7 * 3600000);
      const hour = localTime.getUTCHours();
      let time_of_day = 'sáng';
      if (hour >= 11 && hour < 14) time_of_day = 'trưa';
      else if (hour >= 14 && hour < 18) time_of_day = 'chiều';
      else if (hour >= 18 && hour < 22) time_of_day = 'tối';
      else if (hour >= 22 || hour < 5) time_of_day = 'đêm khuya';
      
      const day_of_month = localTime.getUTCDate();
      const days_to_payday = day_of_month <= 25 ? (25 - day_of_month) : (30 - day_of_month + 25);
      const lat = contextMeta?.lat;
      const lng = contextMeta?.lng;
      const weather = await weatherService.getWeather(lat, lng);
      
      const data = {
        budget_total:     Number(row.budget_total) || 0,
        budget_remain:    Number(row.budget_remain) || 0,
        spent_today:      Number(spendRes.rows[0]?.spent_today) || 0,
        spent_week:       Number(spendRes.rows[0]?.spent_week) || 0,
        spent_month:      Number(spendRes.rows[0]?.spent_month) || 0,
        spent_last_month: Number(spendRes.rows[0]?.spent_last_month) || 0,
        wallet_type:      row.wallet_type,
        member_count:     Number(row.member_count) || 0,
        category_stats,
        time_of_day,
        day_of_month,
        days_to_payday,
        weather,
      };
      
      if (row.wallet_type === 'shared') {
        data.group_analytics_prompt = 'Bạn đang xem xét báo cáo của Ví Nhóm. Hãy sử dụng văn phong tập thể, nhắc nhở các thành viên trong nhóm về việc chi tiêu, đóng quỹ và các sự kiện chung. Phân tích phải tập trung vào việc chia sẻ chi phí (Split) và dòng tiền của nhóm (Settlement).';
      }
      
      walletProfileCache.set(cacheKey, { data, expiresAt: now + 30000 });
      return data;
    }
  } catch (_) {}
  return null;
}

async function expenseFromText(userId, payload) {
  let profile = await _fetchWalletProfile(userId, payload.walletId);
  let emotion = null;
  let username = 'bạn';
  if (userId) {
    try {
      const userRes = await query('SELECT username FROM users WHERE id = $1', [userId]);
      if (userRes.rows[0]?.username) {
        username = userRes.rows[0].username;
      }
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      emotion = mapVerbalStyleToEmotion(verbalStyle);
    } catch (_) {}
  }
  if (!profile) {
    profile = { username };
  } else {
    profile.username = username;
  }
  const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
  const aiResponse = await aiClient.expenseFromText({
    text: payload.text,
    user_id: userId,
    profile,
    run_llm: true,
    emotion,
    user_corrections: userCorrections,
  });
  await logAi(userId, 'expense_from_text', payload, aiResponse, {
    backend: aiResponse.nlu?.backend,
    latency_ms: aiResponse.latency_ms,
    confidence: aiResponse.extracted?.confidence,
  });
  const extracted = aiResponse.extracted || {};
  let savedTx = null;
  const isRecord = aiResponse.nlu?.intent === 'Record';
  if (
    payload.autoSave &&
    isRecord &&
    !aiResponse.requires_category_selection
  ) {
    const isDraft = !extracted.amount || extracted.amount <= 0;
    savedTx = await txService.create(userId, {
      walletId: payload.walletId,
      amount: isDraft ? 0 : extracted.amount,
      type: extracted.record_type === 'Income' ? 'income' : 'expense',
      source: 'text',
      categoryCode: extracted.category || 'Others',
      note: extracted.note || payload.text,
      occurredAt: payload.occurredAt,
      aiExtracted: true,
      aiConfidence: extracted.confidence ?? null,
      aiMeta: { nlu: aiResponse.nlu },
      isDraft,
    });
    // Invalidate wallet profile cache on new transaction
    walletProfileCache.delete(`${userId}:${payload.walletId}`);
  }
  return {
    extracted,
    nlu: aiResponse.nlu,
    requires_category_selection: aiResponse.requires_category_selection || false,
    transaction: savedTx,
  };
}

async function expenseFromTextAsync(userId, payload) {
  // Create PENDING placeholder transaction immediately
  const pendingTx = await query(
    `INSERT INTO transactions
       (wallet_id, creator_id, amount, type, source, processing_status, occurred_at)
     VALUES ($1, $2, 0, 'expense', 'text', 'pending', NOW())
     RETURNING id`,
    [payload.walletId, userId]
  );
  const transactionId = pendingTx.rows[0].id;

  // Run in background
  setImmediate(() => _processTextBackground(userId, transactionId, payload));

  return { transactionId, status: 'pending' };
}

async function _processTextBackground(userId, transactionId, payload) {
  const { sendToUser } = require('../../services/wsHub');
  try {
    let profile = await _fetchWalletProfile(userId, payload.walletId);
    let emotion = null;
    let username = 'bạn';
    if (userId) {
      try {
        const userRes = await query('SELECT username FROM users WHERE id = $1', [userId]);
        if (userRes.rows[0]?.username) {
          username = userRes.rows[0].username;
        }
        const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
        const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
        emotion = mapVerbalStyleToEmotion(verbalStyle);
      } catch (_) {}
    }
    if (!profile) {
      profile = { username };
    } else {
      profile.username = username;
    }
    const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
    const aiResponse = await aiClient.expenseFromText({
      text: payload.text,
      user_id: userId,
      profile,
      run_llm: true,
      emotion,
      user_corrections: userCorrections,
    });
    await logAi(userId, 'expense_from_text', payload, aiResponse, {
      backend: aiResponse.nlu?.backend,
      latency_ms: aiResponse.latency_ms,
      confidence: aiResponse.extracted?.confidence,
    });

    const extracted = aiResponse.extracted || {};
    const isRecord = aiResponse.nlu?.intent === 'Record';
    
    // Auto-save logic: If it's a Record intent, high confidence, and no missing category
    const confidence = extracted.confidence ?? 0;
    const isCertain = isRecord && !aiResponse.requires_category_selection && extracted.amount && extracted.amount > 0 && confidence > 0.8;
    const needsReview = !isCertain;

    const finalAmount = extracted.amount && extracted.amount > 0 ? extracted.amount : 0;
    const recordType = extracted.record_type === 'Income' ? 'income' : 'expense';
    let finalCategoryCode = extracted.category || 'Others';

    if (extracted.category) {
      const normalizedMap = {
        'Food': 'Food & Drink',
        'Transport': 'Transportation',
        'Others': 'Other',
      };
      const mappedCategory = normalizedMap[extracted.category] || extracted.category;
      const catRes = await query(
        `SELECT id, code FROM categories 
         WHERE (LOWER(code) = LOWER($1) OR LOWER(name) = LOWER($1) OR LOWER(code) = LOWER($2) OR LOWER(name) = LOWER($2))
           AND (owner_id IS NULL OR owner_id = $3)
         ORDER BY owner_id NULLS FIRST LIMIT 1`,
        [extracted.category, mappedCategory, userId]
      );
      if (catRes.rows[0]) {
        finalCategoryCode = catRes.rows[0].code;
      } else {
        finalCategoryCode = mappedCategory;
      }
    }

    const aiMeta = {
      nlu: aiResponse.nlu,
      requires_category_selection: aiResponse.requires_category_selection,
    };

    const finalStatus = needsReview ? 'pending_review' : 'completed';

    await query('BEGIN');
    
    // Update the pending transaction
    await query(
      `UPDATE transactions
       SET amount = $1, type = $2, category_code = $3, note = $4,
           ai_extracted = TRUE, ai_confidence = $5, ai_meta = $6,
           processing_status = $7,
           is_draft = $8,
           updated_at = NOW()
       WHERE id = $9`,
      [
        finalAmount,
        recordType,
        finalCategoryCode,
        extracted.note || payload.text,
        extracted.confidence ?? null,
        aiMeta,
        finalStatus,
        needsReview, // Draft if needs review
        transactionId
      ]
    );

    // If completed (auto-saved), create story items
    if (!needsReview) {
      // Find wallet name
      let sourceName = 'Ví cá nhân';
      if (payload.walletId) {
        const walletRes = await query('SELECT name FROM wallets WHERE id = $1', [payload.walletId]);
        if (walletRes.rows[0]) sourceName = walletRes.rows[0].name;
      }
      const isIncome = recordType === 'income';
      const summaryText = `${isIncome ? 'Thu' : 'Chi'} ${finalAmount.toLocaleString('vi-VN')}đ cho ${finalCategoryCode}`;

      const storyRes = await query(
        `INSERT INTO stories (user_id, wallet_id, type)
         VALUES ($1, $2, 'single') RETURNING id`,
        [userId, payload.walletId]
      );
      const storyId = storyRes.rows[0].id;

      const storyItemRes = await query(
        `INSERT INTO story_items (story_id, raw_text, type)
         VALUES ($1, $2, 'text') RETURNING id`,
        [storyId, payload.text]
      );
      const storyItemId = storyItemRes.rows[0].id;

      await query(
        `UPDATE transactions SET story_item_id = $1 WHERE id = $2`,
        [storyItemId, transactionId]
      );

      // Create AI Comment
      const aiCommentContent = aiResponse.nlg?.response || summaryText;
      const aiEmotion = aiResponse.nlg?.emotion || 'Happy';
      await query(
        `INSERT INTO ai_comments (story_id, transaction_id, content_text, emotion)
         VALUES ($1, $2, $3, $4)`,
        [storyId, transactionId, aiCommentContent, aiEmotion]
      );
      
      // Update wallet balance
      if (payload.walletId) {
        if (recordType === 'expense') {
          await query('UPDATE wallets SET balance = balance - $1 WHERE id = $2', [finalAmount, payload.walletId]);
        } else {
          await query('UPDATE wallets SET balance = balance + $1 WHERE id = $2', [finalAmount, payload.walletId]);
        }
      }
      walletProfileCache.delete(`${userId}:${payload.walletId}`);
    }

    await query('COMMIT');

    sendToUser(userId, {
      type: 'transaction_done',
      transactionId,
      data: {
        status: 'done',
        needsReview,
        extracted,
        nlu: aiResponse.nlu,
        requires_category_selection: aiResponse.requires_category_selection || false,
        confidence,
        amount: finalAmount,
        categoryCode: finalCategoryCode,
        note: extracted.note || payload.text,
        storyId,
        aiComment: aiResponse.nlg?.response || summaryText,
        mascotMood: aiResponse.nlg?.emotion || 'Happy'
      }
    });
  } catch (err) {
    await query('ROLLBACK').catch(() => {});
    logger.error({ err: err.message, stack: err.stack, transactionId }, 'Background text NLU failed');
    await query(
      `UPDATE transactions SET processing_status = 'failed', updated_at = NOW() WHERE id = $1`,
      [transactionId]
    ).catch(() => {});
    sendToUser(userId, {
      type: 'transaction_failed',
      transactionId,
      error: 'Lỗi khi phân tích ngữ nghĩa: ' + err.message,
    });
  }
}


async function _processBillBackground(userId, walletId, transactionId, fileBuffer, originalName, contentType, imageUrl) {
  const { sendToUser } = require('../../services/wsHub');
  try {
    const aiResponse = await aiClient.expenseFromBill(
      fileBuffer,
      originalName || 'bill.jpg',
      userId,
      contentType || 'image/jpeg'
    );
    await logAi(userId, 'expense_from_bill', { filename: originalName }, aiResponse, {
      backend: aiResponse.ocr?.backend,
      latency_ms: aiResponse.latency_ms,
      confidence: aiResponse.extracted?.confidence,
    });
    
    // Resolve Date Convergence setting
    const sysSettings = await _getSystemSettings();
    const dateFallback = sysSettings.dateFallback || 'transaction';
    
    let occurredAt = new Date();
    let dateExtracted = false;
    
    const timestampStr = aiResponse.ocr?.kie_fields?.TIMESTAMP;
    if (timestampStr) {
      const parsedDate = parseBillDate(timestampStr);
      if (parsedDate) {
        occurredAt = parsedDate;
        dateExtracted = true;
      }
    }
    
    if (dateFallback === 'current' && !dateExtracted) {
      occurredAt = new Date();
    } else if (dateFallback === 'reject' && !dateExtracted) {
      throw new Error('Date Convergence Policy: Missing or invalid receipt date.');
    }

    const extracted = aiResponse.extracted || {};
    
    // Verify if it is a valid receipt image. 
    // A valid bill MUST have an amount > 0.
    // If it has no amount, it's either a normal image or an unreadable bill.
    const hasNoAmount = !extracted.amount || extracted.amount <= 0;
    if (hasNoAmount) {
      throw new Error('Không tìm thấy số tiền trên hóa đơn. Vui lòng đảm bảo ảnh chụp là hóa đơn rõ ràng.');
    }

    const personalizationKeyword = resolveKeywordFromOcrPayload(
      aiResponse.ocr || {},
      extracted.note || null
    );
    let categoryId = null;
    let finalCategoryCode = extracted.category || null;
    if (extracted.category) {
      const normalizedMap = {
        'Food': 'Food & Drink',
        'Transport': 'Transportation',
        'Others': 'Other',
      };
      const mappedCategory = normalizedMap[extracted.category] || extracted.category;
      const catRes = await query(
        `SELECT id, code FROM categories 
         WHERE (LOWER(code) = LOWER($1) OR LOWER(name) = LOWER($1) OR LOWER(code) = LOWER($2) OR LOWER(name) = LOWER($2))
           AND (owner_id IS NULL OR owner_id = $3)
         ORDER BY owner_id NULLS FIRST LIMIT 1`,
        [extracted.category, mappedCategory, userId]
      );
      if (catRes.rows[0]) {
        categoryId = catRes.rows[0].id;
        finalCategoryCode = catRes.rows[0].code;
      } else {
        finalCategoryCode = mappedCategory;
      }
    }

    // Tạo story + ai_comment để story feed hiển thị mascot + comment LLM (giống luồng nhập tay)
    const nlu = aiResponse.nlu || {};
    const llmStory =
      nlu.gemini_json?.response ||
      nlu.gemini_json?.story ||
      nlu.nlg_response ||
      nlu.response ||
      null;
    const billIntent = nlu.intent || 'Record';
    const mascotMood = pickMimoEmotionFromNlu(nlu, billIntent);

    let storyId = null;
    let storyItemId = null;
    try {
      const storyRes = await query(
        `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [userId, walletId, extracted.note || extracted.category || 'Hóa đơn', extracted.amount || 0, imageUrl, occurredAt]
      );
      storyId = storyRes.rows[0].id;
      const itemRes = await query(
        `INSERT INTO story_items (story_id, raw_text, media_url, media_type)
         VALUES ($1, $2, $3, $4) RETURNING id`,
        [storyId, extracted.note || null, imageUrl, imageUrl ? 'image' : 'text']
      );
      storyItemId = itemRes.rows[0].id;
      if (llmStory) {
        await query(
          `INSERT INTO ai_comments (story_id, content_text, visual_state, emotion)
           VALUES ($1, $2, $3, $4)`,
          [storyId, llmStory, mascotMood, mascotMood]
        );
      }
    } catch (e) {
      logger.warn({ err: e.message, transactionId }, 'bill story/ai_comment creation failed');
    }

    await query(
      `UPDATE transactions SET
         category_id       = COALESCE($1, category_id),
         category_code     = COALESCE($2, category_code),
         amount            = COALESCE($3, amount),
         type              = COALESCE($4::varchar, type),
         note              = COALESCE($5, note),
         ai_extracted      = TRUE,
         ai_confidence     = $6,
         ai_meta           = $7,
         story_item_id     = COALESCE($8, story_item_id),
         processing_status = 'done',
         occurred_at       = $10,
         updated_at        = NOW()
       WHERE id = $9`,
      [
        categoryId,
        finalCategoryCode,
        extracted.amount || null,
        extracted.record_type === 'Income' ? 'income' : extracted.amount ? 'expense' : null,
        extracted.note || null,
        extracted.confidence != null ? Number(extracted.confidence) : null,
        { nlu: aiResponse.nlu, ocr: aiResponse.ocr, image_url: imageUrl, personalizationKeyword },
        storyItemId,
        transactionId,
        occurredAt,
      ]
    );

    // Invalidate wallet profile cache
    walletProfileCache.delete(`${userId}:${walletId}`);

    try {
      const confidence = extracted.confidence != null ? Number(extracted.confidence) : null;
      await query(
        `INSERT INTO ai_processing_logs (ocr_raw_json, nlp_intent_json, final_decision_json, confidence)
         VALUES ($1, $2, $3, $4)`,
        [
          aiResponse.ocr || {},
          aiResponse.nlu || {},
          { amount: extracted.amount || null, category: extracted.category || null,
            record_type: extracted.record_type || null, note: extracted.note || null,
            backend: aiResponse.ocr?.backend || 'mock', latency_ms: aiResponse.latency_ms || null,
            image_url: imageUrl, filename: originalName || null },
          confidence,
        ]
      );
    } catch (_) {}

    // Auto-enqueue bill vào hàng đợi retrain cho admin review (sau WS — không chặn user)
    sendToUser(userId, {
      type: 'transaction_done',
      transactionId,
      data: {
        amount: extracted.amount,
        category: extracted.category,
        record_type: extracted.record_type,
        note: extracted.note,
        imageUrl,
        storyId,
        mascot_mood: aiResponse.nlu?.mascot_mood || null,
        ai_confidence: extracted.confidence != null ? Number(extracted.confidence) : null,
        story:
          aiResponse.nlu?.gemini_json?.response ||
          aiResponse.nlu?.gemini_json?.story ||
          null,
      },
    });

    setImmediate(() => {
      try {
        const retrainStore = require('../../services/billRetrainStore');
        const crypto = require('crypto');
        const ext = path.extname(originalName || 'bill.jpg') || '.jpg';
        const sampleId = crypto.randomUUID();
        const localUrl = retrainStore.saveImage(sampleId, fileBuffer, ext);
        const finalImageUrl = imageUrl || localUrl;
        const ocrPayload = aiResponse.ocr || {};
        retrainStore.upsertSample({
          id: sampleId,
          status: 'pending',
          source: 'user_upload',
          userId,
          transactionId,
          imageUrl: finalImageUrl,
          imageExt: ext,
          autoLabels: {
            boxes: ocrPayload.boxes || [],
            kie_fields: ocrPayload.kie_fields || {},
            kie_backend: ocrPayload.backend || ocrPayload.kie_backend || 'unknown',
            amount: extracted.amount,
            category: extracted.category,
          },
          metadata: {
            amount: extracted.amount,
            category: extracted.category,
            confidence: extracted.confidence,
            originalName,
            backend: aiResponse.ocr?.backend || 'unknown',
          },
        });
        logger.info({ sampleId, transactionId, userId }, 'Auto-enqueued user bill for retrain');
      } catch (enqueueErr) {
        logger.warn({ err: enqueueErr.message, transactionId }, 'Failed to auto-enqueue bill for retrain');
      }
    });
  } catch (err) {
    logger.error({ err: err.message, transactionId }, 'bill background job failed');
    await query(
      `DELETE FROM transactions WHERE id = $1`,
      [transactionId]
    ).catch(() => {});

    if (imageUrl) {
      try {
        const r2Client = require('../../services/r2Client');
        const env = require('../../config/env');
        if (env.r2.publicBaseUrl) {
          const key = imageUrl.replace(env.r2.publicBaseUrl, '').replace(/^\//, '');
          await r2Client.deleteFile(key);
        }
      } catch (r2Err) {
        logger.warn({ err: r2Err.message, imageUrl }, 'Failed to delete failed bill image from R2');
      }
    }

    sendToUser(userId, { type: 'transaction_failed', transactionId, error: err.message });
  }
}

async function expenseFromBill(userId, fileBuffer, originalName, contentType, walletId) {
  if (!fileBuffer || fileBuffer.length === 0) {
    throw ApiError.badRequest('Empty file.');
  }

  let imageUrl = null;
  if (r2Client.isConfigured()) {
    try {
      const uploaded = await r2Client.uploadBuffer(userId, fileBuffer, {
        filename: originalName || 'bill.jpg',
        contentType: contentType || 'image/jpeg',
      });
      imageUrl = uploaded.publicUrl || null;
    } catch (err) {
      logger.warn({ err: err.message }, 'R2 upload failed, continuing without persisted image');
    }
  }

  // Create PENDING placeholder transaction immediately
  const pendingTx = await query(
    `INSERT INTO transactions
       (wallet_id, creator_id, amount, type, source, image_url, processing_status, occurred_at)
     VALUES ($1, $2, 0, 'expense', 'bill', $3, 'pending', NOW())
     RETURNING id`,
    [walletId, userId, imageUrl]
  );
  const transactionId = pendingTx.rows[0].id;

  // Fire background job — do NOT await, use semaphore to limit concurrency
  setImmediate(() =>
    ocrSemaphore.run(() =>
      _processBillBackground(userId, walletId, transactionId, fileBuffer, originalName, contentType, imageUrl)
    )
  );

  return { transactionId, status: 'pending', imageUrl };
}

async function _fetchUserCorrections(userId) {
  if (!userId) return [];
  const now = Date.now();
  const cached = userCorrectionsCache.get(userId);
  if (cached && cached.expiresAt > now) {
    return cached.data;
  }

  try {
    const [correctionsRes, overridesRes] = await Promise.all([
      query(
        `SELECT DISTINCT ON (clean_text)
                text, intent, "categoryCode", "recordType"
         FROM (
           SELECT text, intent, category_code AS "categoryCode", record_type AS "recordType",
                  LOWER(TRIM(text)) as clean_text, created_at
           FROM user_corrections
           WHERE user_id = $1
         ) tmp
         ORDER BY clean_text, created_at DESC`,
        [userId]
      ),
      query(
        `SELECT keyword AS text, category_code AS "categoryCode"
         FROM user_category_mappings
         WHERE user_id = $1`,
        [userId]
      )
    ]);

    const corrections = correctionsRes.rows.map(r => ({
      text: r.text,
      intent: r.intent || 'Record',
      category_code: r.categoryCode || null,
      record_type: r.recordType || null,
    }));

    const overrides = overridesRes.rows.map(r => ({
      text: r.text,
      intent: 'Record',
      category_code: r.categoryCode || null,
      record_type: 'Expense',
    }));

    const merged = [...overrides];
    const seenTexts = new Set(overrides.map(o => o.text.toLowerCase().trim()));

    for (const corr of corrections) {
      const cleanT = corr.text.toLowerCase().trim();
      if (!seenTexts.has(cleanT)) {
        seenTexts.add(cleanT);
        merged.push(corr);
      }
    }

    userCorrectionsCache.set(userId, { data: merged, expiresAt: now + 30000 });
    return merged;
  } catch (err) {
    logger.warn({ err: err.message, userId }, 'failed to fetch user corrections and overrides');
    return [];
  }
}

async function saveCorrection(userId, payload) {
  let keywordText = payload.text;

  if (payload.transactionId) {
    try {
      const txRes = await query(
        `SELECT source, note, ai_meta FROM transactions WHERE id = $1 AND creator_id = $2 AND is_deleted = FALSE`,
        [payload.transactionId, userId]
      );
      if (txRes.rowCount > 0) {
        const resolved = resolveCategoryCorrectionKeyword(txRes.rows[0]);
        if (resolved) keywordText = resolved;
      }
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'failed to resolve correction keyword from transaction');
    }
  } else if (isInvalidPersonalizationKeyword(keywordText)) {
    keywordText = null;
  }

  const r = await query(
    `INSERT INTO user_corrections
       (user_id, text, intent, category_code, record_type, action_type, predicted, source)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'user')
     RETURNING id, created_at`,
    [
      userId,
      keywordText || payload.text || '',
      payload.intent || null,
      payload.categoryCode || null,
      payload.recordType || null,
      payload.actionType || null,
      payload.predicted || null,
    ]
  );

  // If a category was corrected, update user_category_mappings (Layer 1 exact override)
  if (payload.categoryCode && keywordText && (payload.intent === 'Record' || !payload.intent)) {
    const cleanedText = keywordText.trim().toLowerCase();
    if (cleanedText && !isInvalidPersonalizationKeyword(cleanedText)) {
      await query(
        `INSERT INTO user_category_mappings (user_id, keyword, category_code, updated_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (user_id, keyword)
         DO UPDATE SET category_code = EXCLUDED.category_code, updated_at = NOW()`,
        [userId, cleanedText, payload.categoryCode]
      ).catch(err => {
        logger.warn({ err: err.message, userId }, 'failed to update user_category_mappings');
      });
    }
  }

  userCorrectionsCache.delete(userId);
  return r.rows[0];
}

async function isActionConfirmed(userId, actionSignature) {
  const r = await query(
    `SELECT 1 FROM user_confirmed_actions WHERE user_id = $1 AND action_signature = $2`,
    [userId, actionSignature]
  );
  return r.rowCount > 0;
}

async function confirmAction(userId, payload) {
  await query(
    `INSERT INTO user_confirmed_actions (user_id, action_signature, action_type)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, action_signature) DO NOTHING`,
    [userId, payload.actionSignature, payload.actionType || null]
  );
}

async function rejectAction(userId, payload) {
  const predicted = payload.predicted || null;
  await query(
    `INSERT INTO action_rejected_log (user_id, text, predicted)
     VALUES ($1, $2, $3)`,
    [userId, payload.text || null, predicted ? JSON.stringify(predicted) : null]
  );

  // Append misclassified action samples for future NLU retraining
  if (payload.text && predicted?.action_type) {
    try {
      const fs = require('fs');
      const path = require('path');
      const env = require('../../config/env');
      const nluRoot = path.resolve(__dirname, '../../../../../expense-ocr-nlu');
      const outDir = path.join(nluRoot, 'text_nlu', 'datasets');
      fs.mkdirSync(outDir, { recursive: true });
      const outFile = path.join(outDir, 'action_rejected_samples.jsonl');
      const row = JSON.stringify({
        text: payload.text,
        predicted_action_type: predicted.action_type,
        predicted_intent: predicted.intent || 'Action',
        user_id: userId,
        rejected_at: new Date().toISOString(),
      });
      fs.appendFileSync(outFile, `${row}\n`, 'utf8');
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'failed to append action_rejected sample');
    }
  }
}

function summarizeOlderMessages(olderMessages) {
  if (!olderMessages || olderMessages.length === 0) return null;
  const actions = olderMessages
    .filter(m => m.role === 'assistant' && m.intent_action?.intent === 'Action')
    .map(m => {
      const act = m.intent_action;
      const label = act.nlu?.action_type || act.intent || 'Thao tác';
      return `${label}`;
    });
  const uniqActions = [...new Set(actions)];
  if (uniqActions.length > 0) {
    return `Người dùng đã thực hiện các thao tác trước đó: ${uniqActions.join(', ')}.`;
  }
  return 'Người dùng đang trò chuyện tự do.';
}

function extractLlmTextFromResponse(res) {
  if (!res) return null;
  return (
    res.gemini_json?.response ||
    res.gemini_json?.story ||
    res.nlg_response ||
    res.response ||
    res.content ||
    null
  );
}

async function _runChatLlmFollowUp(userId, sessionId, messageId, context) {
  const { sendToUser } = require('../../services/wsHub');
  const chatService = require('../chat/chat.service');

  try {
    const {
      userMessage,
      aiResponse,
      emotion,
      profile,
      userCorrections,
      summary,
      slidingWindow,
    } = context;

    const intent = aiResponse.intent || 'Chitchat';
    const actionType = aiResponse.action_type;
    let llmRes;

    if (intent === 'Action' && actionService.isReportAction(actionType) && aiResponse.action_result) {
      llmRes = await aiClient.inferText({
        text: userMessage,
        profile: {
          ...(profile || {}),
          action_facts: aiResponse.action_result,
        },
        run_llm: true,
        nlg_persona: emotion || null,
        emotion: emotion || null,
        user_id: userId,
        user_corrections: userCorrections || null,
      });
    } else {
      llmRes = await aiClient.inferText({
        text: userMessage,
        profile: profile || null,
        run_llm: true,
        nlg_persona: emotion || null,
        emotion: emotion || null,
        user_id: userId,
        user_corrections: userCorrections || null,
        chat_history: slidingWindow || null,
        chat_summary: summary || null,
      });
    }

    const llmText = extractLlmTextFromResponse(llmRes);
    if (!llmText || !String(llmText).trim()) {
      sendToUser(userId, { type: 'chat_llm_update', sessionId, messageId, failed: true });
      return;
    }

    const mergedNlu = {
      ...(aiResponse || {}),
      ...(llmRes || {}),
      gemini_json: llmRes.gemini_json || aiResponse.gemini_json,
      llama_json: llmRes.llama_json || aiResponse.llama_json,
      nlg_response: llmText,
    };
    const mood = pickMimoEmotionFromNlu(mergedNlu, intent);
    const intentActionPatch = {
      mood,
      llmUpdated: true,
      nlu: mergedNlu,
    };

    await chatService.updateMessageContent(userId, sessionId, messageId, llmText, intentActionPatch);

    const completeIntentAction = {
      ...intentActionPatch,
      intent: intent,
      amount: mergedNlu.amount ?? mergedNlu.amount_spent,
      category: mergedNlu.category,
      nlu: mergedNlu,
    };
    if (mergedNlu.multi_records && Array.isArray(mergedNlu.multi_records) && mergedNlu.multi_records.length >= 2) {
      completeIntentAction.multi_records = mergedNlu.multi_records.map(r => ({
        text: r.text || '',
        amount: Number(r.amount) || 0,
        category: r.category || 'Other',
        record_type: r.record_type || 'Expense',
      }));
    }

    sendToUser(userId, {
      type: 'chat_llm_update',
      sessionId,
      messageId,
      content: llmText,
      mood,
      intentAction: completeIntentAction,
    });
  } catch (err) {
    logger.warn({ err: err.message, userId, sessionId, messageId }, 'chat LLM follow-up failed');
    sendToUser(userId, { type: 'chat_llm_update', sessionId, messageId, failed: true });
  }
}

async function aiChat(userId, sessionId, userMessage, contextMeta) {
  const chatService = require('../chat/chat.service');
  
  // Get recent messages for context
  const recentMessagesRes = await chatService.getMessages(userId, sessionId, { limit: 20 });
  const recentMessages = recentMessagesRes.messages || [];
  const allMessages = recentMessages.map(m => ({
    role: m.role,
    content: m.content,
    intent_action: m.intent_action || {},
  }));
  allMessages.push({ role: 'user', content: userMessage, intent_action: {} });

  const slidingWindow = allMessages.slice(-4);
  const olderMessages = allMessages.slice(0, -4);
  const summary = summarizeOlderMessages(olderMessages);

  let emotion = null;
  let username = 'bạn';
  if (userId) {
    try {
      const userRes = await query('SELECT username FROM users WHERE id = $1', [userId]);
      if (userRes.rows[0]?.username) {
        username = userRes.rows[0].username;
      }
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      emotion = mapVerbalStyleToEmotion(verbalStyle);
    } catch (_) {}
  }

  let walletId = null;
  try {
    const sessionRes = await query(
      `SELECT wallet_id FROM chat_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId]
    );
    if (sessionRes.rows[0]?.wallet_id) {
      walletId = sessionRes.rows[0].wallet_id;
    } else {
      const walletRes = await query(
        `SELECT wallet_id FROM wallet_members WHERE user_id = $1 LIMIT 1`,
        [userId]
      );
      if (walletRes.rows[0]) {
        walletId = walletRes.rows[0].wallet_id;
      }
    }
  } catch (_) {}

  let profile = null;
  if (walletId) {
    profile = await _fetchWalletProfile(userId, walletId);
    if (profile && contextMeta) {
      if (contextMeta.local_hour != null) {
        const hour = Number(contextMeta.local_hour);
        let time_of_day = 'sáng';
        if (hour >= 11 && hour < 14) time_of_day = 'trưa';
        else if (hour >= 14 && hour < 18) time_of_day = 'chiều';
        else if (hour >= 18 && hour < 22) time_of_day = 'tối';
        else if (hour >= 22 || hour < 5) time_of_day = 'đêm khuya';
        profile.time_of_day = time_of_day;
      }
      if (contextMeta.local_day_of_month != null) {
        profile.day_of_month = Number(contextMeta.local_day_of_month);
        const day = profile.day_of_month;
        profile.days_to_payday = day <= 25 ? (25 - day) : (30 - day + 25);
      }
      const lat = contextMeta.lat;
      const lng = contextMeta.lng;
      profile.weather = await weatherService.getWeather(lat, lng);
    }
  }
  if (!profile) {
    profile = { username };
  } else {
    profile.username = username;
  }

  const userCorrections = userId ? await _fetchUserCorrections(userId) : [];
  try {
    let aiResponse = await aiClient.aiChat(slidingWindow, userId, {
      emotion,
      profile,
      user_corrections: userCorrections,
      chat_history: slidingWindow,
      chat_summary: summary,
      run_llm: true,
    });
    if (aiResponse.intent === 'Action' && aiResponse.action_type) {
      aiResponse.action_type = actionService.disambiguateActionType(
        userMessage,
        aiResponse.action_type
      );
    }
    aiResponse = await _enrichNluWithAction(userId, { text: userMessage }, aiResponse);
    const llmText =
      aiResponse.gemini_json?.response ||
      aiResponse.gemini_json?.story ||
      aiResponse.nlg_response ||
      aiResponse.response ||
      aiResponse.content;
    const llmError = aiResponse.llm_error || null;

    let fallbackText = null;
    if (!llmText) {
      const intent = aiResponse.intent || 'Chitchat';
      if (intent === 'Record') {
        const isIncome = aiResponse.record_type === 'Income';
        const categoryCode = aiResponse.category || 'Others';
        const amount = aiResponse.amount ?? aiResponse.amount_spent;

        const vietCategoryMap = {
          'Food': 'Ăn uống',
          'Transport': 'Di chuyển',
          'Housing': 'Nhà ở',
          'Shopping': 'Mua sắm',
          'Entertainment': 'Giải trí',
          'Health': 'Sức khỏe',
          'Education': 'Giáo dục',
          'Others': 'Tiêu dùng khác',
          'Other': 'Tiêu dùng khác',
          'Essentials': 'Thiết yếu',
          'Beauty': 'Làm đẹp',
          'Social': 'Xã hội',
          'Salary': 'Lương',
          'Bonus': 'Thưởng',
          'Business': 'Kinh doanh'
        };
        const vietCat = vietCategoryMap[categoryCode] || categoryCode;

        if (amount && amount > 0) {
          const amtStr = new Intl.NumberFormat('vi-VN').format(amount);
          if (isIncome) {
            fallbackText = `Tuyệt vời! Mimo đã ghi nhận khoản thu nhập ${amtStr}đ vào danh mục ${vietCat}. Tích tiểu thành đại, cố gắng phát huy nhé! 🎉`;
          } else {
            fallbackText = `Mimo đã ghi nhận khoản chi ${amtStr}đ cho ${vietCat} vào ví của bạn. Hãy cân đối chi tiêu hợp lý nhé!`;
          }
        } else {
          if (isIncome) {
            fallbackText = `Mimo đã chuẩn bị sẵn phiếu ghi nhận thu nhập cho danh mục ${vietCat}. Bạn hãy nhập số tiền và bấm lưu nhé!`;
          } else {
            fallbackText = `Mimo đã chuẩn bị sẵn phiếu ghi nhận chi tiêu cho danh mục ${vietCat}. Bạn hãy nhập số tiền và bấm lưu nhé!`;
          }
        }
      } else if (intent === 'Action') {
        const actionType = (aiResponse.action_type || 'Thao tác').toUpperCase();
        const hardcodedActions = ['REPORT_GENERAL', 'REPORT_COMPARE', 'SEARCH_RECORD', 'SUGGEST_BUDGET'];

        if (hardcodedActions.includes(actionType)) {
          const actionLabels = {
            'REPORT_GENERAL': 'Xem báo cáo tổng quan',
            'REPORT_COMPARE': 'So sánh chi tiêu',
            'SEARCH_RECORD': 'Tìm kiếm giao dịch',
            'SUGGEST_BUDGET': 'Gợi ý hạn mức thông minh'
          };
          const actionLabel = actionLabels[actionType] || 'Thao tác';
          fallbackText = `Mimo đã chuẩn bị sẵn dữ liệu: ${actionLabel}. Bạn hãy xem qua nhé!`;
          llmText = ''; // Force override to use the hardcoded string
        } else {
          // Use LLM response for SET_LIMIT, SET_GOAL, SET_USERNAME, etc.
          // Fallback text only if LLM failed to generate anything
          fallbackText = `Mimo đã chuẩn bị sẵn thao tác cho bạn. Bạn có muốn thực hiện không?`;
        }
      }
    }

    if (!llmText && fallbackText) {
      if (!aiResponse.gemini_json) {
        aiResponse.gemini_json = {};
      }
      aiResponse.gemini_json.response = fallbackText;
      aiResponse.gemini_json.story = fallbackText;
      if (!aiResponse.nlg_response) {
        aiResponse.nlg_response = fallbackText;
      }
    }

    const assistantContent = llmText || fallbackText || (llmError
      ? 'Mimo tạm thời gặp sự cố kết nối AI 🤖 Bạn thử lại sau chút nhé!'
      : 'Xin lỗi, tôi không hiểu. Bạn có thể nói rõ hơn không?');
    if (!llmText) {
      logger.warn({ userId, sessionId, llmError, backend: aiResponse.backend }, 'LLM response empty — using fallback text');
    }

    // Parse and normalize the LLM/NLU emotion to PascalCase asset name
    const geminiJson = aiResponse.gemini_json;
    const llamaJson = aiResponse.llama_json;
    const intent = aiResponse.intent || 'Chitchat';
    const amount = aiResponse.amount ?? aiResponse.amount_spent;
    const category = aiResponse.category;
    const moodStatus = pickMimoEmotionFromNlu(aiResponse, intent);

    const intentAction = {
      mood: moodStatus,
      intent: intent,
      amount: amount,
      category: category,
      nlu: aiResponse,
      ...(llmError ? { llmError } : {}),
    };

    if (aiResponse.multi_records && Array.isArray(aiResponse.multi_records) && aiResponse.multi_records.length >= 2) {
      intentAction.multi_records = aiResponse.multi_records.map(r => ({
        text: r.text || '',
        amount: Number(r.amount) || 0,
        category: r.category || 'Other',
        record_type: r.record_type || 'Expense',
      }));
    }

    if (intentAction.intent === 'Record' && intentAction.category) {
      try {
        const categoryCode = intentAction.category;
        const budgetsService = require('../budgets/budgets.service');
        const summaries = await budgetsService.summary(userId);
        const activeBudget = summaries.find(b => b.categoryCode === categoryCode && b.isActive);
        if (!activeBudget) {
          const incomeRes = await query(
            `SELECT COALESCE(SUM(amount), 0) AS total_income 
             FROM transactions 
             WHERE wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
               AND type = 'income' AND is_deleted = FALSE 
               AND date_trunc('month', occurred_at) = date_trunc('month', NOW())`,
            [userId]
          );
          let monthlyIncome = Number(incomeRes.rows[0]?.total_income || 0);
          if (monthlyIncome <= 0) {
            const avgIncomeRes = await query(
              `SELECT COALESCE(AVG(monthly_sum), 0) AS avg_income FROM (
                 SELECT SUM(amount) AS monthly_sum 
                 FROM transactions 
                 WHERE wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = $1)
                   AND type = 'income' AND is_deleted = FALSE
                   AND occurred_at >= NOW() - INTERVAL '3 months'
                 GROUP BY date_trunc('month', occurred_at)
               ) t`,
              [userId]
            );
            monthlyIncome = Number(avgIncomeRes.rows[0]?.avg_income || 0);
          }
          if (monthlyIncome <= 0) {
            monthlyIncome = 8000000;
          }

          const suggestedAmount = Math.round(monthlyIncome * 0.10);
          const targetMonth = new Date().toISOString().substring(0, 7);
          
          intentAction.budget_suggestion = {
            kind: 'budget_suggestion',
            targetMonth: targetMonth,
            suggestions: [
              {
                categoryCode: categoryCode,
                suggestedAmount: suggestedAmount,
                baseSpending: 0,
                reason: `Bạn vừa chi tiêu cho danh mục này nhưng chưa thiết lập hạn mức tháng.`
              }
            ]
          };
        }
      } catch (err) {
        logger.warn({ err: err.message }, 'Failed to check budget suggestion in aiChat');
      }
    }

    // Save AI response to chat session
    const savedMsg = await chatService.addMessage(userId, sessionId, {
      content: assistantContent,
      role: 'assistant',
      intentAction: intentAction,
    });

    const isLlmBackend = (aiResponse.backend === 'llm_unified' || aiResponse.backend === 'llm_fallback' || String(aiResponse.backend).startsWith('user_') || actionService.isReportAction(intentAction.nlu?.action_type));

    if (!isLlmBackend && process.env.NODE_ENV !== 'test') {
      setImmediate(() => {
        _runChatLlmFollowUp(userId, sessionId, savedMsg?.id, {
          userMessage,
          aiResponse,
          emotion,
          profile,
          userCorrections,
          summary,
          slidingWindow,
        }).catch((err) => {
          logger.warn({ err: err.message, userId, sessionId }, 'chat LLM follow-up scheduling failed');
        });
      });
    }

    await logAi(userId, 'chat', { sessionId, userMessage }, aiResponse, {
      backend: aiResponse.backend,
      latency_ms: aiResponse.latency_ms,
    });

    return {
      response: assistantContent,
      intentAction: intentAction,
      messageId: savedMsg?.id,
      llmPending: !isLlmBackend,
    };
  } catch (err) {
    await logAi(userId, 'chat', { sessionId, userMessage }, null, { error: err.message });
    throw err;
  }
}

async function executeAction(userId, payload) {
  const walletId = payload.walletId || (await _resolveWalletId(userId));
  const body = { ...payload, walletId: walletId || undefined };
  const result = await actionService.executeAction(userId, body);
  await logAi(userId, 'action_execute', body, result);
  return result;
}

function clearUserCorrectionsCache(userId) {
  userCorrectionsCache.delete(userId);
}

function clearWalletProfileCache(userId, walletId) {
  walletProfileCache.delete(`${userId}:${walletId}`);
}

module.exports = {
  nluInfer,
  expenseFromText,
  expenseFromTextAsync,
  expenseFromBill,
  saveCorrection,
  isActionConfirmed,
  confirmAction,
  rejectAction,
  executeAction,
  aiChat,
  clearUserCorrectionsCache,
  clearWalletProfileCache,
};
