-- ---------- 21. Add OCR fields to group_transactions ----------------------
ALTER TABLE group_transactions
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS processing_status VARCHAR(20) DEFAULT 'done',
ADD COLUMN IF NOT EXISTS is_draft BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ai_extracted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ai_confidence NUMERIC(5,4),
ADD COLUMN IF NOT EXISTS ai_meta JSONB;
