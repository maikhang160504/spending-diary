'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./transactions.controller');
const {
  createTxSchema,
  updateTxSchema,
  listTxQuerySchema,
} = require('./transactions.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Transactions, description: CRUD giao dịch, lọc theo ví / category / thời gian }]
 *
 * /api/v1/transactions:
 *   get:
 *     tags: [Transactions]
 *     summary: Liệt kê giao dịch (lọc)
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: query, name: walletId, schema: { type: string, format: uuid } }
 *       - { in: query, name: categoryCode, schema: { type: string } }
 *       - { in: query, name: type, schema: { type: string, enum: [expense, income] } }
 *       - { in: query, name: from, schema: { type: string, format: date-time } }
 *       - { in: query, name: to, schema: { type: string, format: date-time } }
 *       - { in: query, name: page, schema: { type: integer, minimum: 1 } }
 *       - { in: query, name: pageSize, schema: { type: integer, minimum: 1, maximum: 100 } }
 *   post:
 *     tags: [Transactions]
 *     summary: Tạo giao dịch
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [walletId, amount]
 *             properties:
 *               walletId: { type: string, format: uuid }
 *               amount: { type: number, example: 45000 }
 *               type: { type: string, enum: [expense, income], example: expense }
 *               categoryCode: { type: string, example: Food }
 *               note: { type: string, example: Ăn phở sáng }
 *               occurredAt: { type: string, format: date-time }
 *               source: { type: string, enum: [manual, text, story, bill], example: manual }
 *               imageUrl: { type: string }
 *               thumbnailUrl: { type: string }
 *
 * /api/v1/transactions/{id}:
 *   get:
 *     tags: [Transactions]
 *     summary: Chi tiết giao dịch
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   patch:
 *     tags: [Transactions]
 *     summary: Cập nhật giao dịch
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   delete:
 *     tags: [Transactions]
 *     summary: Xoá giao dịch (soft delete)
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 */

router.use(requireAuth);
router.get('/', validate({ query: listTxQuerySchema }), controller.list);
router.post('/', validate({ body: createTxSchema }), controller.create);
router.get('/export', controller.exportCsv);
router.get('/:id', controller.get);
router.patch('/:id', validate({ body: updateTxSchema }), controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
