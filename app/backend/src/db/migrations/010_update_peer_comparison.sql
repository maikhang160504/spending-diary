DROP TABLE IF EXISTS group_spending_benchmarks;

CREATE TABLE group_spending_benchmarks (
    age_group VARCHAR(40) NOT NULL,
    job_type VARCHAR(40) NOT NULL,
    category_id VARCHAR(50) NOT NULL,
    period VARCHAR(10) NOT NULL,
    avg_amount DECIMAL(15, 2) NOT NULL,
    p80_amount DECIMAL(15, 2) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (age_group, job_type, category_id, period)
);
