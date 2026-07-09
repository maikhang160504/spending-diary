'use strict';

const { Router } = require('express');
const { requireAuth } = require('../../middlewares/auth');
const controller = require('./loans.controller');

const router = Router();

router.use(requireAuth);

router.get('/', controller.getLoans);
router.post('/', controller.createLoan);
router.get('/:id', controller.getLoan);
router.patch('/:id', controller.updateLoan);
router.delete('/:id', controller.deleteLoan);

module.exports = router;
