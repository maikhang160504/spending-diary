'use strict';

const crypto = require('crypto');
const { query } = require('../../config/db');
const env = require('../../config/env');
const logger = require('../../config/logger');

const PREMIUM_PRICE = 49000;

/**
 * Sinh mã đơn hàng độc nhất dạng SD + YYMMDDHHMMSS
 * VD: SD260712194530
 */
function generateOrderCode() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const yy  = String(now.getFullYear()).slice(-2);
  const mm  = pad(now.getMonth() + 1);
  const dd  = pad(now.getDate());
  const hh  = pad(now.getHours());
  const mi  = pad(now.getMinutes());
  const ss  = pad(now.getSeconds());
  // Thêm 3 random hex để tránh trùng trong cùng giây
  const rand = crypto.randomBytes(2).toString('hex').toUpperCase();
  return `SD${yy}${mm}${dd}${hh}${mi}${ss}${rand}`;
}

/**
 * Nội dung chuyển khoản theo format TKPMK - [Mã Đơn hàng]
 */
function buildTransferContent(code) {
  const prefix = env.sepay?.description || process.env.SEPAY_DES || 'TKPMK';
  return `${prefix} - ${code}`;
}

/**
 * Build VietQR image URL
 */
function buildVietQRUrl(code, amount) {
  const bank          = env.sepay.bank;
  const accountNumber = env.sepay.accountNumber;
  const accountName   = env.sepay.accountName;
  const addInfo       = encodeURIComponent(buildTransferContent(code));
  const name          = encodeURIComponent(accountName);
  return `https://img.vietqr.io/image/${bank}-${accountNumber}-compact2.png?amount=${amount}&addInfo=${addInfo}&accountName=${name}`;
}

/**
 * Tạo đơn hàng mới cho user.
 * - Xóa/hủy mọi đơn pending cũ của user này trước.
 * - Tạo record mới trong bảng orders.
 */
async function createOrder(userId) {
  // Lấy đơn pending gần nhất
  const existingPending = await query(
    `SELECT id, code, amount, status, created_at AS "createdAt"
     FROM orders
     WHERE user_id = $1 AND status = 'pending'
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId],
  );

  if (existingPending.rowCount > 0) {
    const order = existingPending.rows[0];
    const now = new Date();
    const orderDate = new Date(order.createdAt);
    const diffHours = (now - orderDate) / (1000 * 60 * 60);

    // Nếu đơn hàng còn mới (chưa quá 24h), tái sử dụng để tránh spam DB
    if (diffHours < 24) {
      logger.info({ userId, code: order.code }, '[Payments] Reuse existing pending order');
      return {
        orderId:         order.id,
        code:            order.code,
        amount:          parseFloat(order.amount),
        transferContent: buildTransferContent(order.code),
        qrUrl:           buildVietQRUrl(order.code, parseFloat(order.amount)),
        bank:            env.sepay.bank,
        accountNumber:   env.sepay.accountNumber,
        accountName:     env.sepay.accountName,
        createdAt:       order.createdAt,
      };
    } else {
      // Nếu đã quá 24h, hủy đơn cũ
      await query(
        `UPDATE orders SET status = 'cancelled', updated_at = NOW()
         WHERE id = $1`,
        [order.id],
      );
    }
  }

  // Nếu không có hoặc đã hủy đơn cũ -> tạo đơn mới
  const code   = generateOrderCode();
  const amount = PREMIUM_PRICE;

  const result = await query(
    `INSERT INTO orders (user_id, code, amount, status)
     VALUES ($1, $2, $3, 'pending')
     RETURNING id, code, amount, status, created_at AS "createdAt"`,
    [userId, code, amount],
  );

  const order = result.rows[0];
  logger.info({ userId, code }, '[Payments] New order created');

  return {
    orderId:         order.id,
    code:            order.code,
    amount:          parseFloat(order.amount),
    transferContent: buildTransferContent(order.code),
    qrUrl:           buildVietQRUrl(order.code, amount),
    bank:            env.sepay.bank,
    accountNumber:   env.sepay.accountNumber,
    accountName:     env.sepay.accountName,
    createdAt:       order.createdAt,
  };
}

/**
 * Lấy trạng thái đơn hàng pending gần nhất của user.
 */
async function getOrderStatus(userId) {
  const result = await query(
    `SELECT id, code, amount, status, paid_at AS "paidAt", created_at AS "createdAt"
     FROM orders
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId],
  );
  if (result.rowCount === 0) return null;
  const row = result.rows[0];
  return {
    orderId:   row.id,
    code:      row.code,
    amount:    parseFloat(row.amount),
    status:    row.status,
    paidAt:    row.paidAt,
    createdAt: row.createdAt,
  };
}

/**
 * Lấy thông tin premium của user.
 */
async function getUserPremiumStatus(userId) {
  const result = await query(
    `SELECT is_premium AS "isPremium" FROM users WHERE id = $1`,
    [userId],
  );
  if (result.rowCount === 0) return { isPremium: false };
  return { isPremium: !!result.rows[0].isPremium };
}

/**
 * Fulfillment: được gọi sau khi SePay webhook xác nhận thanh toán.
 * Tìm order dựa trên nội dung chuyển khoản, verify, cập nhật DB.
 * @param {string} transferContent  - Nội dung CK từ SePay (chứa mã đơn SD...)
 * @param {number} transferAmount   - Số tiền nhận từ SePay
 * @returns {{ success: boolean, userId?: string, code?: string, alreadyCompleted?: boolean }}
 */
async function fulfillOrder(transferContent, transferAmount) {
  // Trích xuất mã đơn SD... từ nội dung chuyển khoản
  const match = /SD[A-Z0-9]{12,18}/i.exec(transferContent);
  if (!match) {
    logger.warn({ transferContent }, '[Payments] No order code found in transfer content');
    return { success: false };
  }
  const code = match[0].toUpperCase();

  const orderResult = await query(
    `SELECT id, user_id AS "userId", amount, status FROM orders WHERE code = $1`,
    [code],
  );

  if (orderResult.rowCount === 0) {
    logger.warn({ code }, '[Payments] Order not found');
    return { success: false };
  }

  const order = orderResult.rows[0];

  if (order.status === 'completed') {
    logger.info({ code }, '[Payments] Order already completed — idempotent skip');
    return { success: true, alreadyCompleted: true, userId: order.userId, code };
  }

  // Kiểm tra số tiền (cho phép chênh lệch nhỏ 1000đ để xử lý phí bank)
  const expectedAmount = parseFloat(order.amount);
  if (transferAmount < expectedAmount - 1000) {
    logger.warn({ code, expectedAmount, transferAmount }, '[Payments] Insufficient transfer amount');
    return { success: false };
  }

  // Cập nhật order → completed
  await query(
    `UPDATE orders
     SET status = 'completed', paid_at = NOW(), transfer_content = $2, updated_at = NOW()
     WHERE id = $1`,
    [order.id, transferContent],
  );

  // Cập nhật user → is_premium = true
  await query(
    `UPDATE users SET is_premium = TRUE, updated_at = NOW() WHERE id = $1`,
    [order.userId],
  );

  logger.info({ code, userId: order.userId }, '[Payments] Order fulfilled — user upgraded to Premium');
  return { success: true, userId: order.userId, code };
}

/**
 * Admin: Cấp/tước Premium thủ công cho user.
 */
async function adminSetPremium(userId, isPremium) {
  await query(
    `UPDATE users SET is_premium = $2, updated_at = NOW() WHERE id = $1`,
    [userId, isPremium],
  );
}

/**
 * Admin: Lấy thống kê doanh thu.
 */
async function getRevenueStats() {
  const totalResult = await query(
    `SELECT
       COALESCE(SUM(amount), 0) AS total,
       COUNT(*) AS count
     FROM orders WHERE status = 'completed'`,
  );

  const monthResult = await query(
    `SELECT COALESCE(SUM(amount), 0) AS monthly
     FROM orders
     WHERE status = 'completed'
       AND created_at >= date_trunc('month', NOW())`,
  );

  const premiumUsersResult = await query(
    `SELECT COUNT(*) AS count FROM users WHERE is_premium = TRUE`,
  );

  return {
    totalRevenue:     parseFloat(totalResult.rows[0].total),
    totalOrders:      parseInt(totalResult.rows[0].count, 10),
    monthlyRevenue:   parseFloat(monthResult.rows[0].monthly),
    premiumUserCount: parseInt(premiumUsersResult.rows[0].count, 10),
  };
}

/**
 * Admin: Lấy biểu đồ doanh thu theo ngày (30 ngày gần nhất).
 */
async function getRevenueDailyHistory(days = 30) {
  const result = await query(
    `SELECT
       TO_CHAR(created_at, 'YYYY-MM-DD') AS date,
       COALESCE(SUM(amount), 0)::float    AS revenue,
       COUNT(*)::int                      AS orders
     FROM orders
     WHERE status = 'completed'
       AND created_at >= NOW() - CAST($1 || ' days' AS INTERVAL)
     GROUP BY TO_CHAR(created_at, 'YYYY-MM-DD')
     ORDER BY date ASC`,
    [days],
  );

  const map = {};
  for (const r of result.rows) map[r.date] = r;

  const data = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const dateStr   = d.toISOString().split('T')[0];
    const dateLabel = `${d.getDate()}/${d.getMonth() + 1}`;
    const log       = map[dateStr];
    data.push({
      date:    dateLabel,
      revenue: log ? parseFloat(log.revenue) : 0,
      orders:  log ? log.orders : 0,
    });
  }
  return data;
}

/**
 * Admin: Lấy danh sách lịch sử giao dịch.
 */
async function getOrdersList({ limit = 50, offset = 0 } = {}) {
  const result = await query(
    `SELECT
       o.id,
       o.code,
       o.amount,
       o.status,
       o.transfer_content AS "transferContent",
       o.paid_at          AS "paidAt",
       o.created_at       AS "createdAt",
       u.username,
       u.email,
       u.id AS "userId"
     FROM orders o
     JOIN users u ON o.user_id = u.id
     ORDER BY o.created_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset],
  );
  return result.rows;
}

module.exports = {
  createOrder,
  getOrderStatus,
  getUserPremiumStatus,
  fulfillOrder,
  adminSetPremium,
  getRevenueStats,
  getRevenueDailyHistory,
  getOrdersList,
  buildTransferContent,
  buildVietQRUrl,
  PREMIUM_PRICE,
};
