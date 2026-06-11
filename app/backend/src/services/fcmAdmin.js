'use strict';

const logger = require('../config/logger');

let _admin = null;
let _initAttempted = false;

function _loadAdmin() {
  if (_initAttempted) return _admin;
  _initAttempted = true;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKeyRaw) {
    logger.warn('FCM disabled: set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY');
    return null;
  }

  try {
    // eslint-disable-next-line global-require
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey: privateKeyRaw.replace(/\\n/g, '\n'),
        }),
      });
    }
    _admin = admin;
    logger.info('Firebase Admin initialized for FCM');
  } catch (err) {
    logger.error({ err: err.message }, 'Firebase Admin init failed');
    _admin = null;
  }

  return _admin;
}

function isEnabled() {
  return Boolean(_loadAdmin());
}

/**
 * @param {string[]} tokens
 * @param {{ title: string, body: string, data?: Record<string, string> }} payload
 */
async function sendMulticast(tokens, { title, body, data = {} }) {
  const admin = _loadAdmin();
  if (!admin || !tokens.length) {
    return { sent: 0, failed: tokens.length, invalidTokens: [] };
  }

  const stringData = Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value ?? '')])
  );

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: stringData,
    android: {
      priority: 'high',
      notification: {
        channelId: 'budget_alerts_channel',
        icon: 'launcher_icon',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  });

  const invalidTokens = [];
  response.responses.forEach((res, idx) => {
    if (res.success) return;
    const code = res.error?.code || '';
    if (
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/registration-token-not-registered'
    ) {
      invalidTokens.push(tokens[idx]);
    }
  });

  return {
    sent: response.successCount,
    failed: response.failureCount,
    invalidTokens,
  };
}

module.exports = { isEnabled, sendMulticast };
