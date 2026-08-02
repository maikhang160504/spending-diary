'use strict';

const { z } = require('zod');

const createLoanSchema = z.object({
  wallet_id: z.string().uuid().optional().nullable(),
  contact_name: z.string().min(1, 'Vui lòng nhập tên người vay/cho vay').max(100, 'Tên tối đa 100 ký tự').trim(),
  type: z.enum(['lend', 'borrow'], { errorMap: () => ({ message: "Loại phải là 'lend' hoặc 'borrow'" }) }),
  amount: z
    .number({ invalid_type_error: 'Số tiền phải là số' })
    .positive('Số tiền phải lớn hơn 0')
    .max(100_000_000_000, 'Số tiền tối đa 100 tỷ đồng'),
  due_date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Ngày phải có định dạng YYYY-MM-DD')
    .optional()
    .nullable(),
  note: z.string().max(500, 'Ghi chú tối đa 500 ký tự').optional().default(''),
  interest_rate: z
    .number({ invalid_type_error: 'Lãi suất phải là số' })
    .min(0, 'Lãi suất không được âm')
    .max(100, 'Lãi suất tối đa 100%')
    .optional()
    .default(0),
  create_transaction: z.boolean().optional().default(false),
});

const updateLoanSchema = z.object({
  contact_name: z.string().min(1).max(100).trim().optional(),
  amount: z.number().positive().max(100_000_000_000).optional(),
  paid_amount: z.number().min(0).max(100_000_000_000).optional(),
  due_date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional()
    .nullable(),
  status: z.enum(['active', 'completed', 'overdue']).optional(),
  note: z.string().max(500).optional(),
  interest_rate: z.number().min(0).max(100).optional(),
});

const loanContributeSchema = z.object({
  amount: z
    .number({ invalid_type_error: 'Số tiền phải là số' })
    .positive('Số tiền phải lớn hơn 0')
    .max(100_000_000_000, 'Số tiền tối đa 100 tỷ đồng'),
  walletId: z.string().uuid().optional().nullable(),
});

module.exports = { createLoanSchema, updateLoanSchema, loanContributeSchema };
