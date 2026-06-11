'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./fcm.service');

exports.registerToken = asyncHandler(async (req, res) => {
  const { token, platform } = req.body;
  await service.upsertToken(req.user.id, token, platform);
  res.json({ success: true, data: { registered: true } });
});

exports.removeToken = asyncHandler(async (req, res) => {
  const { token } = req.body;
  await service.removeToken(req.user.id, token);
  res.json({ success: true, data: { removed: true } });
});
