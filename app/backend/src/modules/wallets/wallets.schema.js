'use strict';

const { z } = require('zod');

const createWalletSchema = z.object({
  name: z.string().min(1).max(120),
  type: z.enum(['personal', 'group']).default('personal'),
  currency: z.string().min(3).max(10).default('VND'),
  icon: z.string().max(60).optional(),
  color: z
    .string()
    .max(20)
    .regex(/^#?[0-9A-Fa-f]{3,8}$/)
    .optional(),
  balance: z.number().nonnegative().optional(),
});

const updateWalletSchema = createWalletSchema.partial();

const addMemberSchema = z.object({
  userId: z.string().uuid(),
  role: z.enum(['owner', 'member', 'viewer']).default('member'),
});

const inviteMemberSchema = z.object({
  email: z.string().email(),
  role: z.enum(['owner', 'member', 'viewer']).default('member'),
});

module.exports = { createWalletSchema, updateWalletSchema, addMemberSchema, inviteMemberSchema };
