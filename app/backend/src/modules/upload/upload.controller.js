'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const r2Client = require('../../services/r2Client');
const ApiError = require('../../utils/ApiError');

exports.presign = asyncHandler(async (req, res) => {
  const { filename, contentType } = req.body || {};
  if (!filename) throw ApiError.badRequest('filename is required.');
  const data = await r2Client.presignUpload(req.user.id, { filename, contentType });
  res.json({ success: true, data });
});

exports.directUpload = asyncHandler(async (req, res) => {
  if (!req.file) throw ApiError.badRequest('Field "file" is required.');
  if (!r2Client.isConfigured()) throw ApiError.upstream('Cloudflare R2 not configured.');
  const data = await r2Client.uploadBuffer(req.user.id, req.file.buffer, {
    filename: req.file.originalname,
    contentType: req.file.mimetype,
  });
  res.json({ success: true, data });
});
