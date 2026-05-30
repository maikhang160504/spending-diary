'use strict';

const express = require('express');

const validate = require('../../middlewares/validate');
const { requireAuth } = require('../../middlewares/auth');
const controller = require('./auth.controller');
const { registerSchema, loginSchema, refreshSchema, changePasswordSchema } = require('./auth.schema');

const router = express.Router();

/**
 * @openapi
 * tags:
 *   - name: Auth
 *     description: Đăng ký / đăng nhập / refresh
 *
 * components:
 *   securitySchemes:
 *     bearerAuth:
 *       type: http
 *       scheme: bearer
 *       bearerFormat: JWT
 *
 * /api/v1/auth/register:
 *   post:
 *     tags: [Auth]
 *     summary: Đăng ký tài khoản mới
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password, username]
 *             properties:
 *               email: { type: string, format: email, example: demo@money.local }
 *               password: { type: string, minLength: 8, example: demo1234 }
 *               username: { type: string, example: Demo User }
 *               preferredVibe: { type: string, example: funny }
 *     responses:
 *       201:
 *         description: Created
 *       409:
 *         description: Email tồn tại
 *
 * /api/v1/auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: Đăng nhập (email + password)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email: { type: string, format: email, example: demo@money.local }
 *               password: { type: string, example: demo1234 }
 *     responses:
 *       200:
 *         description: OK
 *       401:
 *         description: Sai thông tin
 *
 * /api/v1/auth/refresh:
 *   post:
 *     tags: [Auth]
 *     summary: Cấp lại access token bằng refresh token
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties:
 *               refreshToken: { type: string }
 *     responses:
 *       200: { description: OK }
 *
 * /api/v1/auth/logout:
 *   post:
 *     tags: [Auth]
 *     summary: Logout (revoke refresh token)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties:
 *               refreshToken: { type: string }
 *     responses:
 *       200: { description: OK }
 *
 * /api/v1/auth/me:
 *   get:
 *     tags: [Auth]
 *     summary: Thông tin user hiện tại
 *     security: [ { bearerAuth: [] } ]
 *     responses:
 *       200: { description: OK }
 *       401: { description: Unauthorized }
 *
 * /api/v1/auth/change-password:
 *   post:
 *     tags: [Auth]
 *     summary: Đổi mật khẩu
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword: { type: string }
 *               newPassword: { type: string, minLength: 8 }
 *     responses:
 *       200: { description: OK }
 *       401: { description: Wrong current password }
 *
 * /api/v1/users/me/streak:
 *   get:
 *     tags: [Auth]
 *     summary: Streak ghi chép của user
 *     security: [ { bearerAuth: [] } ]
 *     responses:
 *       200: { description: OK }
 *
 * /api/v1/auth/google:
 *   post:
 *     tags: [Auth]
 *     summary: Đăng nhập bằng Google (Google ID Token)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [idToken]
 *             properties:
 *               idToken: { type: string, description: Google ID Token từ GoogleSignIn }
 *     responses:
 *       200:
 *         description: Trả về accessToken, refreshToken, user
 *       401:
 *         description: Invalid Google token
 */

router.post('/register', validate({ body: registerSchema }), controller.register);
router.post('/login', validate({ body: loginSchema }), controller.login);
router.post('/refresh', validate({ body: refreshSchema }), controller.refresh);
router.post('/logout', validate({ body: refreshSchema }), controller.logout);
router.get('/me', requireAuth, controller.me);
router.patch('/me', requireAuth, controller.updateProfile);
router.post('/change-password', requireAuth, validate({ body: changePasswordSchema }), controller.changePassword);
router.post('/google', controller.googleLogin);

module.exports = router;
