-- Migration 011: Smart Budgeting Recommendation — pre-computed suggestion cache
CREATE TABLE IF NOT EXISTS user_budget_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_month VARCHAR(7) NOT NULL,
    category_code VARCHAR(50) NOT NULL,
    suggested_amount DECIMAL(15,2) NOT NULL,
    base_spending DECIMAL(15,2),
    income_factor DECIMAL(5,3) DEFAULT 1.000,
    saving_rate DECIMAL(5,3) DEFAULT 0.000,
    holiday_factor DECIMAL(5,3) DEFAULT 1.000,
    reason TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, target_month, category_code)
);

CREATE INDEX IF NOT EXISTS idx_budget_suggestions_user_month
    ON user_budget_suggestions (user_id, target_month);
