-- Migration: Thêm bảng lưu lịch sử hạn mức ngân sách hàng tháng
-- Chạy 1 lần trên CockroachDB

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
);

CREATE INDEX IF NOT EXISTS idx_budget_snapshots_user_month
  ON budget_monthly_snapshots(user_id, month);
