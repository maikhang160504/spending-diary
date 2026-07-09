-- NO TRANSACTION
-- Migration 019: Alter next_occurrence in recurring_rules from DATE to TIMESTAMPTZ
DROP INDEX IF EXISTS idx_recurring_rules_active_next;
ALTER TABLE recurring_rules ALTER COLUMN next_occurrence TYPE TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_recurring_rules_active_next ON recurring_rules(is_active, next_occurrence);
