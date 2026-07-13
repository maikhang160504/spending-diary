'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const controller = require('./stats.controller');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Stats, description: Dashboard & thống kê chi tiêu }]
 *
 * /api/v1/stats/dashboard:
 *   get:
 *     tags: [Stats]
 *     summary: Tổng quan (tổng chi, tổng thu, theo category, theo ngày)
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: query, name: from, schema: { type: string, format: date-time } }
 *       - { in: query, name: to,   schema: { type: string, format: date-time } }
 *
 * /api/v1/stats/by-month:
 *   get:
 *     tags: [Stats]
 *     summary: Thu / chi theo tháng trong năm
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: query, name: year, schema: { type: integer, example: 2026 } }
 */

router.use(requireAuth);
router.get('/dashboard', controller.dashboard);
router.get('/by-month', controller.byMonth);
router.get('/by-category', controller.byCategory);
router.get('/mom', controller.mom);
router.get('/cumulative-vs-budget', controller.cumulativeVsBudget);
router.get('/peer-compare', controller.peerCompare);

module.exports = router;
