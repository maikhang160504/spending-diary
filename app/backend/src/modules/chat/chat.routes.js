'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./chat.controller');
const { createSessionSchema, createMessageSchema } = require('./chat.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Chat, description: Chat sessions with Mascot AI }]
 *
 * /api/v1/chat/sessions:
 *   get:
 *     tags: [Chat]
 *     summary: List chat sessions
 *     security: [ { bearerAuth: [] } ]
 *   post:
 *     tags: [Chat]
 *     summary: Create new chat session
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title: { type: string }
 *
 * /api/v1/chat/sessions/{id}/messages:
 *   get:
 *     tags: [Chat]
 *     summary: Get messages in a session
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   post:
 *     tags: [Chat]
 *     summary: Add a message to a session
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [content]
 *             properties:
 *               content: { type: string }
 *               role: { type: string, enum: [user, assistant, system] }
 *
 * /api/v1/chat/sessions/{id}/archive:
 *   post:
 *     tags: [Chat]
 *     summary: Archive a session
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 */

router.use(requireAuth);
router.get('/sessions', controller.listSessions);
router.post('/sessions', validate({ body: createSessionSchema }), controller.createSession);
router.get('/sessions/:id/messages', controller.getMessages);
router.post('/sessions/:id/messages', validate({ body: createMessageSchema }), controller.addMessage);
router.post('/sessions/:id/archive', controller.archiveSession);
router.delete('/sessions/:id', controller.deleteSession);

module.exports = router;
