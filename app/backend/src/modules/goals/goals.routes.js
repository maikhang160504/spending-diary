'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./goals.controller');
const { createGoalSchema, updateGoalSchema, contributeSchema } = require('./goals.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Goals, description: Saving goals }]
 *
 * /api/v1/goals:
 *   get:
 *     tags: [Goals]
 *     summary: List all goals
 *     security: [ { bearerAuth: [] } ]
 *   post:
 *     tags: [Goals]
 *     summary: Create a new goal
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, targetAmount]
 *             properties:
 *               name: { type: string, example: 'Mua iPhone' }
 *               targetAmount: { type: number, example: 25000000 }
 *               emoji: { type: string, example: '📱' }
 *               deadline: { type: string, format: date }
 *               walletId: { type: string, format: uuid }
 *
 * /api/v1/goals/{id}:
 *   get:
 *     tags: [Goals]
 *     summary: Get goal by ID
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   patch:
 *     tags: [Goals]
 *     summary: Update a goal
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   delete:
 *     tags: [Goals]
 *     summary: Cancel a goal
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *
 * /api/v1/goals/{id}/contribute:
 *   post:
 *     tags: [Goals]
 *     summary: Contribute money to a goal
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [amount]
 *             properties:
 *               amount: { type: number, example: 500000 }
 */

router.use(requireAuth);
router.get('/', controller.list);
router.post('/', validate({ body: createGoalSchema }), controller.create);
router.post('/join', controller.joinByInviteCode);
router.post('/trigger-reminders', controller.triggerReminders);
router.get('/:id', controller.getById);
router.patch('/:id', validate({ body: updateGoalSchema }), controller.update);
router.delete('/:id', controller.remove);
router.post('/:id/leave', controller.leaveGoal);
router.post('/:id/contribute', validate({ body: contributeSchema }), controller.contribute);
router.post('/:id/invite', controller.generateInviteCode);

module.exports = router;
