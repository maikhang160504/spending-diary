-- ---------- 22. Group Settlements ----------------------------------------
CREATE TABLE IF NOT EXISTS group_settlements (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id         UUID NOT NULL REFERENCES expense_groups(id) ON DELETE CASCADE,
    from_member_id   UUID NOT NULL REFERENCES group_members(id) ON DELETE CASCADE,
    to_member_id     UUID NOT NULL REFERENCES group_members(id) ON DELETE CASCADE,
    amount           NUMERIC(15, 2) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_group_settlements_group_id ON group_settlements(group_id);
