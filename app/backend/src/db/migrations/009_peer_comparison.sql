CREATE TABLE IF NOT EXISTS group_spending_benchmarks (
    age_group VARCHAR(40),
    job_type VARCHAR(40),
    category_id VARCHAR(50),
    period VARCHAR(10),
    avg_amount DECIMAL(15, 2),
    p80_amount DECIMAL(15, 2),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (age_group, job_type, category_id, period)
);
