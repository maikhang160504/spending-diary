'use strict';

const { query } = require('../config/db');
const logger = require('../config/logger');

// Store requests: { "userId_timestamp": count }
const requestCounts = new Map();
const WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS = 60; // Max 60 requests per minute

/**
 * Bans a user immediately and logs it out.
 */
async function banUser(userId, reason) {
  try {
    const userResult = await query('UPDATE users SET status = $1, ban_reason = $2 WHERE id = $3 RETURNING email', ['banned', reason, userId]);
    logger.warn(`User ${userId} was auto-banned. Reason: ${reason}`);
    
    if (userResult.rows.length > 0 && userResult.rows[0].email) {
      const { sendBanNotification } = require('../utils/mailer');
      await sendBanNotification(userResult.rows[0].email, reason);
    }
  } catch (err) {
    logger.error(`Error auto-banning user ${userId}:`, err);
  }
}

/**
 * Middleware to detect spam and abuse (Rate Limiting).
 * If a user sends >60 requests per minute, ban them for 'Spam hoặc lạm dụng hệ thống'.
 */
async function autoBanSpam(req, res, next) {
  if (!req.user || !req.user.id) {
    return next();
  }

  const userId = req.user.id;
  const now = Date.now();
  const windowStart = Math.floor(now / WINDOW_MS) * WINDOW_MS;
  const key = `${userId}_${windowStart}`;

  // Clean up old entries to prevent memory leak
  if (Math.random() < 0.05) { // 5% chance on each request to cleanup
    for (const [k, v] of requestCounts.entries()) {
      const [kUserId, kWindowStart] = k.split('_');
      if (now - parseInt(kWindowStart, 10) > WINDOW_MS * 2) {
        requestCounts.delete(k);
      }
    }
  }

  const currentCount = requestCounts.get(key) || 0;
  
  if (currentCount > MAX_REQUESTS) {
    // Ban the user
    await banUser(userId, 'Spam hoặc lạm dụng hệ thống');
    return res.status(403).json({ success: false, message: 'Your account has been banned due to spam or system abuse.' });
  }

  requestCounts.set(key, currentCount + 1);
  next();
}

/**
 * Middleware to detect community guideline violations in Chat/NLU texts.
 */
async function autoBanCommunity(req, res, next) {
  if (!req.user || !req.user.id) {
    return next();
  }

  const text = (req.body.text || req.body.query || req.body.message || '').toLowerCase();
  
  if (!text) {
    return next();
  }

  // Simple profanity list for demo
  const badWords = [
    'đụ má', 'địt mẹ', 'cặc', 'lồn', 'phản động', 'đĩ', 'chết cụ'
  ];

  for (const word of badWords) {
    if (text.includes(word)) {
      await banUser(req.user.id, 'Vi phạm tiêu chuẩn cộng đồng');
      return res.status(403).json({ success: false, message: 'Your account has been banned due to community guidelines violation.' });
    }
  }

  next();
}

module.exports = {
  banUser,
  autoBanSpam,
  autoBanCommunity
};
