'use strict';

const { z } = require('zod');

const createSessionSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  walletId: z.string().uuid().optional(),
});

const createMessageSchema = z.object({
  content: z.string().min(1),
  role: z.enum(['user', 'assistant', 'system']).default('user'),
  intentAction: z.record(z.unknown()).optional(),
});

module.exports = { createSessionSchema, createMessageSchema };
