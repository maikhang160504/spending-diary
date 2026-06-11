'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./recurring.controller');
const { createRecurringRuleSchema, updateRecurringRuleSchema } = require('./recurring.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Recurring, description: Quy tắc giao dịch định kỳ }]
 *
 * /api/v1/recurring:
 *   get:
 *     tags: [Recurring]
 *     summary: Danh sách quy tắc định kỳ của user
 *     security: [ { bearerAuth: [] } ]
 *   post:
 *     tags: [Recurring]
 *     summary: Tạo quy tắc định kỳ
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [walletId, amount, frequency, nextOccurrence]
 *             properties:
 *               walletId: { type: string, format: uuid }
 *               amount: { type: number, example: 500000 }
 *               type: { type: string, enum: [expense, income], example: expense }
 *               categoryCode: { type: string, example: Food }
 *               note: { type: string, example: Tiền điện mạng }
 *               frequency: { type: string, enum: [daily, weekly, monthly], example: monthly }
 *               nextOccurrence: { type: string, format: date, example: "2026-06-15" }
 *               isActive: { type: boolean, example: true }
 *
 * /api/v1/recurring/{id}:
 *   patch:
 *     tags: [Recurring]
 *     summary: Cập nhật quy tắc định kỳ
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   delete:
 *     tags: [Recurring]
 *     summary: Xoá quy tắc định kỳ
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 */

router.use(requireAuth);
router.get('/', controller.list);
router.post('/', validate({ body: createRecurringRuleSchema }), controller.create);
router.patch('/:id', validate({ body: updateRecurringRuleSchema }), controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
