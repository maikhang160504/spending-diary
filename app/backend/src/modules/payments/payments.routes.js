'use strict';

const express = require('express');
const { requireAuth } = require('../../middlewares/auth');
const paymentsService = require('./payments.service');
const logger = require('../../config/logger');

const router = express.Router();

/**
 * @openapi
 * /payments/create:
 *   post:
 *     tags: [Payments]
 *     summary: Tạo đơn hàng Premium mới + trả về URL VietQR
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200:
 *         description: Đơn hàng tạo thành công
 */
router.post('/create', requireAuth, async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Kiểm tra user đã premium rồi chưa
    const { isPremium } = await paymentsService.getUserPremiumStatus(userId);
    if (isPremium) {
      return res.status(409).json({
        success: false,
        error: { message: 'Tài khoản của bạn đã là Premium!', code: 'ALREADY_PREMIUM' },
      });
    }

    const order = await paymentsService.createOrder(userId);

    return res.json({
      success: true,
      data: order,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /payments/status:
 *   get:
 *     tags: [Payments]
 *     summary: Kiểm tra trạng thái đơn hàng gần nhất của user (polling)
 *     security: [{ bearerAuth: [] }]
 */
router.get('/status', requireAuth, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const order  = await paymentsService.getOrderStatus(userId);

    return res.json({
      success: true,
      data: order,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /payments/my:
 *   get:
 *     tags: [Payments]
 *     summary: Lấy trạng thái Premium của user hiện tại
 *     security: [{ bearerAuth: [] }]
 */
router.get('/my', requireAuth, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const data   = await paymentsService.getUserPremiumStatus(userId);

    return res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
