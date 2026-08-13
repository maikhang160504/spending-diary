'use strict';

const express = require('express');
const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./groups.controller');
const { createGroupSchema, joinGroupSchema, addTransactionSchema } = require('./groups.schema');

const router = express.Router();

router.use(requireAuth);

router.post('/', validate({ body: createGroupSchema }), controller.createGroup);
router.get('/', controller.listGroups);
router.get('/preview/:code', controller.previewGroup);
router.post('/join', validate({ body: joinGroupSchema }), controller.joinGroup);
router.get('/:id', controller.getGroupDetails);
router.delete('/:id/members/:memberId', controller.removeMember);
router.post('/:id/members/manual', controller.addMember);
router.post('/:id/transactions', validate({ body: addTransactionSchema }), controller.addTransaction);
router.put('/transactions/:txId', controller.updateTransaction);
router.get('/transactions/:txId', controller.getGroupTransaction);
router.post('/:id/split', controller.calculateSplit);
router.post('/:id/settle', controller.settleGroupDebt);

module.exports = router;
