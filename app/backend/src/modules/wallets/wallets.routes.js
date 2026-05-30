'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./wallets.controller');
const {
  createWalletSchema,
  updateWalletSchema,
  addMemberSchema,
  inviteMemberSchema,
} = require('./wallets.schema');

const router = express.Router();

/**
 * @openapi
 * tags: [{ name: Wallets, description: Ví cá nhân & ví chung }]
 *
 * /api/v1/wallets:
 *   get:
 *     tags: [Wallets]
 *     summary: Danh sách ví user đang tham gia
 *     security: [ { bearerAuth: [] } ]
 *     responses: { 200: { description: OK } }
 *   post:
 *     tags: [Wallets]
 *     summary: Tạo ví mới
 *     security: [ { bearerAuth: [] } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name: { type: string, example: Ví du lịch }
 *               type: { type: string, enum: [personal, group], example: group }
 *               currency: { type: string, example: VND }
 *               icon: { type: string }
 *               color: { type: string }
 *     responses: { 201: { description: Created } }
 *
 * /api/v1/wallets/{id}:
 *   get:
 *     tags: [Wallets]
 *     summary: Chi tiết ví
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *     responses: { 200: { description: OK } }
 *   patch:
 *     tags: [Wallets]
 *     summary: Cập nhật ví
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   delete:
 *     tags: [Wallets]
 *     summary: Archive ví
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *
 * /api/v1/wallets/{id}/members:
 *   get:
 *     tags: [Wallets]
 *     summary: Danh sách thành viên ví
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *   post:
 *     tags: [Wallets]
 *     summary: Thêm thành viên (owner only)
 *     security: [ { bearerAuth: [] } ]
 *     parameters: [ { in: path, name: id, required: true, schema: { type: string, format: uuid } } ]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [userId]
 *             properties:
 *               userId: { type: string, format: uuid }
 *               role: { type: string, enum: [owner, member, viewer], example: member }
 *
 * /api/v1/wallets/{id}/members/{memberId}:
 *   delete:
 *     tags: [Wallets]
 *     summary: Xoá thành viên
 *     security: [ { bearerAuth: [] } ]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *       - { in: path, name: memberId, required: true, schema: { type: string, format: uuid } }
 */

router.use(requireAuth);
router.get('/', controller.list);
router.post('/', validate({ body: createWalletSchema }), controller.create);
router.get('/:id', controller.get);
router.patch('/:id', validate({ body: updateWalletSchema }), controller.update);
router.delete('/:id', controller.archive);

router.get('/:id/members', controller.listMembers);
router.post(
  '/:id/members',
  validate({ body: addMemberSchema }),
  controller.addMember
);
router.post(
  '/:id/invite',
  validate({ body: inviteMemberSchema }),
  controller.inviteMember
);
router.delete('/:id/members/:memberId', controller.removeMember);

module.exports = router;
