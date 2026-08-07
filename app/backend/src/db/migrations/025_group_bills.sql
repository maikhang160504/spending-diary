-- ---------- 20. Group Bill Splitting ----------------------------------------
CREATE TABLE IF NOT EXISTS expense_groups (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(120) NOT NULL,
    description      TEXT,
    invite_code      VARCHAR(20) UNIQUE,
    created_by       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_members (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES expense_groups(id) ON DELETE CASCADE,
    user_id          UUID REFERENCES users(id) ON DELETE SET NULL, -- Nullable for users without app
    display_name     VARCHAR(80) NOT NULL,
    joined_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS group_transactions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES expense_groups(id) ON DELETE CASCADE,
    paid_by          UUID NOT NULL REFERENCES group_members(id) ON DELETE CASCADE,
    amount           NUMERIC(15, 2) NOT NULL DEFAULT 0,
    note             TEXT,
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_group_tx_group_id ON group_transactions(group_id);
