-- Migration 013: Add is_draft to transactions for Voice Draft Fallback
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS is_draft BOOLEAN NOT NULL DEFAULT FALSE;
