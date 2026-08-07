'use strict';

const { z } = require('zod');

const createGroupSchema = z.object({
  name: z.string().min(1).max(120),
  description: z.string().optional(),
  members: z.array(z.string()).optional() // List of display names to add immediately
});

const joinGroupSchema = z.object({
  inviteCode: z.string().min(1)
});

const addTransactionSchema = z.object({
  paidBy: z.string().uuid(),
  amount: z.number().positive(),
  note: z.string().optional(),
  occurredAt: z.string().datetime().optional()
});

module.exports = {
  createGroupSchema,
  joinGroupSchema,
  addTransactionSchema
};
