-- ============================================================================
--  MoneyStory / Expense AI -- full database schema
--  Compatible with both PostgreSQL 14+ and CockroachDB (cluster_connect in .env)
--  Run via:   psql $DATABASE_URL -f schema.sql
--  Or via:    node app/backend/src/db/migrate.js
-- ============================================================================

-- ---------- 0. Extensions ---------------------------------------------------
-- pgcrypto skipped: CockroachDB has gen_random_uuid() built-in.
-- On plain Postgres run manually: CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    code             VARCHAR(40) NOT NULL,        -- machine-friendly key (matches AI labels: Food, Shopping, ...)
    type             VARCHAR(20) NOT NULL DEFAULT 'expense', -- expense | income | both
    icon             VARCHAR(60),
    color            VARCHAR(20),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_owner_code
    ON categories(COALESCE(owner_id, '00000000-0000-0000-0000-000000000000'), code);

-- ---------- 4. Wallets ------------------------------------------------------
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

-- ---------- 6. Budgets ------------------------------------------------------
CREATE TABLE IF NOT EXISTS budgets (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id        UUID REFERENCES wallets(id) ON DELETE CASCADE,
    category_code    VARCHAR(40),                 -- NULL = overall budget
    period           VARCHAR(10) NOT NULL DEFAULT 'month',  -- week | month | year
    amount_limit     NUMERIC(15, 2) NOT NULL,
    start_date       DATE NOT NULL,
    end_date         DATE,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_budgets_user      ON budgets(user_id);

-- ---------- 7. Debts (for shared wallets) ----------------------------------
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

-- ---------- 8. AI logs ------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS idx_ai_logs_user     ON ai_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_logs_created  ON ai_logs(created_at);

-- ---------- 9. User learning (corrections + confirmed actions) -------------
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

-- ---------- 10. Seed system categories -------------------------------------
INSERT INTO categories (id, owner_id, name, code, type, icon, color)
VALUES
    (gen_random_uuid(), NULL, 'Ăn uống',       'Food',          'expense', 'utensils',     '#F59E0B'),
    (gen_random_uuid(), NULL, 'Mua sắm',       'Shopping',      'expense', 'shopping-bag', '#F472B6'),
    (gen_random_uuid(), NULL, 'Nhu yếu phẩm',   'Essentials',    'expense', 'home',         '#10B981'),
    (gen_random_uuid(), NULL, 'Di chuyển',     'Transport',     'expense', 'car',          '#3B82F6'),
    (gen_random_uuid(), NULL, 'Nhà ở / Hóa đơn', 'Housing',     'expense', 'wifi',         '#6366F1'),
    (gen_random_uuid(), NULL, 'Y tế',           'Health',       'expense', 'heart',        '#EF4444'),
    (gen_random_uuid(), NULL, 'Làm đẹp',        'Beauty',       'expense', 'sparkles',     '#EC4899'),
    (gen_random_uuid(), NULL, 'Giải trí',       'Entertainment','expense', 'music',        '#8B5CF6'),
    (gen_random_uuid(), NULL, 'Giáo dục',       'Education',    'expense', 'book',         '#0EA5E9'),
    (gen_random_uuid(), NULL, 'Quà tặng / Xã hội', 'Social',     'expense', 'gift',         '#A855F7'),
    (gen_random_uuid(), NULL, 'Khác',           'Others',       'expense', 'ellipsis',     '#6B7280'),
    (gen_random_uuid(), NULL, 'Lương',          'salary',       'income',  'briefcase',    '#22C55E'),
    (gen_random_uuid(), NULL, 'Thưởng',         'bonus',        'income',  'medal',        '#16A34A'),
    (gen_random_uuid(), NULL, 'Đầu tư',         'investment',   'income',  'trending-up',  '#0D9488'),
    (gen_random_uuid(), NULL, 'Kinh doanh',     'business',     'income',  'store',        '#7C3AED')
ON CONFLICT DO NOTHING;

-- ---------- 11. Orders (Premium payments via VietQR / SePay) ---------------
CREATE TABLE IF NOT EXISTS orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code             VARCHAR(30) NOT NULL UNIQUE,    -- VD: SD60711224215 (SD + YYMMDDHHMMSS)
    amount           NUMERIC(15, 2) NOT NULL DEFAULT 49000,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending | completed | cancelled
    transfer_content TEXT,                           -- Nội dung chuyển khoản thực tế từ SePay webhook
    paid_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_code   ON orders(code);
CREATE INDEX IF NOT EXISTS idx_orders_user          ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_pending       ON orders(user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_orders_status        ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created       ON orders(created_at);
