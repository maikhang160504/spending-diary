'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./chat.service');

exports.listSessions = asyncHandler(async (req, res) => {
  const data = await service.listSessions(req.user.id);
  res.json({ success: true, data });
});

exports.createSession = asyncHandler(async (req, res) => {
  const data = await service.createSession(req.user.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.getMessages = asyncHandler(async (req, res) => {
  const data = await service.getMessages(req.user.id, req.params.id);
  res.json({ success: true, data });
});

exports.addMessage = asyncHandler(async (req, res) => {
  const data = await service.addMessage(req.user.id, req.params.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.archiveSession = asyncHandler(async (req, res) => {
  await service.archiveSession(req.user.id, req.params.id);
  res.json({ success: true });
});
