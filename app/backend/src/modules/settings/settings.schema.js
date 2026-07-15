'use strict';

const { z } = require('zod');

const updateSettingsSchema = z.object({
  verbalStyle: z.string().max(40).optional(),
  themeMode: z.boolean().optional(),
  personality: z.string().min(1).max(20).optional(),
  notificationsEnabled: z.boolean().optional(),
  locale: z.string().min(2).max(10).optional(),
  ageGroup: z.string().max(40).optional().nullable(),
  jobType: z.string().max(40).optional().nullable(),
});

module.exports = { updateSettingsSchema };
