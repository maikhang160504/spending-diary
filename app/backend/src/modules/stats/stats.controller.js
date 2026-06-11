'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./stats.service');

exports.dashboard = asyncHandler(async (req, res) => {
  const data = await service.dashboard(req.user.id, {
    from: req.query.from,
    to: req.query.to,
    walletId: req.query.walletId,
  });
  res.json({ success: true, data });
});

exports.byMonth = asyncHandler(async (req, res) => {
  const data = await service.byMonth(req.user.id, {
    year: req.query.year,
    walletId: req.query.walletId,
  });
  res.json({ success: true, data });
});

exports.byCategory = asyncHandler(async (req, res) => {
  const data = await service.byCategory(req.user.id, {
    from: req.query.from,
    to: req.query.to,
    range: req.query.range,
    walletId: req.query.walletId,
  });
  res.json({ success: true, data });
});

exports.mom = asyncHandler(async (req, res) => {
  const data = await service.getMoMComparison(req.user.id, {
    walletId: req.query.walletId,
  });
  res.json({ success: true, data });
});

exports.cumulativeVsBudget = asyncHandler(async (req, res) => {
  const data = await service.getCumulativeVsBudget(req.user.id, {
    walletId: req.query.walletId,
  });
  res.json({ success: true, data });
});
