'use strict';

const { z } = require('zod');

const createRecurringRuleSchema = z.object({
  walletId: z.string().uuid(),
  amount: z.number().positive(),
  type: z.enum(['expense', 'income']).default('expense'),
  categoryCode: z.string().min(1).max(40).optional().nullable(),
  note: z.string().optional().nullable(),
  frequency: z.enum(['daily', 'weekly', 'monthly']),
  nextOccurrence: z.string().refine((val) => !isNaN(Date.parse(val)), {
    message: "Invalid date format, must be a valid date or ISO 8601 string",
  }),
  isActive: z.boolean().default(true),
});

const updateRecurringRuleSchema = createRecurringRuleSchema.partial();

module.exports = { createRecurringRuleSchema, updateRecurringRuleSchema };
