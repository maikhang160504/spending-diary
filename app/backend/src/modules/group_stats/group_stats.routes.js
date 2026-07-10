'use strict';

const express = require('express');
const router = express.Router();
const groupStatsCtrl = require('./group_stats.controller');
const { requireAuth } = require('../../middlewares/auth');

router.use(requireAuth);

router.get('/:walletId/overview', groupStatsCtrl.getOverview);
router.get('/:walletId/categories', groupStatsCtrl.getCategories);
router.get('/:walletId/settlement', groupStatsCtrl.getSettlement);
router.get('/:walletId/timeline', groupStatsCtrl.getTimeline);

module.exports = router;
