-- Migration: Create and seed system_settings table
CREATE TABLE IF NOT EXISTS system_settings (
  key VARCHAR(255) PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed default settings if not already present
INSERT INTO system_settings (key, value)
VALUES 
  ('ocr_weight', '0.75'::jsonb),
  ('nlu_threshold', '0.85'::jsonb),
  ('prioritize_user_typing', 'true'::jsonb),
  ('date_fallback', '"transaction"'::jsonb)
ON CONFLICT (key) DO NOTHING;
