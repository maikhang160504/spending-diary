'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./stats.service');
const peerCompareService = require('./peer_compare.service');

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
    type: req.query.type,
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
    timeRange: req.query.timeRange,
    periodOffset: req.query.periodOffset ? parseInt(req.query.periodOffset, 10) : 0,
  });
  res.json({ success: true, data });
});

exports.peerCompare = asyncHandler(async (req, res) => {
  const data = await peerCompareService.getPeerCompare(req.user.id, {
    month: req.query.month,
  });
  res.json({ success: true, data });
});
