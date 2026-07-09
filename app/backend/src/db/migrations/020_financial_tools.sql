-- Thêm type cho goals để phân biệt Tiết kiệm và Thử thách
ALTER TABLE goals ADD COLUMN IF NOT EXISTS type VARCHAR(20) DEFAULT 'personal';

-- Bảng loans (Vay mượn)
CREATE TABLE IF NOT EXISTS loans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id       UUID REFERENCES wallets(id) ON DELETE CASCADE,
    contact_name    VARCHAR(160) NOT NULL,
    type            VARCHAR(20) NOT NULL, -- 'lend' (cho vay) | 'borrow' (đi vay)
    amount          NUMERIC(15, 2) NOT NULL,
    paid_amount     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    due_date        DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'active', -- active | paid | overdue
    note            TEXT,
    interest_rate   NUMERIC(5, 2) DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_loans_user ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_wallet ON loans(wallet_id);
