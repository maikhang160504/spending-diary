'use strict';

const express = require('express');
const multer = require('multer');

const { requireAuth } = require('../../middlewares/auth');
const controller = require('./upload.controller');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Upload, description: Cloudflare R2 storage }]
 *
 * /api/v1/upload/presign:
 *   post:
 *     tags: [Upload]
 *     summary: Lấy presigned URL (PUT trực tiếp lên R2)
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [filename]
 *             properties:
 *               filename: { type: string, example: receipt.jpg }
 *               contentType: { type: string, example: image/jpeg }
 *
 * /api/v1/upload/direct:
 *   post:
 *     tags: [Upload]
 *     summary: Upload trực tiếp qua backend (proxy lên R2)
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [file]
 *             properties:
 *               file: { type: string, format: binary }
 */

router.use(requireAuth);
router.post('/presign', controller.presign);
router.post('/direct', upload.single('file'), controller.directUpload);

module.exports = router;
