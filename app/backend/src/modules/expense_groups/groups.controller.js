'use strict';

const service = require('./groups.service');
const logger = require('../../config/logger');

async function createGroup(req, res, next) {
  try {
    const userId = req.user.id;
    const userName = req.user.username;
    const group = await service.createGroup(userId, userName, req.body);
    res.status(201).json({ success: true, data: group });
  } catch (err) {
    next(err);
  }
}

async function listGroups(req, res, next) {
  try {
    const userId = req.user.id;
    const groups = await service.listGroups(userId);
    res.json({ success: true, data: groups });
  } catch (err) {
    next(err);
  }
}

async function joinGroup(req, res, next) {
  try {
    const userId = req.user.id;
    const userName = req.user.username;
    const group = await service.joinGroup(userId, userName, req.body.inviteCode);
    res.json({ success: true, data: group });
  } catch (err) {
    if (err.message === 'NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'Invite code not found' });
    }
    next(err);
  }
}

async function getGroupDetails(req, res, next) {
  try {
    const userId = req.user.id;
    const groupId = req.params.id;
    const details = await service.getGroupDetails(groupId, userId);
    res.json({ success: true, data: details });
  } catch (err) {
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    next(err);
  }
}

async function addTransaction(req, res, next) {
  try {
    const userId = req.user.id;
    const groupId = req.params.id;
    const tx = await service.addTransaction(groupId, userId, req.body);
    res.status(201).json({ success: true, data: tx });
  } catch (err) {
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    next(err);
  }
}

async function updateTransaction(req, res, next) {
  try {
    const userId = req.user.id;
    const txId = req.params.txId;
    const tx = await service.updateTransaction(txId, userId, req.body);
    res.json({ success: true, data: tx });
  } catch (err) {
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    next(err);
  }
}

async function calculateSplit(req, res, next) {
  try {
    const userId = req.user.id;
    const groupId = req.params.id;
    const result = await service.calculateSplit(groupId, userId);
    res.json({ success: true, data: result });
  } catch (err) {
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    next(err);
  }
}

async function settleGroupDebt(req, res, next) {
  try {
    const userId = req.user.id;
    const groupId = req.params.id;
    const debtId = req.body.debtId;
    const result = await service.settleGroupDebt(groupId, userId, debtId);
    res.json({ success: true, data: result });
  } catch (err) {
    if (err.message === 'FORBIDDEN') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    if (err.message === 'INVALID_DEBT_ID' || err.message === 'DEBT_NOT_FOUND') {
      return res.status(400).json({ success: false, message: 'Debt not found or invalid' });
    }
    next(err);
  }
}

module.exports = {
  createGroup,
  listGroups,
  joinGroup,
  getGroupDetails,
  addTransaction,
  updateTransaction,
  calculateSplit,
  settleGroupDebt
};
