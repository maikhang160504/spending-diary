'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./ai.service');
const aiClient = require('../../services/aiClient');
const ApiError = require('../../utils/ApiError');

exports.health = asyncHandler(async (_req, res) => {
  const data = await aiClient.health();
  res.json({ success: true, data });
});

exports.nlu = asyncHandler(async (req, res) => {
  const data = await service.nluInfer(req.user.id, req.body);
  res.json({ success: true, data });
});

exports.expenseFromText = asyncHandler(async (req, res) => {
  const data = await service.expenseFromText(req.user.id, req.body);
  res.json({ success: true, data });
});

exports.expenseFromTextAsync = asyncHandler(async (req, res) => {
  const data = await service.expenseFromTextAsync(req.user.id, req.body);
  res.status(202).json({ success: true, data });
});

exports.expenseFromBill = asyncHandler(async (req, res) => {
  if (!req.file) throw ApiError.badRequest('Field "file" is required.');
  const walletId = req.body?.walletId || req.query?.walletId || null;
  if (!walletId) throw ApiError.badRequest('walletId is required.');
  const data = await service.expenseFromBill(
    req.user.id,
    req.file.buffer,
    req.file.originalname,
    req.file.mimetype,
    walletId
  );
  res.status(202).json({ success: true, data });
});

exports.expenseGroupFromBill = asyncHandler(async (req, res) => {
  if (!req.file) throw ApiError.badRequest('Field "file" is required.');
  const groupId = req.body?.groupId || req.query?.groupId || null;
  const paidBy = req.body?.paidBy || req.query?.paidBy || null;
  if (!groupId) throw ApiError.badRequest('groupId is required.');
  const data = await service.expenseGroupFromBill(
    req.user.id,
    req.file.buffer,
    req.file.originalname,
    req.file.mimetype,
    groupId,
    paidBy
  );
  res.status(202).json({ success: true, data });
});

exports.saveCorrection = asyncHandler(async (req, res) => {
  const data = await service.saveCorrection(req.user.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.dislikeIntent = asyncHandler(async (req, res) => {
  const data = await service.dislikeIntent(req.user.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.confirmAction = asyncHandler(async (req, res) => {

  await service.confirmAction(req.user.id, req.body);
  res.json({ success: true });
});

exports.rejectAction = asyncHandler(async (req, res) => {
  await service.rejectAction(req.user.id, req.body);
  res.json({ success: true });
});

exports.actionConfirmed = asyncHandler(async (req, res) => {
  const signature = req.query.actionSignature;
  if (!signature) throw ApiError.badRequest('actionSignature query param required.');
  const confirmed = await service.isActionConfirmed(req.user.id, signature);
  res.json({ success: true, data: { confirmed } });
});

exports.executeAction = asyncHandler(async (req, res) => {
  const data = await service.executeAction(req.user.id, req.body);
  res.json({ success: true, data });
});

exports.aiChat = asyncHandler(async (req, res) => {
  const { sessionId } = req.params;
  const { content, contextMeta, walletId } = req.body;
  if (!content || !content.trim()) throw ApiError.badRequest('content is required.');
  const data = await service.aiChat(req.user.id, sessionId, content.trim(), contextMeta, walletId);
  res.json({ success: true, data });
});

const { simulateUserPush } = require('../fcm/notification.scheduler');

exports.simulateNotification = asyncHandler(async (req, res) => {
  const data = await simulateUserPush(req.user.id);
  res.json({ success: true, data });
});

const actionService = require('./action.service');

exports.goalRecap = asyncHandler(async (req, res) => {
  const data = await actionService.generateGoalRecapCommentary(req.body || {}, req.user || {});
  res.json({ success: true, data });
});

