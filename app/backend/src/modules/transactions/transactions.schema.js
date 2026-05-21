'use strict';

const { z } = require('zod');

const baseTxFields = {
  walletId: z.string().uuid(),
  categoryCode: z.string().min(1).max(40).optional(),
  amount: z.number().positive(),
  type: z.enum(['expense', 'income']).default('expense'),
  note: z.string().max(2000).optional(),
  occurredAt: z
    .string()
    .datetime({ offset: true })
    .optional(),
  source: z.enum(['manual', 'text', 'story', 'bill']).default('manual'),
  imageUrl: z.string().url().optional(),
  thumbnailUrl: z.string().url().optional(),
  aiExtracted: z.boolean().optional(),
  aiConfidence: z.number().min(0).max(1).optional(),
  aiMeta: z.record(z.any()).optional(),
};

const createTxSchema = z.object(baseTxFields);

const updateTxSchema = z
  .object({
    categoryCode: baseTxFields.categoryCode,
    amount: baseTxFields.amount.optional(),
    type: baseTxFields.type.optional(),
    note: baseTxFields.note,
    occurredAt: baseTxFields.occurredAt,
    imageUrl: baseTxFields.imageUrl,
    thumbnailUrl: baseTxFields.thumbnailUrl,
  })
  .partial();

const listTxQuerySchema = z
  .object({
    walletId: z.string().uuid().optional(),
    categoryCode: z.string().max(40).optional(),
    type: z.enum(['expense', 'income']).optional(),
    from: z.string().datetime({ offset: true }).optional(),
    to: z.string().datetime({ offset: true }).optional(),
    page: z.coerce.number().int().min(1).optional(),
    pageSize: z.coerce.number().int().min(1).max(100).optional(),
  })
  .partial();

module.exports = { createTxSchema, updateTxSchema, listTxQuerySchema };
