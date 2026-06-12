-- Track dispatched push notifications per user, date, and period to avoid double-spamming
CREATE TABLE IF NOT EXISTS user_notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type VARCHAR(50) NOT NULL,
  time_period VARCHAR(20) NOT NULL,
  sent_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, sent_date, time_period)
);

CREATE INDEX IF NOT EXISTS idx_user_notification_logs_user_date ON user_notification_logs(user_id, sent_date);
