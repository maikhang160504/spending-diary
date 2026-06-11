'use strict';

const { sendToUser } = require('./wsHub');
const fcmService = require('../modules/fcm/fcm.service');
const settingsService = require('../modules/settings/settings.service');

/**
 * Send in-app (WebSocket) + system push (FCM) for the same alert payload.
 * Respects user_settings.notifications_enabled.
 */
async function dispatchUserNotification(userId, { type, payload }) {
  sendToUser(userId, { type, payload });

  try {
    const settings = await settingsService.get(userId);
    if (settings && settings.notifications_enabled === false) {
      return;
    }
  } catch (_) {
    // continue — default to sending push
  }

  await fcmService.sendPushToUser(userId, {
    title: payload.title || 'SpendDiary',
    body: payload.message || '',
    data: {
      type: type || 'GENERAL',
      deepLink: payload.deepLink || '/',
      categoryCode: payload.categoryCode || '',
    },
  });
}

module.exports = { dispatchUserNotification };
