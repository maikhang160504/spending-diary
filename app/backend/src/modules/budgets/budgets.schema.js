'use strict';

const { z } = require('zod');

const createBudgetSchema = z.object({
  walletId: z.string().uuid().optional(),
  categoryCode: z.string().min(1).max(40).optional(),
  period: z.enum(['week', 'month', 'year']).default('month'),
  amountLimit: z.number().positive(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  endDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

const updateBudgetSchema = createBudgetSchema.partial();

module.exports = { createBudgetSchema, updateBudgetSchema };
