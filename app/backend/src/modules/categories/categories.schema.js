'use strict';

const { z } = require('zod');

const createCategorySchema = z.object({
  name: z.string().min(1).max(80),
  code: z
    .string()
    .min(1)
    .max(40)
    .regex(/^[A-Za-z0-9_-]+$/),
  type: z.enum(['expense', 'income', 'both']).default('expense'),
  icon: z.string().max(60).optional(),
  color: z
    .string()
    .max(20)
    .regex(/^#?[0-9A-Fa-f]{3,8}$/)
    .optional(),
});

const updateCategorySchema = createCategorySchema.partial();

module.exports = { createCategorySchema, updateCategorySchema };
