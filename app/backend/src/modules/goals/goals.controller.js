'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./goals.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.list(req.user.id);
  res.json({ success: true, data });
});

exports.getById = asyncHandler(async (req, res) => {
  const data = await service.getById(req.user.id, req.params.id);
  res.json({ success: true, data });
});

exports.create = asyncHandler(async (req, res) => {
  const data = await service.create(req.user.id, req.body);
  res.status(201).json({ success: true, data });
});

exports.update = asyncHandler(async (req, res) => {
  const data = await service.update(req.user.id, req.params.id, req.body);
  res.json({ success: true, data });
});

exports.remove = asyncHandler(async (req, res) => {
  await service.remove(req.user.id, req.params.id);
  res.json({ success: true });
});

exports.contribute = asyncHandler(async (req, res) => {
  const data = await service.contribute(req.user.id, req.params.id, req.body.amount);
  res.json({ success: true, data });
});

exports.generateInviteCode = asyncHandler(async (req, res) => {
  const data = await service.generateInviteCode(req.user.id, req.params.id);
  res.json({ success: true, data });
});

exports.joinByInviteCode = asyncHandler(async (req, res) => {
  const data = await service.joinByInviteCode(req.user.id, req.body.inviteCode);
  res.json({ success: true, data });
});

