-- 1. Create wallet_invite_codes table
CREATE TABLE IF NOT EXISTS wallet_invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    code VARCHAR(8) NOT NULL UNIQUE,
    created_by UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
    max_uses INT DEFAULT 10,
    use_count INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Clean up duplicate budgets (keep latest)
DELETE FROM budgets
WHERE is_active = TRUE
  AND id NOT IN (
    SELECT id FROM (
      SELECT DISTINCT ON (user_id, wallet_id, category_code, period) id
      FROM budgets
      WHERE is_active = TRUE
      ORDER BY user_id, wallet_id, category_code, period, created_at DESC
    ) tmp
  );

-- 3. Add partial unique index for budgets
CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_user_wallet_category_period 
ON budgets (user_id, wallet_id, category_code, period) 
WHERE (is_active = TRUE);
