'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./budgets.controller');
const { createBudgetSchema, updateBudgetSchema } = require('./budgets.schema');
const asyncHandler = require('../../utils/asyncHandler');
const { runMonthlyReset, runLastWeekReminder, snapshotAndResetForUser } = require('../../cron/budgetReset.cron');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Budgets, description: Hạn mức chi tiêu theo category / period }]
 *
 * /api/v1/budgets:
 *   get:
 *     tags: [Budgets]
 *     summary: Danh sách budget
 *     security: [ { bearerAuth: [] } ]
 *   post:
 *     tags: [Budgets]
 *     summary: Tạo budget
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [amountLimit, startDate]
 *             properties:
 *               amountLimit: { type: number, example: 3000000 }
 *               period: { type: string, enum: [week, month, year], example: month }
 *               categoryCode: { type: string, example: Food }
 *               walletId: { type: string, format: uuid }
 *               startDate: { type: string, format: date }
 *               endDate: { type: string, format: date }
 *
 * /api/v1/budgets/summary:
 *   get:
 *     tags: [Budgets]
 *     summary: Tổng kết spent / remain / usagePct của các budget đang chạy
 *     security: [ { bearerAuth: [] } ]
 *
 * /api/v1/budgets/{id}:
 *   patch:
 *     tags: [Budgets]
 *     summary: Cập nhật budget
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   delete:
 *     tags: [Budgets]
 *     summary: Vô hiệu hoá budget
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 */

router.use(requireAuth);
router.get('/summary', controller.summary);
router.get('/suggestions', controller.getSuggestions);
router.post('/suggestions/apply', controller.applySuggestions);
router.post('/suggestions/dismiss', controller.dismissSuggestions);
router.get('/', controller.list);
router.post('/', validate({ body: createBudgetSchema }), controller.create);
router.patch('/:id', validate({ body: updateBudgetSchema }), controller.update);
router.delete('/:id', controller.remove);

// ── Lịch sử snapshot hàng tháng ──────────────────────────────────────────
router.get('/snapshots', asyncHandler(async (req, res) => {
  const { query } = require('../../config/db');
  const r = await query(
    `SELECT * FROM budget_monthly_snapshots
     WHERE user_id = $1
     ORDER BY month DESC, category_code ASC
     LIMIT 72`,
    [req.user.id]
  );
  res.json({
    success: true,
    data: r.rows.map(row => ({
      id: row.id,
      categoryCode: row.category_code,
      month: row.month,
      amountLimit: Number(row.amount_limit),
      spent: Number(row.spent),
      usagePct: Number(row.amount_limit) > 0
        ? Math.round((Number(row.spent) / Number(row.amount_limit)) * 1000) / 10
        : null,
      source: row.source,
      createdAt: row.created_at,
    }))
  });
}));

// ── Debug: chạy reset thủ công (dành cho test) ────────────────────────────
router.post('/debug/run-reset', asyncHandler(async (req, res) => {
  // Chỉ cho phép nếu có header x-debug-key khớp với env.DEBUG_KEY (nếu đặt)
  const { NODE_ENV } = process.env;
  const result = await snapshotAndResetForUser(req.user.id);
  res.json({ success: true, data: result });
}));

router.post('/debug/send-reminder', asyncHandler(async (req, res) => {
  const result = await runLastWeekReminder();
  res.json({ success: true, data: result });
}));

module.exports = router;

