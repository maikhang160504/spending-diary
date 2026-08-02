'use strict';

/**
 * Chạy migration để tạo bảng budget_monthly_snapshots
 */
const { query } = require('../src/config/db');

async function migrate() {
  console.log('[migrate] Creating budget_monthly_snapshots table...');
  
  await query(`
    CREATE TABLE IF NOT EXISTS budget_monthly_snapshots (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      budget_id UUID REFERENCES budgets(id) ON DELETE SET NULL,
      category_code VARCHAR(40),
      month VARCHAR(7) NOT NULL,
      amount_limit NUMERIC(18,2) NOT NULL,
      spent NUMERIC(18,2) NOT NULL DEFAULT 0,
      source VARCHAR(30) DEFAULT 'manual',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_id, category_code, month)
    )
  `);

  await query(`
    CREATE INDEX IF NOT EXISTS idx_budget_snapshots_user_month
      ON budget_monthly_snapshots(user_id, month)
  `);

  console.log('[migrate] Done: budget_monthly_snapshots created successfully.');
  process.exit(0);
}

migrate().catch((err) => {
  console.error('[migrate] Error:', err.message);
  process.exit(1);
});
