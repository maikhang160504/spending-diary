'use strict';

const { z } = require('zod');

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72),
  username: z.string().min(2).max(80),
  preferredVibe: z.string().max(20).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1).max(72),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(10),
});

module.exports = { registerSchema, loginSchema, refreshSchema };
