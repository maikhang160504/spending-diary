-- Migration 012 — Bill OCR label queue & retrain jobs (WebAdmin)
CREATE TABLE IF NOT EXISTS bill_label_samples (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_url       TEXT NOT NULL,
    transaction_id  UUID,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    auto_labels     JSONB NOT NULL DEFAULT '{}',
    admin_labels    JSONB,
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bill_label_samples_status ON bill_label_samples(status);

CREATE TABLE IF NOT EXISTS bill_retrain_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type        VARCHAR(32) NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'queued',
    sample_count    INT NOT NULL DEFAULT 0,
    kaggle_plan     JSONB,
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bill_retrain_jobs_status ON bill_retrain_jobs(status);
