'use strict';

const express = require('express');

const authRoutes = require('../modules/auth/auth.routes');
const categoriesRoutes = require('../modules/categories/categories.routes');
const walletsRoutes = require('../modules/wallets/wallets.routes');
const transactionsRoutes = require('../modules/transactions/transactions.routes');
const budgetsRoutes = require('../modules/budgets/budgets.routes');
const statsRoutes = require('../modules/stats/stats.routes');
const aiRoutes = require('../modules/ai/ai.routes');
const uploadRoutes = require('../modules/upload/upload.routes');
const settingsRoutes = require('../modules/settings/settings.routes');
const goalsRoutes = require('../modules/goals/goals.routes');
const storiesRoutes = require('../modules/stories/stories.routes');
const chatRoutes = require('../modules/chat/chat.routes');
const recurringRoutes = require('../modules/recurring/recurring.routes');
const fcmRoutes = require('../modules/fcm/fcm.routes');
const loansRoutes = require('../modules/loans/loans.route');
const groupStatsRoutes = require('../modules/group_stats/group_stats.routes');
const authController = require('../modules/auth/auth.controller');
const { requireAuth } = require('../middlewares/auth');

const router = express.Router();

/**
 * @openapi
 * /health:
 *   get:
 *     tags: [Meta]
 *     summary: Liveness probe (không cần auth)
 *     responses:
 *       200:
 *         description: OK
 */
router.get('/health', (_req, res) => {
  res.json({ success: true, status: 'ok', uptime: process.uptime() });
});

router.use('/auth', authRoutes);
router.use('/categories', categoriesRoutes);
router.use('/wallets', walletsRoutes);
router.use('/transactions', transactionsRoutes);
router.use('/budgets', budgetsRoutes);
router.use('/stats', statsRoutes);
router.use('/ai', aiRoutes);
router.use('/upload', uploadRoutes);
router.use('/users/me/settings', settingsRoutes);
router.use('/users/me/streak', requireAuth, authController.getStreak);
router.use('/goals', goalsRoutes);
router.use('/stories', storiesRoutes);
router.use('/chat', chatRoutes);
router.use('/recurring', recurringRoutes);
router.use('/users/me/fcm', fcmRoutes);
router.use('/loans', loansRoutes);
router.use('/group-stats', groupStatsRoutes);

module.exports = router;
