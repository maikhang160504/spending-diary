-- ============================================================================
--  Migration 002 — Extend schema theo CSDL.md
--    Bổ sung: user_settings, stories, story_items, ai_processing_logs,
--             ai_comments, goals, spending_limits, chat_sessions, chat_messages,
--             user profile fields (age, job_title, income, streak)
--  Idempotent: dùng IF NOT EXISTS / ADD COLUMN IF NOT EXISTS.
--  Tương thích Postgres 14+ và CockroachDB.
-- ============================================================================

-- ---------- 1. Bổ sung profile fields cho users ----------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS age INT CHECK (age IS NULL OR age > 0);
ALTER TABLE users ADD COLUMN IF NOT EXISTS job_title       VARCHAR(120);
ALTER TABLE users ADD COLUMN IF NOT EXISTS income_amount   NUMERIC(15, 2) NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS income_type     VARCHAR(20);   -- 'salary' | 'business' | ...
ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_count    INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_max      INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

-- ---------- 2. User settings (tone, theme, personality) --------------------
CREATE TABLE IF NOT EXISTS user_settings (
    user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    verbal_style   VARCHAR(20) NOT NULL DEFAULT 'funny',  -- funny | gentle | serious | sarcastic
    theme_mode     BOOLEAN NOT NULL DEFAULT FALSE,        -- false=light, true=dark
    personality    VARCHAR(20) NOT NULL DEFAULT 'mascot',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    locale         VARCHAR(10) NOT NULL DEFAULT 'vi-VN',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- 3. Stories (gom giao dịch theo "câu chuyện" / ngày) -----------
CREATE TABLE IF NOT EXISTS stories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(255),
    total_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'open',  -- open | closed | archived
    cover_image_url TEXT,
    occurred_on     DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stories_user_date ON stories(user_id, occurred_on DESC);
CREATE INDEX IF NOT EXISTS idx_stories_wallet    ON stories(wallet_id);

-- ---------- 4. Story items (text / image / voice — input thô của user) ----
CREATE TABLE IF NOT EXISTS story_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id     UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    raw_text     TEXT,
    media_url    TEXT,
    media_type   VARCHAR(20),                         -- image | voice | text
    ocr_status   VARCHAR(20) NOT NULL DEFAULT 'none', -- none | processing | completed | failed
    processed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_story_items_story ON story_items(story_id);

-- ---------- 5. Liên kết transactions ↔ story_items ------------------------
-- Trong schema cũ transactions.source='story' nhưng chưa có item_id;
-- thêm cột optional (không phá CRUD hiện tại).
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS story_item_id UUID
    REFERENCES story_items(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_tx_story_item ON transactions(story_item_id);

-- ---------- 6. AI processing logs (chi tiết per-item: OCR/NLU/Fusion) -----
CREATE TABLE IF NOT EXISTS ai_processing_logs (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_item_id      UUID REFERENCES story_items(id) ON DELETE CASCADE,
    transaction_id     UUID REFERENCES transactions(id) ON DELETE SET NULL,
    ocr_raw_json       JSONB NOT NULL DEFAULT '{}'::jsonb,
    nlp_intent_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
    final_decision_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence         NUMERIC(4, 3),
    is_user_corrected  BOOLEAN NOT NULL DEFAULT FALSE,
    user_feedback      TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_proc_logs_item ON ai_processing_logs(story_item_id);

-- ---------- 7. AI comments (Mascot bình luận story) -----------------------
CREATE TABLE IF NOT EXISTS ai_comments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id      UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    content_text  TEXT NOT NULL,
    visual_state  VARCHAR(30),                         -- 'happy' | 'worry' | 'sad' | ...
    emotion       VARCHAR(20),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_comments_story ON ai_comments(story_id);

-- ---------- 8. Goals (mục tiêu tiết kiệm) ---------------------------------
CREATE TABLE IF NOT EXISTS goals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id       UUID REFERENCES wallets(id) ON DELETE SET NULL,
    name            VARCHAR(160) NOT NULL,
    target_amount   NUMERIC(15, 2) NOT NULL,
    current_amount  NUMERIC(15, 2) NOT NULL DEFAULT 0,
    emoji           VARCHAR(16),
    deadline        DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'active', -- active | done | cancelled
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(user_id);

-- ---------- 9. Spending limits (hạn mức nhanh — bổ sung budgets) ----------
CREATE TABLE IF NOT EXISTS spending_limits (
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_code  VARCHAR(40) NOT NULL,
    limit_amount   NUMERIC(15, 2) NOT NULL,
    spent_amount   NUMERIC(15, 2) NOT NULL DEFAULT 0,
    period         VARCHAR(10) NOT NULL DEFAULT 'month',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, category_code, period)
);

-- ---------- 10. Chat sessions + messages (history Mascot) -----------------
CREATE TABLE IF NOT EXISTS chat_sessions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        VARCHAR(255),
    is_archived  BOOLEAN NOT NULL DEFAULT FALSE,
    last_message_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user ON chat_sessions(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id     UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role           VARCHAR(10) NOT NULL,                -- 'user' | 'assistant' | 'system'
    content        TEXT NOT NULL,
    intent_action  JSONB NOT NULL DEFAULT '{}'::jsonb,  -- nhãn NLU đã chạy
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, created_at);

-- ---------- 11. Helper view: stats view per wallet (optional) -------------
-- (chỉ tạo trên Postgres; Cockroach support đầy đủ)
-- Một summary view nhanh, có thể remove nếu không dùng.
CREATE OR REPLACE VIEW v_wallet_summary AS
SELECT
    w.id   AS wallet_id,
    w.owner_id,
    w.name,
    COALESCE(SUM(CASE WHEN t.type='expense' AND NOT t.is_deleted THEN t.amount END), 0) AS total_expense,
    COALESCE(SUM(CASE WHEN t.type='income'  AND NOT t.is_deleted THEN t.amount END), 0) AS total_income,
    COUNT(t.id) FILTER (WHERE NOT t.is_deleted)                                          AS tx_count
FROM wallets w
LEFT JOIN transactions t ON t.wallet_id = w.id
GROUP BY w.id, w.owner_id, w.name;
