'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./transactions.service');

exports.list = asyncHandler(async (req, res) => {
  const data = await service.listForUser(req.user.id, req.valid?.query || {});
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

exports.remove = asyncHandler(async (req, res) => {
  await service.softDelete(req.user.id, req.params.id);
  res.json({ success: true });
});
