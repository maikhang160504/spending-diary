'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./settings.service');

exports.get = asyncHandler(async (req, res) => {
  const data = await service.get(req.user.id);
  res.json({ success: true, data });
});

exports.update = asyncHandler(async (req, res) => {
  const data = await service.update(req.user.id, req.body);
  res.json({ success: true, data });
});
