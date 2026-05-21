'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./categories.controller');
const { createCategorySchema, updateCategorySchema } = require('./categories.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Categories, description: Danh mục hệ thống + tự định nghĩa }]
 *
 * /api/v1/categories:
 *   get:
 *     tags: [Categories]
 *     summary: Liệt kê danh mục khả dụng cho user
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [expense, income, both] }
 *     responses:
 *       200: { description: OK }
 *   post:
 *     tags: [Categories]
 *     summary: Tạo category của user
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, code]
 *             properties:
 *               name: { type: string, example: Cà phê sáng }
 *               code: { type: string, example: morning_coffee }
 *               type: { type: string, enum: [expense, income, both], example: expense }
 *               icon: { type: string, example: coffee }
 *               color: { type: string, example: "#F59E0B" }
 *     responses:
 *       201: { description: Created }
 *
 * /api/v1/categories/{id}:
 *   patch:
 *     tags: [Categories]
 *     summary: Cập nhật category của chính user
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               icon: { type: string }
 *               color: { type: string }
 *     responses:
 *       200: { description: OK }
 *   delete:
 *     tags: [Categories]
 *     summary: Soft-delete category của user
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200: { description: OK }
 */

router.get('/', requireAuth, controller.list);
router.post(
  '/',
  requireAuth,
  validate({ body: createCategorySchema }),
  controller.create
);
router.patch(
  '/:id',
  requireAuth,
  validate({ body: updateCategorySchema }),
  controller.update
);
router.delete('/:id', requireAuth, controller.remove);

module.exports = router;
