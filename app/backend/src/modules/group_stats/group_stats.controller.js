'use strict';

const groupStatsService = require('./group_stats.service');

async function getOverview(req, res, next) {
  try {
    const { walletId } = req.params;
    const userId = req.user.id;
    const data = await groupStatsService.overview(walletId, userId);
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

async function getCategories(req, res, next) {
  try {
    const { walletId } = req.params;
    const userId = req.user.id;
    const data = await groupStatsService.categories(walletId, userId);
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

async function getSettlement(req, res, next) {
  try {
    const { walletId } = req.params;
    const userId = req.user.id;
    const data = await groupStatsService.settlement(walletId, userId);
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

async function getTimeline(req, res, next) {
  try {
    const { walletId } = req.params;
    const userId = req.user.id;
    const data = await groupStatsService.timeline(walletId, userId);
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getOverview,
  getCategories,
  getSettlement,
  getTimeline
};
