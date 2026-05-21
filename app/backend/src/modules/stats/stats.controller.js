'use strict';

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./stats.service');

exports.dashboard = asyncHandler(async (req, res) => {
  const data = await service.dashboard(req.user.id, {
    from: req.query.from,
    to: req.query.to,
  });
  res.json({ success: true, data });
});

exports.byMonth = asyncHandler(async (req, res) => {
  const data = await service.byMonth(req.user.id, { year: req.query.year });
  res.json({ success: true, data });
});
