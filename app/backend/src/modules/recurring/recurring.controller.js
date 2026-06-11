'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./recurring.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.list(req.user.id);
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
