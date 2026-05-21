'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./settings.controller');
const { updateSettingsSchema } = require('./settings.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Settings, description: User settings (theme, notifications, personality) }]
 *
 * /api/v1/users/me/settings:
 *   get:
 *     tags: [Settings]
 *     summary: Get current user settings
 *     security: [ { bearerAuth: [] } ]
 *     responses:
 *       200:
 *         description: Settings object
 *   patch:
 *     tags: [Settings]
 *     summary: Update user settings
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               verbalStyle: { type: string, enum: [funny, gentle, serious, sarcastic] }
 *               themeMode: { type: boolean }
 *               personality: { type: string }
 *               notificationsEnabled: { type: boolean }
 *               locale: { type: string }
 */

router.use(requireAuth);
router.get('/', controller.get);
router.patch('/', validate({ body: updateSettingsSchema }), controller.update);

module.exports = router;
