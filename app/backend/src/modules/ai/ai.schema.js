'use strict';

const { z } = require('zod');

const nluSchema = z.object({
  text: z.string().min(1).max(1000),
  profile: z.record(z.any()).optional(),
  nlgPersona: z.string().max(40).optional(),
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
  transactionId: z.string().uuid().optional(),
  intent: z.enum(['Record', 'Action', 'Chitchat']).optional(),
  categoryCode: z.string().max(40).optional(),
  recordType: z.enum(['Expense', 'Income']).optional(),
  actionType: z.string().max(40).optional(),
  predicted: z.record(z.any()).optional(),
});

const confirmActionSchema = z.object({
  actionSignature: z.string().min(1).max(160),
  actionType: z.string().max(40).optional(),
  messageId: z.string().uuid().optional(),
});

const executeActionSchema = z.object({
  actionType: z.string().min(1).max(40),
  timeRange: z
    .object({
      from: z.string(),
      to: z.string(),
      period_label: z.string().optional(),
      granularity: z.string().optional(),
    })
    .optional(),
  walletId: z.string().uuid().optional(),
  categoryCode: z.string().max(40).optional(),
  amount: z.number().positive().optional(),
  text: z.string().max(1000).optional(),
  query: z.string().max(200).optional(),
  goalName: z.string().max(160).optional(),
  verbalStyle: z.enum(['funny', 'gentle', 'serious', 'sarcastic', 'strict']).optional(),
  actionDetails: z.record(z.any()).optional(),
  minAmount: z.number().positive().optional(),
  limit: z.number().int().min(1).max(20).optional(),
});

const dislikeIntentSchema = z.object({
  text: z.string().min(1).max(1000),
  predictedIntent: z.string().max(80).optional().nullable(),
  predictedActionType: z.string().max(80).optional().nullable(),
  sessionId: z.string().optional().nullable(),
  messageId: z.string().optional().nullable(),
  reason: z.string().max(500).optional().nullable(),
});

module.exports = {
  nluSchema,
  expenseFromTextSchema,
  correctionSchema,
  confirmActionSchema,
  executeActionSchema,
  dislikeIntentSchema,
};

