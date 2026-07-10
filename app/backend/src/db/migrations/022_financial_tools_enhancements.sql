-- Thêm tiến độ cá nhân cho thành viên trong thử thách (challenge)
ALTER TABLE goal_members
  ADD COLUMN IF NOT EXISTS current_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Thêm nhắc hẹn tùy chỉnh cho khoản vay mượn (loans)
ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS reminder_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reminder_days_before INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_reminded BOOLEAN NOT NULL DEFAULT FALSE;
