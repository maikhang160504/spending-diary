'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./stories.controller');
const { createStorySchema, updateStorySchema } = require('./stories.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Stories, description: Group transactions by story / day }]
 *
 * /api/v1/stories:
 *   get:
 *     tags: [Stories]
 *     summary: List stories
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: query, name: walletId, schema: { type: string, format: uuid } }
 *   post:
 *     tags: [Stories]
 *     summary: Create a new story
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [walletId]
 *             properties:
 *               walletId: { type: string, format: uuid }
 *               title: { type: string }
 *               occurredOn: { type: string, format: date }
 *               coverImageUrl: { type: string, format: uri }
 *
 * /api/v1/stories/{id}:
 *   get:
 *     tags: [Stories]
 *     summary: Get story detail with items + transactions
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   patch:
 *     tags: [Stories]
 *     summary: Update story
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 */

router.use(requireAuth);
router.get('/', controller.list);
router.post('/', validate({ body: createStorySchema }), controller.create);
router.get('/:id', controller.getById);
router.patch('/:id', validate({ body: updateStorySchema }), controller.update);

module.exports = router;
