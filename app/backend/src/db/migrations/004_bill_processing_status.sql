-- Migration 004: Add processing_status to transactions for async bill flow
-- Values: 'done' (default) | 'pending' | 'failed'

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS processing_status VARCHAR(20) NOT NULL DEFAULT 'done';

CREATE INDEX IF NOT EXISTS idx_tx_processing_status
  ON transactions(processing_status)
  WHERE processing_status != 'done';
