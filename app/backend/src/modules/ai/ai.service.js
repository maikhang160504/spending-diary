'use strict';

const aiClient = require('../../services/aiClient');
const r2Client = require('../../services/r2Client');
const { query } = require('../../config/db');
const txService = require('../transactions/transactions.service');
const ApiError = require('../../utils/ApiError');
const logger = require('../../config/logger');

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

function mapVerbalStyleToEmotion(style) {
  const mapping = {
    funny: 'hai_huoc',
    gentle: 'dong_cam',
    serious: 'nghiem_tuc',
    sarcastic: 'cham_choc',
    strict: 'dan_doi',
  };
  return mapping[style] || 'hai_huoc';
}

async function nluInfer(userId, payload) {
  let emotion = payload.emotion;
  if (!emotion && userId) {
    try {
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      emotion = mapVerbalStyleToEmotion(verbalStyle);
    } catch (_) {}
  }

  const aiPayload = {
    text: payload.text,
    profile: payload.profile || null,
    run_llm: Boolean(payload.runLlm),
    emotion: emotion || null,
    user_id: userId,
  };
  try {
    const response = await aiClient.inferText(aiPayload);
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
  try {
    const [walletRes, catRes, spendRes] = await Promise.all([
      query(
        `SELECT b.amount_limit AS budget_total,
                GREATEST(0, b.amount_limit - COALESCE(SUM(t.amount) FILTER (WHERE t.type='expense'), 0)) AS budget_remain,
                COUNT(t.id) FILTER (WHERE t.occurred_at >= NOW() - INTERVAL '7 days') AS frequency_week,
                COALESCE(AVG(t.amount) FILTER (WHERE t.type='expense'), 0) AS avg_amount
         FROM wallets w
         LEFT JOIN budgets b ON b.wallet_id = w.id AND b.period = 'monthly'
                             AND date_trunc('month', NOW()) BETWEEN b.start_date AND COALESCE(b.end_date, 'infinity'::date)
         LEFT JOIN transactions t ON t.wallet_id = w.id AND t.is_deleted = FALSE AND t.type = 'expense'
                                  AND date_trunc('month', t.occurred_at) = date_trunc('month', NOW())
         WHERE w.id = $1
         GROUP BY b.amount_limit`,
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
           COALESCE(SUM(amount) FILTER (WHERE type = 'expense' AND occurred_at >= date_trunc('month', NOW())), 0)::numeric AS spent_month
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
      return {
        budget_total:    Number(row.budget_total) || 0,
        budget_remain:   Number(row.budget_remain) || 0,
        frequency_week:  Number(row.frequency_week) || 0,
        avg_amount:      Number(row.avg_amount) || 0,
        spent_today:     Number(spendRes.rows[0]?.spent_today) || 0,
        spent_week:      Number(spendRes.rows[0]?.spent_week) || 0,
        spent_month:     Number(spendRes.rows[0]?.spent_month) || 0,
        category_stats,
      };
    }
  } catch (_) {}
  return null;
}

async function expenseFromText(userId, payload) {
  const profile = await _fetchWalletProfile(userId, payload.walletId);
  let emotion = null;
  if (userId) {
    try {
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      emotion = mapVerbalStyleToEmotion(verbalStyle);
    } catch (_) {}
  }
  const aiResponse = await aiClient.expenseFromText({
    text: payload.text,
    user_id: userId,
    profile,
    run_llm: true,
    emotion,
  });
  await logAi(userId, 'expense_from_text', payload, aiResponse, {
    backend: aiResponse.nlu?.backend,
    latency_ms: aiResponse.latency_ms,
    confidence: aiResponse.extracted?.confidence,
  });
  const extracted = aiResponse.extracted || {};
  let savedTx = null;
  if (
    payload.autoSave &&
    extracted.amount &&
    extracted.amount > 0 &&
    !aiResponse.requires_category_selection
  ) {
    savedTx = await txService.create(userId, {
      walletId: payload.walletId,
      amount: extracted.amount,
      type: extracted.record_type === 'Income' ? 'income' : 'expense',
      source: 'text',
      categoryCode: extracted.category,
      note: extracted.note || payload.text,
      occurredAt: payload.occurredAt,
      aiExtracted: true,
      aiConfidence: extracted.confidence ?? null,
      aiMeta: { nlu: aiResponse.nlu },
    });
  }
  return {
    extracted,
    nlu: aiResponse.nlu,
    requires_category_selection: aiResponse.requires_category_selection || false,
    transaction: savedTx,
  };
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
    const extracted = aiResponse.extracted || {};
    const categoryId = extracted.category
      ? (await query(
          `SELECT id FROM categories WHERE code = $1 LIMIT 1`,
          [extracted.category]
        )).rows[0]?.id || null
      : null;

    // Tạo story + ai_comment để story feed hiển thị mascot + comment LLM (giống luồng nhập tay)
    const nlu = aiResponse.nlu || {};
    const llmStory = nlu.gemini_json?.story || nlu.nlg_response || nlu.response || null;
    let mascotMood =
      nlu.gemini_json?.emotion || nlu.llama_json?.emotion || nlu.mascot_mood || nlu.emotion || 'Chill';
    const verbalToPascal = {
      hai_huoc: 'Sassy',
      dong_cam: 'Approved',
      nghiem_tuc: 'Thinking',
      cham_choc: 'Taunting',
      dan_doi: 'Sad',
    };
    if (verbalToPascal[mascotMood]) mascotMood = verbalToPascal[mascotMood];

    let storyItemId = null;
    try {
      const storyRes = await query(
        `INSERT INTO stories (user_id, wallet_id, title, total_amount, cover_image_url, occurred_on)
         VALUES ($1, $2, $3, $4, $5, CURRENT_DATE) RETURNING id`,
        [userId, walletId, extracted.note || extracted.category || 'Hóa đơn', extracted.amount || 0, imageUrl]
      );
      const storyId = storyRes.rows[0].id;
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
         updated_at        = NOW()
       WHERE id = $9`,
      [
        categoryId,
        extracted.category || null,
        extracted.amount || null,
        extracted.record_type === 'Income' ? 'income' : extracted.amount ? 'expense' : null,
        extracted.note || null,
        extracted.confidence != null ? Number(extracted.confidence) : null,
        { nlu: aiResponse.nlu, ocr: aiResponse.ocr, image_url: imageUrl },
        storyItemId,
        transactionId,
      ]
    );

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

    sendToUser(userId, {
      type: 'transaction_done',
      transactionId,
      data: {
        amount: extracted.amount,
        category: extracted.category,
        record_type: extracted.record_type,
        note: extracted.note,
        imageUrl,
        mascot_mood: aiResponse.nlu?.mascot_mood || null,
        story: aiResponse.nlu?.gemini_json?.story || null,
      },
    });
  } catch (err) {
    logger.error({ err: err.message, transactionId }, 'bill background job failed');
    await query(
      `UPDATE transactions SET processing_status = 'failed', updated_at = NOW() WHERE id = $1`,
      [transactionId]
    ).catch(() => {});
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

  // Fire background job — do NOT await
  setImmediate(() =>
    _processBillBackground(userId, walletId, transactionId, fileBuffer, originalName, contentType, imageUrl)
  );

  return { transactionId, status: 'pending', imageUrl };
}

async function saveCorrection(userId, payload) {
  const r = await query(
    `INSERT INTO user_corrections
       (user_id, text, intent, category_code, record_type, action_type, predicted, source)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'user')
     RETURNING id, created_at`,
    [
      userId,
      payload.text,
      payload.intent || null,
      payload.categoryCode || null,
      payload.recordType || null,
      payload.actionType || null,
      payload.predicted || null,
    ]
  );
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
  await query(
    `INSERT INTO action_rejected_log (user_id, text, predicted)
     VALUES ($1, $2, $3)`,
    [userId, payload.text || null, payload.predicted || null]
  );
}

async function aiChat(userId, sessionId, userMessage) {
  const chatService = require('../chat/chat.service');
  
  // Get recent messages for context
  const recentMessages = await chatService.getMessages(userId, sessionId, 20);
  const messages = recentMessages.map(m => ({
    role: m.role,
    content: m.content,
  }));
  messages.push({ role: 'user', content: userMessage });

  let emotion = null;
  if (userId) {
    try {
      const settingsRes = await query('SELECT verbal_style FROM user_settings WHERE user_id = $1', [userId]);
      const verbalStyle = settingsRes.rows[0]?.verbal_style || 'funny';
      emotion = mapVerbalStyleToEmotion(verbalStyle);
    } catch (_) {}
  }

  let walletId = null;
  try {
    const walletRes = await query(
      `SELECT wallet_id FROM wallet_members WHERE user_id = $1 LIMIT 1`,
      [userId]
    );
    if (walletRes.rows[0]) {
      walletId = walletRes.rows[0].wallet_id;
    }
  } catch (_) {}
  const profile = walletId ? await _fetchWalletProfile(userId, walletId) : null;

  try {
    const aiResponse = await aiClient.aiChat(messages, userId, { emotion, profile });
    const assistantContent =
      aiResponse.gemini_json?.story ||
      aiResponse.nlg_response ||
      aiResponse.response ||
      aiResponse.content ||
      'Xin lỗi, tôi không hiểu. Bạn có thể nói rõ hơn không?';

    // Parse and normalize the LLM/NLU emotion to PascalCase asset name
    const geminiJson = aiResponse.gemini_json;
    const llamaJson = aiResponse.llama_json;
    const intent = aiResponse.intent || 'Chitchat';
    const amount = aiResponse.amount ?? aiResponse.amount_spent;
    const category = aiResponse.category;
    const moodRaw = geminiJson?.emotion || llamaJson?.emotion || aiResponse.mascot_mood || aiResponse.emotion;
    const verbalToPascal = {
      'hai_huoc': 'Sassy',
      'dong_cam': 'Approved',
      'nghiem_tuc': 'Thinking',
      'cham_choc': 'Taunting',
      'dan_doi': 'Sad',
    };
    let moodStatus = verbalToPascal[moodRaw] || moodRaw || 'Chill';

    const intentAction = {
      mood: moodStatus,
      intent: intent,
      amount: amount,
      category: category,
      nlu: aiResponse,
    };

    // Save AI response to chat session
    await chatService.addMessage(userId, sessionId, {
      content: assistantContent,
      role: 'assistant',
      intentAction: intentAction,
    });

    await logAi(userId, 'chat', { sessionId, userMessage }, aiResponse, {
      backend: aiResponse.backend,
      latency_ms: aiResponse.latency_ms,
    });

    return {
      response: assistantContent,
      intentAction: intentAction,
    };
  } catch (err) {
    await logAi(userId, 'chat', { sessionId, userMessage }, null, { error: err.message });
    throw err;
  }
}

module.exports = {
  nluInfer,
  expenseFromText,
  expenseFromBill,
  saveCorrection,
  isActionConfirmed,
  confirmAction,
  rejectAction,
  aiChat,
};
