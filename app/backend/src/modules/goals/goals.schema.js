'use strict';

const { z } = require('zod');

const createGoalSchema = z.object({
  walletId: z.string().uuid().optional(),
  name: z.string().min(1).max(160),
  targetAmount: z.number().positive(),
  emoji: z.string().max(16).optional(),
  deadline: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

const updateGoalSchema = createGoalSchema.partial();

const contributeSchema = z.object({
  amount: z.number().positive(),
});

module.exports = { createGoalSchema, updateGoalSchema, contributeSchema };
