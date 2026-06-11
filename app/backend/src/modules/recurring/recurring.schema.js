'use strict';

const { z } = require('zod');

const createRecurringRuleSchema = z.object({
  walletId: z.string().uuid(),
  amount: z.number().positive(),
  type: z.enum(['expense', 'income']).default('expense'),
  categoryCode: z.string().min(1).max(40).optional().nullable(),
  note: z.string().optional().nullable(),
  frequency: z.enum(['daily', 'weekly', 'monthly']),
  nextOccurrence: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  isActive: z.boolean().default(true),
});

const updateRecurringRuleSchema = createRecurringRuleSchema.partial();

module.exports = { createRecurringRuleSchema, updateRecurringRuleSchema };
