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

async function nluInfer(userId, payload) {
  const aiPayload = {
    text: payload.text,
    profile: payload.profile || null,
    run_llm: Boolean(payload.runLlm),
    emotion: payload.emotion || null,
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

async function expenseFromText(userId, payload) {
  const aiResponse = await aiClient.expenseFromText({
    text: payload.text,
    user_id: userId,
    profile: null,
    run_llm: false,
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
  return { ai: aiResponse, transaction: savedTx };
}

async function expenseFromBill(userId, fileBuffer, originalName, contentType) {
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
  return { ai: aiResponse, imageUrl, requiresConfirmation: true };
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

  try {
    const aiResponse = await aiClient.aiChat(messages, userId);
    const assistantContent = aiResponse.response || aiResponse.content || 'Xin lỗi, tôi không hiểu. Bạn có thể nói rõ hơn không?';

    // Save AI response to chat session
    await chatService.addMessage(userId, sessionId, {
      content: assistantContent,
      role: 'assistant',
      intentAction: aiResponse.intent_action || {},
    });

    await logAi(userId, 'chat', { sessionId, userMessage }, aiResponse, {
      backend: aiResponse.backend,
      latency_ms: aiResponse.latency_ms,
    });

    return {
      response: assistantContent,
      intentAction: aiResponse.intent_action || null,
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
