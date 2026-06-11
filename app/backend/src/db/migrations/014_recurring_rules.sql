-- Migration 014: Recurring transaction rules
CREATE TABLE IF NOT EXISTS recurring_rules (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id        UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    amount           NUMERIC(15, 2) NOT NULL,
    type             VARCHAR(20) NOT NULL DEFAULT 'expense', -- expense | income
    category_code    VARCHAR(40),
    note             TEXT,
    frequency        VARCHAR(20) NOT NULL, -- daily | weekly | monthly
    next_occurrence  DATE NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recurring_rules_user ON recurring_rules(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_rules_active_next ON recurring_rules(is_active, next_occurrence);
