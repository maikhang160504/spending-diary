'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./stories.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.list(req.user.id, req.query.walletId);
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
