-- Migration 015: Add wallet_id to chat_sessions
ALTER TABLE chat_sessions
ADD COLUMN IF NOT EXISTS wallet_id UUID REFERENCES wallets(id) ON DELETE SET NULL;
