'use strict';

const { z } = require('zod');

const nluSchema = z.object({
  text: z.string().min(1).max(1000),
  profile: z.record(z.any()).optional(),
  emotion: z.string().max(40).optional(),
  runLlm: z.boolean().optional(),
});

const expenseFromTextSchema = z.object({
  walletId: z.string().uuid(),
  text: z.string().min(1).max(1000),
  occurredAt: z.string().datetime({ offset: true }).optional(),
  autoSave: z.boolean().default(true),
});

const correctionSchema = z.object({
  text: z.string().min(1).max(1000),
  intent: z.enum(['Record', 'Action', 'Chitchat']).optional(),
  categoryCode: z.string().max(40).optional(),
  recordType: z.enum(['Expense', 'Income']).optional(),
  actionType: z.string().max(40).optional(),
  predicted: z.record(z.any()).optional(),
});

const confirmActionSchema = z.object({
  actionSignature: z.string().min(1).max(160),
  actionType: z.string().max(40).optional(),
});

module.exports = {
  nluSchema,
  expenseFromTextSchema,
  correctionSchema,
  confirmActionSchema,
};
