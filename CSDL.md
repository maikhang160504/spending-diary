CREATE TABLE users (
    id UUID PRIMARY KEY,

    username VARCHAR(50) UNIQUE NOT NULL,

    email VARCHAR(100) UNIQUE NOT NULL,

    password_hash TEXT NOT NULL,

    age INT CHECK (age > 0),

    job_title VARCHAR(100),

    income_amount NUMERIC DEFAULT 0,

    income_type VARCHAR(20),

    avatar_url TEXT,

    streak_count INT DEFAULT 0,

    streak_max INT,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_settings (
    user_id UUID PRIMARY KEY,

    verbal_style VARCHAR(20),

    theme_mode BOOLEAN DEFAULT FALSE,

    personality VARCHAR(20),

    CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE TABLE wallets (
    id UUID PRIMARY KEY,

    name VARCHAR(100),

    type VARCHAR(20),

    balance NUMERIC DEFAULT 0,

    created_by UUID,

    CONSTRAINT fk_wallet_created_by
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE SET NULL
);

CREATE TABLE wallet_members (
    wallet_id UUID,

    user_id UUID,

    role VARCHAR(20),

    PRIMARY KEY (wallet_id, user_id),

    CONSTRAINT fk_wallet_members_wallet
        FOREIGN KEY (wallet_id)
        REFERENCES wallets(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_wallet_members_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE TABLE stories (
    id UUID PRIMARY KEY,

    wallet_id UUID,

    user_id UUID,

    title VARCHAR(255),

    total_amount NUMERIC DEFAULT 0,

    status VARCHAR(20),

    CONSTRAINT fk_story_wallet
        FOREIGN KEY (wallet_id)
        REFERENCES wallets(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_story_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


CREATE TABLE story_items (
    id UUID PRIMARY KEY,

    story_id UUID,

    raw_text TEXT,

    media_url TEXT,

    media_type VARCHAR(20),
    ocr_status VARCHAR(20) DEFAULT 'none', -- 'none', 'processing', 'completed', 'failed'
    processed_at TIMESTAMP;
    CONSTRAINT fk_story_item_story
        FOREIGN KEY (story_id)
        REFERENCES stories(id)
        ON DELETE CASCADE
);

CREATE TABLE transactions (
    id UUID PRIMARY KEY,

    item_id UUID,

    category_id INT,

    amount NUMERIC NOT NULL,

    raw_content TEXT,
    ai_metadata JSONB,
    is_confirmed BOOLEAN DEFAULT FALSE,
    transaction_date DATE NOT NULL,

    is_verified BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_transaction_item
        FOREIGN KEY (item_id)
        REFERENCES story_items(id),
    CONSTRAINT fk_transaction_category
        FOREIGN KEY (category_id)
        REFERENCES categories(id)
);

CREATE TABLE ai_processing_logs (
    id SERIAL PRIMARY KEY,
    item_id UUID,
    
    -- Dữ liệu thô AI bóc tách
    ocr_raw_json JSONB,       -- Kết quả từ VietOCR/PaddleOCR
    nlp_intent_json JSONB,    -- Kết quả từ model phân loại SVM/Logistic
    
    -- LOGIC FUSION: Lưu lại quyết định cuối cùng của hệ thống
    final_decision_json JSONB, -- Ví dụ: {"amount": 50000, "source": "OCR", "category": "Food", "source": "NLP"}
    
    confidence FLOAT,          -- Độ tin cậy trung bình
    
    -- Dành cho việc Labeling (Quan trọng cho PO)
    is_user_corrected BOOLEAN DEFAULT FALSE, -- User có sửa lại kết quả AI không?
    user_feedback TEXT,                      -- Lưu ý của user nếu có
    
    CONSTRAINT fk_ai_log_item
        FOREIGN KEY (item_id)
        REFERENCES story_items(id) -- Sửa lại cho đúng tên bảng story_items
        ON DELETE CASCADE
);


CREATE TABLE ai_comments (
    id UUID PRIMARY KEY,

    story_id UUID,

    content_text TEXT,

    visual_state VARCHAR(20),

    CONSTRAINT fk_ai_comment_story
        FOREIGN KEY (story_id)
        REFERENCES stories(id)
        ON DELETE CASCADE
);



CREATE TABLE goals (
    id UUID PRIMARY KEY,

    user_id UUID,

    name VARCHAR(100),

    target_amount NUMERIC NOT NULL,

    current_amount NUMERIC DEFAULT 0,

    emoji VARCHAR(10),

    CONSTRAINT fk_goal_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE TABLE spending_limits (
    user_id UUID,

    category_id INT,

    limit_amount NUMERIC NOT NULL,

    spent_amount NUMERIC DEFAULT 0,

    PRIMARY KEY (user_id, category_id),

    CONSTRAINT fk_spending_limit_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_spending_limit_category
        FOREIGN KEY (category_id)
        REFERENCES categories(id)
        ON DELETE CASCADE
);

CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY,

    user_id UUID,

    title VARCHAR(255),

    is_archived BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW(),

    updated_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_chat_session_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY,

    session_id UUID,

    role VARCHAR(10),

    content TEXT NOT NULL,

    intent_action JSONB,

    created_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_chat_message_session
        FOREIGN KEY (session_id)
        REFERENCES chat_sessions(id)
        ON DELETE CASCADE
);
