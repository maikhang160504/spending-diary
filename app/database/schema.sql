-- ============================================================================
--  Spending Diary / MoneyStory -- Full Unified Database Schema
--  Compatible with PostgreSQL 14+ and CockroachDB (cluster_connect in .env)
--  Consolidates initial schema + migrations 002 through 023 into a single source.
--  Run via:   psql $DATABASE_URL -f schema.sql
--  Or via:    node app/backend/src/db/migrate.js
-- ============================================================================

-- ---------- 0. Extensions ---------------------------------------------------
-- CockroachDB has gen_random_uuid() built-in.
-- On plain Postgres run manually: CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- PACKAGE 1: CORE EXPENSE & WALLET MANAGEMENT
-- ============================================================================

-- ---------- 1. Users --------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username         VARCHAR(80) NOT NULL,
    email            VARCHAR(160) NOT NULL UNIQUE,
    password_hash    TEXT NOT NULL,
    google_id        TEXT UNIQUE,                             -- Google OAuth ID
    avatar_url       TEXT,
    preferred_vibe   VARCHAR(20) NOT NULL DEFAULT 'funny',
    role             VARCHAR(20) NOT NULL DEFAULT 'user',     -- user | admin
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    is_premium       BOOLEAN NOT NULL DEFAULT FALSE,          -- Premium subscription flag
    last_login_at    TIMESTAMPTZ,
    -- Profile fields (Migration 002)
    age              INT CHECK (age IS NULL OR age > 0),
    job_title        VARCHAR(120),
    income_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,
    income_type      VARCHAR(20),                             -- 'salary' | 'business' | ...
    streak_count     INT NOT NULL DEFAULT 0,
    streak_max       INT NOT NULL DEFAULT 0,
    last_activity_at TIMESTAMPTZ,
    -- Password reset fields (Migration 023)
    reset_otp        VARCHAR(6),
    reset_otp_expires TIMESTAMP,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- 2. Refresh tokens ----------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash       TEXT NOT NULL,
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

-- ---------- 3. Categories ---------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id         UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = system category
    name             VARCHAR(80) NOT NULL,
    code             VARCHAR(40) NOT NULL,        -- machine-friendly key (Food, Shopping, ...)
    type             VARCHAR(20) NOT NULL DEFAULT 'expense', -- expense | income | both
    icon             VARCHAR(60),
    color            VARCHAR(20),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_owner_code
    ON categories(COALESCE(owner_id, '00000000-0000-0000-0000-000000000000'), code);

-- ---------- 4. Wallets & Members --------------------------------------------
CREATE TABLE IF NOT EXISTS wallets (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name             VARCHAR(120) NOT NULL,
    type             VARCHAR(20) NOT NULL DEFAULT 'personal',  -- personal | group
    currency         VARCHAR(10) NOT NULL DEFAULT 'VND',
    balance          NUMERIC(15, 2) NOT NULL DEFAULT 0,
    icon             VARCHAR(60),
    color            VARCHAR(20),
    is_archived      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wallets_owner ON wallets(owner_id);

CREATE TABLE IF NOT EXISTS wallet_members (
    wallet_id        UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role             VARCHAR(20) NOT NULL DEFAULT 'member',  -- owner | member | viewer
    joined_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ,                            -- Migration 007
    PRIMARY KEY (wallet_id, user_id)
);

-- ---------- 5. Transactions -------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id        UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    creator_id       UUID NOT NULL REFERENCES users(id),
    category_id      UUID REFERENCES categories(id),
    category_code    VARCHAR(40),                 -- denormalized for quick stats / AI label
    amount           NUMERIC(15, 2) NOT NULL,
    type             VARCHAR(20) NOT NULL DEFAULT 'expense', -- expense | income
    source           VARCHAR(20) NOT NULL DEFAULT 'manual',  -- manual | text | story | bill
    note             TEXT,
    image_url        TEXT,
    thumbnail_url    TEXT,
    ai_extracted     BOOLEAN NOT NULL DEFAULT FALSE,
    ai_confidence    NUMERIC(4, 3),
    ai_meta          JSONB NOT NULL DEFAULT '{}'::jsonb,
    mascot_mood      VARCHAR(30),
    ai_comment       TEXT,
    story_item_id    UUID,                        -- Migration 002 (FK added below after story_items creation)
    is_draft         BOOLEAN NOT NULL DEFAULT FALSE,          -- Migration 013
    occurred_at      TIMESTAMPTZ NOT NULL,        -- thực tế phát sinh
    server_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tx_wallet         ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_tx_creator        ON transactions(creator_id);
CREATE INDEX IF NOT EXISTS idx_tx_occurred       ON transactions(occurred_at);
CREATE INDEX IF NOT EXISTS idx_tx_category       ON transactions(category_code);
CREATE INDEX IF NOT EXISTS idx_tx_active         ON transactions(wallet_id, occurred_at) WHERE is_deleted = FALSE;

-- ---------- 6. Budgets & Spending Limits ------------------------------------
CREATE TABLE IF NOT EXISTS budgets (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id        UUID REFERENCES wallets(id) ON DELETE CASCADE,
    category_code    VARCHAR(40),                 -- NULL = overall budget
    period           VARCHAR(10) NOT NULL DEFAULT 'month',  -- week | month | year
    amount_limit     NUMERIC(15, 2) NOT NULL,
    start_date       DATE NOT NULL,
    end_date         DATE,
    alert_enabled    BOOLEAN NOT NULL DEFAULT TRUE,         -- Migration 012
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_budgets_user ON budgets(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_user_wallet_category_period 
    ON budgets (user_id, wallet_id, category_code, period) WHERE (is_active = TRUE);

CREATE TABLE IF NOT EXISTS spending_limits (
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_code  VARCHAR(40) NOT NULL,
    limit_amount   NUMERIC(15, 2) NOT NULL,
    spent_amount   NUMERIC(15, 2) NOT NULL DEFAULT 0,
    period         VARCHAR(10) NOT NULL DEFAULT 'month',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, category_code, period)
);

-- ---------- 7. Debts & Loans ------------------------------------------------
CREATE TABLE IF NOT EXISTS debts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id        UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    transaction_id   UUID REFERENCES transactions(id) ON DELETE SET NULL,
    debtor_id        UUID NOT NULL REFERENCES users(id),
    creditor_id      UUID NOT NULL REFERENCES users(id),
    amount           NUMERIC(15, 2) NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'unpaid', -- paid | unpaid
    settled_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_debts_wallet_open ON debts(wallet_id) WHERE status = 'unpaid';

CREATE TABLE IF NOT EXISTS loans (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id           UUID REFERENCES wallets(id) ON DELETE CASCADE,
    contact_name        VARCHAR(160) NOT NULL,
    type                VARCHAR(20) NOT NULL,            -- 'lend' (cho vay) | 'borrow' (đi vay)
    amount              NUMERIC(15, 2) NOT NULL,
    paid_amount         NUMERIC(15, 2) NOT NULL DEFAULT 0,
    due_date            DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'active', -- active | paid | overdue
    note                TEXT,
    interest_rate       NUMERIC(5, 2) DEFAULT 0,
    reminder_date       TIMESTAMPTZ,                     -- Migration 022
    reminder_days_before INT DEFAULT 0,
    is_reminded         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_loans_user   ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_wallet ON loans(wallet_id);

-- ---------- 8. Recurring Rules ----------------------------------------------
CREATE TABLE IF NOT EXISTS recurring_rules (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id        UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    amount           NUMERIC(15, 2) NOT NULL,
    type             VARCHAR(20) NOT NULL DEFAULT 'expense', -- expense | income
    category_code    VARCHAR(40),
    note             TEXT,
    frequency        VARCHAR(20) NOT NULL,                   -- daily | weekly | monthly
    next_occurrence  TIMESTAMPTZ NOT NULL,                   -- Migration 019
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_recurring_rules_user ON recurring_rules(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_rules_active_next ON recurring_rules(is_active, next_occurrence);


-- ============================================================================
-- PACKAGE 2: FINANCIAL GOALS & STORIES
-- ============================================================================

-- ---------- 9. Goals, Members & Contributions -------------------------------
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
    type            VARCHAR(20) DEFAULT 'personal',        -- personal | challenge | saving (Migration 020)
    invite_code     VARCHAR(32) UNIQUE,                    -- Migration 021
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(user_id);

CREATE TABLE IF NOT EXISTS goal_members (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id         UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            VARCHAR(20) NOT NULL DEFAULT 'member',
    current_amount  NUMERIC(15, 2) NOT NULL DEFAULT 0,       -- Migration 022
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    completed_at    TIMESTAMPTZ,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_goal_members_goal ON goal_members(goal_id);
CREATE INDEX IF NOT EXISTS idx_goal_members_user ON goal_members(user_id);

CREATE TABLE IF NOT EXISTS goal_contributions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id     UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    amount      NUMERIC(15, 2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- 10. Stories & Story Items ---------------------------------------
CREATE TABLE IF NOT EXISTS stories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(255),
    total_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'open',   -- open | closed | archived
    cover_image_url TEXT,
    occurred_on     DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stories_user_date ON stories(user_id, occurred_on DESC);
CREATE INDEX IF NOT EXISTS idx_stories_wallet    ON stories(wallet_id);

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

-- Link transaction foreign key to story_items safely
ALTER TABLE transactions
    ADD CONSTRAINT fk_tx_story_item
    FOREIGN KEY (story_item_id) REFERENCES story_items(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_tx_story_item ON transactions(story_item_id);


-- ============================================================================
-- PACKAGE 3: AI & PERSONALIZATION ENGINE
-- ============================================================================

-- ---------- 11. AI Processing & Inference Logs ------------------------------
CREATE TABLE IF NOT EXISTS ai_logs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID REFERENCES users(id) ON DELETE SET NULL,
    flow             VARCHAR(40) NOT NULL,    -- nlu | ocr | expense_from_text | expense_from_bill | comment
    request_input    JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_output  JSONB NOT NULL DEFAULT '{}'::jsonb,
    backend          VARCHAR(20),             -- real | mock | gemini | error
    latency_ms       INTEGER,
    confidence       NUMERIC(4, 3),
    error            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_logs_user    ON ai_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_logs_created ON ai_logs(created_at);

CREATE TABLE IF NOT EXISTS ai_processing_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_item_id       UUID REFERENCES story_items(id) ON DELETE CASCADE,
    transaction_id      UUID REFERENCES transactions(id) ON DELETE SET NULL,
    ocr_raw_json        JSONB NOT NULL DEFAULT '{}'::jsonb,
    nlp_intent_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    final_decision_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence          NUMERIC(4, 3),
    is_user_corrected   BOOLEAN NOT NULL DEFAULT FALSE,
    user_feedback       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_proc_logs_item ON ai_processing_logs(story_item_id);

CREATE TABLE IF NOT EXISTS ai_comments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id      UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    content_text  TEXT NOT NULL,
    visual_state  VARCHAR(30),                         -- 'happy' | 'worry' | 'sad' | ...
    emotion       VARCHAR(20),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_comments_story ON ai_comments(story_id);

-- ---------- 12. MiMo Chat Sessions & Messages -------------------------------
CREATE TABLE IF NOT EXISTS chat_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id       UUID REFERENCES wallets(id) ON DELETE SET NULL,  -- Migration 015
    title           VARCHAR(255),
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    last_message_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
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

-- ---------- 13. Smart Budgeting Suggestions & Peer Benchmarks ---------------
CREATE TABLE IF NOT EXISTS user_budget_suggestions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_month    VARCHAR(7) NOT NULL,
    category_code   VARCHAR(50) NOT NULL,
    suggested_amount DECIMAL(15,2) NOT NULL,
    base_spending   DECIMAL(15,2),
    income_factor   DECIMAL(5,3) DEFAULT 1.000,
    saving_rate     DECIMAL(5,3) DEFAULT 0.000,
    holiday_factor  DECIMAL(5,3) DEFAULT 1.000,
    reason          TEXT,
    status          VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, target_month, category_code)
);
CREATE INDEX IF NOT EXISTS idx_budget_suggestions_user_month ON user_budget_suggestions(user_id, target_month);

CREATE TABLE IF NOT EXISTS group_spending_benchmarks (
    age_group       VARCHAR(40) NOT NULL,
    job_type        VARCHAR(40) NOT NULL,
    category_id     VARCHAR(50) NOT NULL,
    period          VARCHAR(10) NOT NULL,
    avg_amount      DECIMAL(15, 2) NOT NULL,
    p80_amount      DECIMAL(15, 2) NOT NULL,
    updated_at      TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (age_group, job_type, category_id, period)
);

-- ---------- 14. User Learning & Corrections (Human-in-the-Loop) ------------
CREATE TABLE IF NOT EXISTS user_category_mappings (
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    keyword          VARCHAR(120) NOT NULL,
    category_code    VARCHAR(40) NOT NULL,
    weight           NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, keyword)
);

CREATE TABLE IF NOT EXISTS user_corrections (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text             TEXT NOT NULL,
    intent           VARCHAR(20),
    category_code    VARCHAR(40),
    record_type      VARCHAR(20),
    action_type      VARCHAR(40),
    predicted        JSONB,
    source           VARCHAR(20) NOT NULL DEFAULT 'user',   -- user | admin | ai_suggest
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_corrections_user ON user_corrections(user_id);

CREATE TABLE IF NOT EXISTS user_confirmed_actions (
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_signature VARCHAR(160) NOT NULL,
    action_type      VARCHAR(40),
    confirmed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, action_signature)
);

CREATE TABLE IF NOT EXISTS action_rejected_log (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text             TEXT,
    predicted        JSONB,
    rejected_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- 15. Bill OCR Retrain & Label Queue (WebAdmin) -------------------
CREATE TABLE IF NOT EXISTS bill_label_samples (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_url       TEXT NOT NULL,
    transaction_id  UUID,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    auto_labels     JSONB NOT NULL DEFAULT '{}',
    admin_labels    JSONB,
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bill_label_samples_status ON bill_label_samples(status);

CREATE TABLE IF NOT EXISTS bill_retrain_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type        VARCHAR(32) NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'queued',
    sample_count    INT NOT NULL DEFAULT 0,
    kaggle_plan     JSONB,
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_bill_retrain_jobs_status ON bill_retrain_jobs(status);


-- ============================================================================
-- PACKAGE 4: SYSTEM, NOTIFICATIONS & PAYMENTS
-- ============================================================================

-- ---------- 16. User Settings & System Configuration ------------------------
CREATE TABLE IF NOT EXISTS user_settings (
    user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    verbal_style          VARCHAR(20) NOT NULL DEFAULT 'funny',  -- funny | gentle | serious | sarcastic
    theme_mode            BOOLEAN NOT NULL DEFAULT FALSE,        -- false=light, true=dark
    personality           VARCHAR(20) NOT NULL DEFAULT 'mascot',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    locale                VARCHAR(10) NOT NULL DEFAULT 'vi-VN',
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS system_settings (
    key        VARCHAR(255) PRIMARY KEY,
    value      JSONB NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------- 17. Push Notifications & FCM Tokens ----------------------------
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT NOT NULL,
    platform   VARCHAR(20) NOT NULL DEFAULT 'android',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);

CREATE TABLE IF NOT EXISTS user_notification_logs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    time_period       VARCHAR(20) NOT NULL,
    sent_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, sent_date, time_period)
);
CREATE INDEX IF NOT EXISTS idx_user_notification_logs_user_date ON user_notification_logs(user_id, sent_date);

-- ---------- 18. Wallet Invite Codes -----------------------------------------
CREATE TABLE IF NOT EXISTS wallet_invite_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id   UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    code        VARCHAR(8) NOT NULL UNIQUE,
    created_by  UUID NOT NULL REFERENCES users(id),
    expires_at  TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
    max_uses    INT DEFAULT 10,
    use_count   INT DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- 19. Orders (Premium Payments via VietQR / SePay) ----------------
CREATE TABLE IF NOT EXISTS orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code             VARCHAR(30) NOT NULL UNIQUE,    -- VD: SD60711224215
    amount           NUMERIC(15, 2) NOT NULL DEFAULT 49000,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | completed | cancelled
    transfer_content TEXT,                           -- Nội dung chuyển khoản thực tế từ SePay webhook
    paid_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_code    ON orders(code);
CREATE INDEX IF NOT EXISTS idx_orders_user           ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_pending        ON orders(user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_orders_status         ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created        ON orders(created_at);


-- ============================================================================
-- SEED DATA: SYSTEM CATEGORIES & SETTINGS
-- ============================================================================

INSERT INTO categories (id, owner_id, name, code, type, icon, color)
VALUES
    (gen_random_uuid(), NULL, 'Ăn uống',           'Food',          'expense', 'utensils',     '#F59E0B'),
    (gen_random_uuid(), NULL, 'Mua sắm',           'Shopping',      'expense', 'shopping-bag', '#F472B6'),
    (gen_random_uuid(), NULL, 'Nhu yếu phẩm',       'Essentials',    'expense', 'home',         '#10B981'),
    (gen_random_uuid(), NULL, 'Di chuyển',         'Transport',     'expense', 'car',          '#3B82F6'),
    (gen_random_uuid(), NULL, 'Nhà ở / Hóa đơn',     'Housing',       'expense', 'wifi',         '#6366F1'),
    (gen_random_uuid(), NULL, 'Y tế',               'Health',        'expense', 'heart',        '#EF4444'),
    (gen_random_uuid(), NULL, 'Làm đẹp',            'Beauty',        'expense', 'sparkles',     '#EC4899'),
    (gen_random_uuid(), NULL, 'Giải trí',           'Entertainment', 'expense', 'music',        '#8B5CF6'),
    (gen_random_uuid(), NULL, 'Giáo dục',           'Education',     'expense', 'book',         '#0EA5E9'),
    (gen_random_uuid(), NULL, 'Quà tặng / Xã hội',  'Social',        'expense', 'gift',         '#A855F7'),
    (gen_random_uuid(), NULL, 'Khác',               'Others',        'expense', 'ellipsis',     '#6B7280'),
    (gen_random_uuid(), NULL, 'Lương',              'salary',        'income',  'briefcase',    '#22C55E'),
    (gen_random_uuid(), NULL, 'Thưởng',             'bonus',         'income',  'medal',        '#16A34A'),
    (gen_random_uuid(), NULL, 'Đầu tư',             'investment',    'income',  'trending-up',  '#0D9488'),
    (gen_random_uuid(), NULL, 'Kinh doanh',         'business',      'income',  'store',        '#7C3AED')
ON CONFLICT DO NOTHING;

INSERT INTO system_settings (key, value)
VALUES 
    ('ocr_weight', '0.75'::jsonb),
    ('nlu_threshold', '0.85'::jsonb),
    ('prioritize_user_typing', 'true'::jsonb),
    ('date_fallback', '"transaction"'::jsonb)
ON CONFLICT (key) DO NOTHING;
