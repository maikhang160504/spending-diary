'use strict';

const { z } = require('zod');

const createStorySchema = z.object({
  walletId: z.string().uuid(),
  title: z.string().min(1).max(255).optional(),
  occurredOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  coverImageUrl: z.string().url().optional(),
});

const updateStorySchema = z.object({
  title: z.string().min(1).max(255).optional(),
  status: z.enum(['open', 'closed', 'archived']).optional(),
  coverImageUrl: z.string().url().optional(),
});

module.exports = { createStorySchema, updateStorySchema };
