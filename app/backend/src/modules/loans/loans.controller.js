'use strict';

const loansService = require('./loans.service');

async function getLoans(req, res, next) {
  try {
    const loans = await loansService.list(req.user.id);
    res.json({ success: true, data: loans });
  } catch (err) {
    next(err);
  }
}

async function getLoan(req, res, next) {
  try {
    const loan = await loansService.getById(req.user.id, req.params.id);
    res.json({ success: true, data: loan });
  } catch (err) {
    next(err);
  }
}

async function createLoan(req, res, next) {
  try {
    const loan = await loansService.create(req.user.id, req.body);
    res.status(201).json({ success: true, data: loan });
  } catch (err) {
    next(err);
  }
}

async function updateLoan(req, res, next) {
  try {
    const loan = await loansService.update(req.user.id, req.params.id, req.body);
    res.json({ success: true, data: loan });
  } catch (err) {
    next(err);
  }
}

async function deleteLoan(req, res, next) {
  try {
    await loansService.remove(req.user.id, req.params.id);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

module.exports = { getLoans, getLoan, createLoan, updateLoan, deleteLoan };
