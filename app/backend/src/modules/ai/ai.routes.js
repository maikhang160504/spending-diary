'use strict';

const express = require('express');
const multer = require('multer');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./ai.controller');
const {
  nluSchema,
  expenseFromTextSchema,
  correctionSchema,
  confirmActionSchema,
  executeActionSchema,
} = require('./ai.schema');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: AI, description: NLU / OCR / Correction (proxy đến AI service) }]
 *
 * /api/v1/ai/health:
 *   get:
 *     tags: [AI]
 *     summary: Trạng thái AI service (proxy /health)
 *     security: [ { bearerAuth: [] } ]
 *
 * /api/v1/ai/nlu:
 *   post:
 *     tags: [AI]
 *     summary: Phân tích câu chi tiêu (intent + amount + category)
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [text]
 *             properties:
 *               text: { type: string, example: "ăn phở 45k" }
 *               profile: { type: object }
 *               runLlm: { type: boolean }
 *
 * /api/v1/ai/expense/from-text:
 *   post:
 *     tags: [AI]
 *     summary: Parse text → tạo giao dịch (auto-save nếu không cần chọn category)
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [walletId, text]
 *             properties:
 *               walletId: { type: string, format: uuid }
 *               text: { type: string, example: "trà sữa 35k" }
 *               occurredAt: { type: string, format: date-time }
 *               autoSave: { type: boolean, default: true }
 *
 * /api/v1/ai/expense/from-bill:
 *   post:
 *     tags: [AI]
 *     summary: "Upload bill ảnh → tạo giao dịch PENDING ngay (HTTP 202); OCR+LLM chạy ngầm; kết quả trả qua WebSocket /ws"
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [file, walletId]
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               walletId:
 *                 type: string
 *                 format: uuid
 *                 description: Ví sẽ ghi giao dịch vào
 *     responses:
 *       202:
 *         description: Giao dịch PENDING đã được tạo; lắng nghe WebSocket để nhận kết quả
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   properties:
 *                     transactionId: { type: string, format: uuid }
 *                     status: { type: string, enum: [pending] }
 *                     imageUrl: { type: string, nullable: true }
 *
 * /api/v1/ai/corrections:
 *   post:
 *     tags: [AI]
 *     summary: Lưu correction (user gán lại nhãn) cho phase training/model_custom
 *     security: [ { bearerAuth: [] } ]
 *
 * /api/v1/ai/actions/confirm:
 *   post:
 *     tags: [AI]
 *     summary: Đánh dấu một action đã được user confirm (không hỏi lại)
 *     security: [ { bearerAuth: [] } ]
 *
 * /api/v1/ai/actions/reject:
 *   post:
 *     tags: [AI]
 *     summary: Log action bị reject (cho admin queue review)
 *     security: [ { bearerAuth: [] } ]
 *
 * /api/v1/ai/actions/is-confirmed:
 *   get:
 *     tags: [AI]
 *     summary: Tra cứu nhanh `confirmed?` trước khi hiện popup
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: query, name: actionSignature, required: true, schema: { type: string } }
 */

router.use(requireAuth);
router.get('/health', controller.health);
router.post('/nlu', validate({ body: nluSchema }), controller.nlu);
router.post(
  '/expense/from-text',
  validate({ body: expenseFromTextSchema }),
  controller.expenseFromText
);
router.post(
  '/expense/from-text-async',
  validate({ body: expenseFromTextSchema }),
  controller.expenseFromTextAsync
);
router.post('/expense/from-bill', upload.single('file'), controller.expenseFromBill);

router.post('/corrections', validate({ body: correctionSchema }), controller.saveCorrection);
router.post(
  '/actions/confirm',
  validate({ body: confirmActionSchema }),
  controller.confirmAction
);
router.post('/actions/reject', controller.rejectAction);
router.get('/actions/is-confirmed', controller.actionConfirmed);
router.post(
  '/actions/execute',
  validate({ body: executeActionSchema }),
  controller.executeAction
);
router.post('/chat/:sessionId', controller.aiChat);
router.post('/notifications/simulate', controller.simulateNotification);
router.post('/goal-recap', controller.goalRecap);

module.exports = router;
