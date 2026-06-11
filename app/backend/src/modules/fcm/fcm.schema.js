'use strict';

const { z } = require('zod');

const registerFcmTokenSchema = z.object({
  token: z.string().min(10).max(4096),
  platform: z.enum(['android', 'ios', 'web']).optional().default('android'),
});

const removeFcmTokenSchema = z.object({
  token: z.string().min(10).max(4096),
});

module.exports = { registerFcmTokenSchema, removeFcmTokenSchema };
