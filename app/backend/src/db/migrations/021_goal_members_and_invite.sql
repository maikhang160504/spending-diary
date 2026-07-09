ALTER TABLE goals ALTER COLUMN wallet_id DROP NOT NULL;
ALTER TABLE goals ADD COLUMN IF NOT EXISTS invite_code VARCHAR(32) UNIQUE;

CREATE TABLE IF NOT EXISTS goal_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_goal_members_goal ON goal_members(goal_id);
CREATE INDEX IF NOT EXISTS idx_goal_members_user ON goal_members(user_id);
