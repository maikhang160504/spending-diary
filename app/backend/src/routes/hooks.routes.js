'use strict';

const express = require('express');
const crypto = require('crypto');
const env = require('../config/env');
const logger = require('../config/logger');

const router = express.Router();

/**
 * @openapi
 * /hooks/sepay-payments:
 *   post:
 *     tags: [Hooks]
 *     summary: Webhook endpoint for SePay payment notifications
 *     responses:
 *       200:
 *         description: Webhook received successfully
 */
router.post('/sepay-payments', (req, res) => {
  const secret = env.sepayWebhookSecret;
  const signature = req.headers['x-sepay-signature'];

  // Print raw headers and body for troubleshooting
  logger.info({ headers: req.headers }, 'Received webhook headers from SePay');
  
  let payload;
  try {
    payload = req.body;
    logger.info({ payload }, 'Received webhook body from SePay');
  } catch (err) {
    logger.error({ err: err.message }, 'Failed to parse SePay webhook body');
    return res.status(400).json({ success: false, error: 'Invalid JSON body' });
  }

  // Verify HMAC-SHA256 signature if secret is configured
  if (secret) {
    const timestamp = req.headers['x-sepay-timestamp'];

    if (!signature) {
      logger.warn('SePay webhook secret is configured, but X-SePay-Signature header is missing.');
      return res.status(401).json({ success: false, error: 'Missing signature' });
    }

    if (!timestamp) {
      logger.warn('X-SePay-Timestamp header is missing.');
      return res.status(401).json({ success: false, error: 'Missing timestamp' });
    }

    if (!req.rawBody) {
      logger.error('rawBody is missing from request. Cannot verify HMAC signature.');
      return res.status(500).json({ success: false, error: 'Server misconfiguration' });
    }

    try {
      let actualSignature = signature;
      if (signature.startsWith('sha256=')) {
        actualSignature = signature.substring(7);
      }

      // SePay signature formula: HMAC-SHA256(secret, timestamp + '.' + rawBody)
      const dataToSign = Buffer.concat([
        Buffer.from(timestamp + '.', 'utf8'),
        req.rawBody
      ]);

      const computedSignature = crypto
        .createHmac('sha256', secret)
        .update(dataToSign)
        .digest('hex');

      const bufComputed = Buffer.from(computedSignature, 'utf8');
      const bufActual = Buffer.from(actualSignature, 'utf8');

      if (bufComputed.length !== bufActual.length) {
        logger.warn({ signature, computedSignature }, 'SePay webhook signature length mismatch.');
        return res.status(401).json({ success: false, error: 'Invalid signature' });
      }

      // Compare signatures securely using timingSafeEqual to prevent timing attacks
      const isSignatureValid = crypto.timingSafeEqual(bufComputed, bufActual);

      if (!isSignatureValid) {
        logger.warn({ signature, computedSignature }, 'SePay webhook signature verification failed.');
        return res.status(401).json({ success: false, error: 'Invalid signature' });
      }

      logger.info('SePay webhook signature verification successful.');
    } catch (cryptoErr) {
      logger.error({ cryptoErr: cryptoErr.message }, 'Error comparing HMAC signatures.');
      return res.status(401).json({ success: false, error: 'Invalid signature' });
    }
  } else {
    logger.warn('SePay webhook secret is not configured. Skipping signature verification.');
  }

  // Respond 200 ngay để SePay không retry, xử lý fulfillment async
  res.status(200).json({ success: true });

  // ── Async fulfillment ───────────────────────────────────────────────────────
  setImmediate(async () => {
    try {
      const transferAmount  = Number(payload.transferAmount  || payload.transfer_amount  || 0);
      const transferContent = String(payload.content         || payload.transferContent  || payload.description || '');

      if (!transferContent) {
        logger.warn({ payload }, '[Webhook] Missing transfer content — cannot match order');
        return;
      }

      const paymentsService = require('../modules/payments/payments.service');
      const result = await paymentsService.fulfillOrder(transferContent, transferAmount);

      if (result.success && !result.alreadyCompleted && result.userId) {
        logger.info({ userId: result.userId, code: result.code }, '[Webhook] Premium activated for user');

        // Push FCM notification (non-critical)
        try {
          const fcmModule = require('../modules/fcm/fcm.service');
          if (fcmModule && typeof fcmModule.sendToUser === 'function') {
            await fcmModule.sendToUser(result.userId, {
              title: '🎉 Nâng cấp thành công!',
              body:  'Tài khoản SpendDiary đã được nâng cấp Premium vĩnh viễn. Không còn quảng cáo!',
              data:  { type: 'PREMIUM_ACTIVATED' },
            });
          }
        } catch (fcmErr) {
          logger.warn({ err: fcmErr.message }, '[Webhook] FCM push failed (non-critical)');
        }
      }
    } catch (fulfillErr) {
      logger.error({ err: fulfillErr.message }, '[Webhook] Fulfillment error after 200 response');
    }
  });
});

module.exports = router;