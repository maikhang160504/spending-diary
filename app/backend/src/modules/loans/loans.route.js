'use strict';

const { Router } = require('express');
const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./loans.controller');
const { createLoanSchema, updateLoanSchema, loanContributeSchema } = require('./loans.schema');

const router = Router();

router.use(requireAuth);

router.get('/', controller.getLoans);
router.post('/', validate({ body: createLoanSchema }), controller.createLoan);
router.get('/:id', controller.getLoan);
router.patch('/:id', validate({ body: updateLoanSchema }), controller.updateLoan);
router.delete('/:id', controller.deleteLoan);

module.exports = router;
