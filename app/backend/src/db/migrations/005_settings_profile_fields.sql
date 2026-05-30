-- Migration 005: add age_group and job_type to user_settings
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS age_group  VARCHAR(40);
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS job_type   VARCHAR(40);
