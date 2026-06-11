-- Migration 012: Add alert_enabled to budgets for Smart Budget Alerts
ALTER TABLE budgets ADD COLUMN IF NOT EXISTS alert_enabled BOOLEAN NOT NULL DEFAULT TRUE;
