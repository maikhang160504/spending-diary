'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./wallets.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.list(req.user.id);
  res.json({ success: true, data });
});

exports.get = asyncHandler(async (req, res) => {
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

exports.archive = asyncHandler(async (req, res) => {
  await service.archive(req.user.id, req.params.id);
  res.json({ success: true });
});

exports.listMembers = asyncHandler(async (req, res) => {
  const data = await service.listMembers(req.user.id, req.params.id);
  res.json({ success: true, data });
});

exports.addMember = asyncHandler(async (req, res) => {
  const data = await service.addMember(req.user.id, req.params.id, req.body);
  res.json({ success: true, data });
});

exports.removeMember = asyncHandler(async (req, res) => {
  await service.removeMember(req.user.id, req.params.id, req.params.memberId);
  res.json({ success: true });
});
