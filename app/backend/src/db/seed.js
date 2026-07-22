'use strict';

require('../config/env');

const bcrypt = require('bcryptjs');
const { pool, withTransaction } = require('../config/db');
const env = require('../config/env');
const logger = require('../config/logger');

async function ensureDemoUser() {
  if (!env.seed.email || !env.seed.password) {
    logger.info('SEED_DEMO_USER_* not set; skipping demo user.');
    return null;
  }
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [env.seed.email]);
  if (existing.rowCount > 0) {
    logger.info({ email: env.seed.email }, 'demo user already exists');
    return existing.rows[0].id;
  }
  const hash = await bcrypt.hash(env.seed.password, 10);
  const inserted = await pool.query(
    `INSERT INTO users (username, email, password_hash, role)
     VALUES ($1, $2, $3, 'user')
     RETURNING id`,
    [env.seed.username, env.seed.email, hash]
  );
  const id = inserted.rows[0].id;
  logger.info({ id, email: env.seed.email }, 'demo user created');
  return id;
}

async function ensureDefaultWallet(userId) {
  if (!userId) return null;
  const existing = await pool.query(
    'SELECT id FROM wallets WHERE owner_id = $1 ORDER BY created_at LIMIT 1',
    [userId]
  );
  if (existing.rowCount > 0) return existing.rows[0].id;
  const r = await pool.query(
    `INSERT INTO wallets (owner_id, name, type, currency)
     VALUES ($1, 'Ví cá nhân', 'personal', 'VND')
     RETURNING id`,
    [userId]
  );
  await pool.query(
    `INSERT INTO wallet_members (wallet_id, user_id, role) VALUES ($1, $2, 'owner')
     ON CONFLICT DO NOTHING`,
    [r.rows[0].id, userId]
  );
  return r.rows[0].id;
}

async function seedSampleTransactions(userId, walletId) {
  if (!userId || !walletId) return;
  const existing = await pool.query(
    'SELECT COUNT(*)::int AS c FROM transactions WHERE creator_id = $1',
    [userId]
  );
  if (existing.rows[0].c > 0) return;
  const samples = [
    { amount: 45000, code: 'Food', note: 'Ăn phở sáng', daysAgo: 0 },
    { amount: 35000, code: 'Food', note: 'Trà sữa', daysAgo: 1 },
    { amount: 152000, code: 'Essentials', note: 'Đi siêu thị', daysAgo: 2 },
    { amount: 20000, code: 'Transport', note: 'Xăng xe', daysAgo: 3 },
    { amount: 350000, code: 'Shopping', note: 'Áo thun', daysAgo: 5 },
  ];
  await withTransaction(async (client) => {
    for (const s of samples) {
      await client.query(
        `INSERT INTO transactions
           (wallet_id, creator_id, category_code, amount, type, source, note, occurred_at)
         VALUES ($1, $2, $3, $4, 'expense', 'manual', $5, NOW() - ($6 || ' days')::interval)`,
        [walletId, userId, s.code, s.amount, s.note, s.daysAgo]
      );
    }
  });
  logger.info({ count: samples.length }, 'seeded sample transactions');
}

async function seedGroupBenchmarks() {
  // ── Demographic groups from onboarding step 4 ─────────────────────
  const AGE_GROUPS = ['18-22 tuổi', '23-30 tuổi', '31-40 tuổi', '41-50 tuổi', 'Trên 50'];
  const JOB_TYPES  = ['Sinh viên', 'Văn phòng', 'Freelancer', 'Kinh doanh', 'Khác'];

  // Spending profile per (age, job) – avg / p80 in VND/month for 6 core categories
  //   Food, Transport, Shopping, Entertainment, Housing, Essentials
  const profiles = {
    // ── 18-22 tuổi ──────────────────────────────────────────────────
    '18-22 tuổi|Sinh viên':   { Food: [1000000, 1800000], Transport: [450000, 750000], Shopping: [200000, 500000], Entertainment: [200000, 500000], Housing: [800000, 1200000], Essentials: [150000, 250000] },
    '18-22 tuổi|Văn phòng':   { Food: [3200000, 4200000], Transport: [800000, 1200000], Shopping: [1200000, 2000000], Entertainment: [1800000, 2800000], Housing: [2500000, 3500000], Essentials: [600000, 1000000] },
    '18-22 tuổi|Freelancer':  { Food: [3000000, 4000000], Transport: [500000, 800000], Shopping: [1000000, 1800000], Entertainment: [2000000, 3000000], Housing: [2200000, 3200000], Essentials: [550000, 900000] },
    '18-22 tuổi|Kinh doanh':  { Food: [3500000, 4500000], Transport: [1000000, 1500000], Shopping: [1500000, 2500000], Entertainment: [2200000, 3200000], Housing: [2800000, 4000000], Essentials: [700000, 1100000] },
    '18-22 tuổi|Khác':        { Food: [2500000, 3500000], Transport: [500000, 800000], Shopping: [700000, 1200000], Entertainment: [1200000, 2000000], Housing: [1800000, 2800000], Essentials: [450000, 750000] },

    // ── 23-30 tuổi ──────────────────────────────────────────────────
    '23-30 tuổi|Sinh viên':   { Food: [1200000, 2000000], Transport: [450000, 750000], Shopping: [200000, 500000], Entertainment: [200000, 500000], Housing: [800000, 1200000], Essentials: [150000, 250000] },
    '23-30 tuổi|Văn phòng':   { Food: [4500000, 6000000], Transport: [1200000, 1800000], Shopping: [2000000, 3500000], Entertainment: [3000000, 4200000], Housing: [4000000, 6000000], Essentials: [1000000, 1500000] },
    '23-30 tuổi|Freelancer':  { Food: [4000000, 5500000], Transport: [800000, 1200000], Shopping: [1800000, 3000000], Entertainment: [2800000, 4000000], Housing: [3500000, 5000000], Essentials: [900000, 1400000] },
    '23-30 tuổi|Kinh doanh':  { Food: [5500000, 7500000], Transport: [2000000, 3000000], Shopping: [3000000, 5000000], Entertainment: [3500000, 5000000], Housing: [5000000, 7000000], Essentials: [1200000, 1800000] },
    '23-30 tuổi|Khác':        { Food: [3500000, 4800000], Transport: [800000, 1200000], Shopping: [1200000, 2200000], Entertainment: [2000000, 3000000], Housing: [3000000, 4500000], Essentials: [700000, 1100000] },

    // ── 31-40 tuổi ──────────────────────────────────────────────────
    '31-40 tuổi|Sinh viên':   { Food: [3800000, 5000000], Transport: [900000, 1300000], Shopping: [1500000, 2500000], Entertainment: [2000000, 3000000], Housing: [3500000, 5000000], Essentials: [800000, 1200000] },
    '31-40 tuổi|Văn phòng':   { Food: [5500000, 7500000], Transport: [1800000, 2500000], Shopping: [2500000, 4000000], Entertainment: [2500000, 3800000], Housing: [5500000, 8000000], Essentials: [1500000, 2200000] },
    '31-40 tuổi|Freelancer':  { Food: [5000000, 7000000], Transport: [1200000, 1800000], Shopping: [2200000, 3500000], Entertainment: [2200000, 3500000], Housing: [4500000, 6500000], Essentials: [1200000, 1800000] },
    '31-40 tuổi|Kinh doanh':  { Food: [7000000, 9500000], Transport: [3000000, 4500000], Shopping: [4000000, 6500000], Entertainment: [3500000, 5500000], Housing: [7000000, 10000000], Essentials: [1800000, 2800000] },
    '31-40 tuổi|Khác':        { Food: [4500000, 6000000], Transport: [1000000, 1500000], Shopping: [1800000, 3000000], Entertainment: [1800000, 2800000], Housing: [4000000, 5500000], Essentials: [1000000, 1600000] },

    // ── 41-50 tuổi ──────────────────────────────────────────────────
    '41-50 tuổi|Sinh viên':   { Food: [4000000, 5500000], Transport: [1000000, 1500000], Shopping: [1500000, 2500000], Entertainment: [1500000, 2500000], Housing: [4000000, 5500000], Essentials: [1000000, 1500000] },
    '41-50 tuổi|Văn phòng':   { Food: [6000000, 8000000], Transport: [2000000, 3000000], Shopping: [2500000, 4000000], Entertainment: [2000000, 3200000], Housing: [6000000, 8500000], Essentials: [1800000, 2500000] },
    '41-50 tuổi|Freelancer':  { Food: [5500000, 7500000], Transport: [1500000, 2200000], Shopping: [2200000, 3500000], Entertainment: [1800000, 3000000], Housing: [5000000, 7000000], Essentials: [1500000, 2200000] },
    '41-50 tuổi|Kinh doanh':  { Food: [8000000, 11000000], Transport: [3500000, 5000000], Shopping: [5000000, 8000000], Entertainment: [3000000, 5000000], Housing: [8000000, 12000000], Essentials: [2200000, 3500000] },
    '41-50 tuổi|Khác':        { Food: [5000000, 6500000], Transport: [1200000, 1800000], Shopping: [2000000, 3200000], Entertainment: [1500000, 2500000], Housing: [4500000, 6000000], Essentials: [1200000, 1800000] },

    // ── Trên 50 ─────────────────────────────────────────────────────
    'Trên 50|Sinh viên':      { Food: [3500000, 5000000], Transport: [800000, 1200000], Shopping: [1200000, 2000000], Entertainment: [1000000, 1800000], Housing: [3500000, 5000000], Essentials: [1200000, 1800000] },
    'Trên 50|Văn phòng':      { Food: [5500000, 7500000], Transport: [1800000, 2500000], Shopping: [2000000, 3500000], Entertainment: [1500000, 2500000], Housing: [5000000, 7000000], Essentials: [2000000, 3000000] },
    'Trên 50|Freelancer':     { Food: [5000000, 7000000], Transport: [1200000, 1800000], Shopping: [1800000, 3000000], Entertainment: [1200000, 2200000], Housing: [4500000, 6500000], Essentials: [1800000, 2800000] },
    'Trên 50|Kinh doanh':     { Food: [7500000, 10000000], Transport: [3000000, 4500000], Shopping: [4000000, 6500000], Entertainment: [2500000, 4000000], Housing: [7000000, 10000000], Essentials: [2500000, 4000000] },
    'Trên 50|Khác':           { Food: [4500000, 6000000], Transport: [1000000, 1500000], Shopping: [1500000, 2500000], Entertainment: [1200000, 2000000], Housing: [4000000, 5500000], Essentials: [1500000, 2200000] },
  };

  // Flatten profiles into rows
  const benchmarks = [];
  for (const age of AGE_GROUPS) {
    for (const job of JOB_TYPES) {
      const key = `${age}|${job}`;
      const cats = profiles[key];
      if (!cats) continue;
      for (const [catId, [avg, p80]] of Object.entries(cats)) {
        benchmarks.push({ age_group: age, job_type: job, category_id: catId, period: 'month', avg, p80 });
      }
    }
  }

  await withTransaction(async (client) => {
    for (const b of benchmarks) {
      await client.query(
        `INSERT INTO group_spending_benchmarks (age_group, job_type, category_id, period, avg_amount, p80_amount, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (age_group, job_type, category_id, period) DO UPDATE
         SET avg_amount = EXCLUDED.avg_amount, p80_amount = EXCLUDED.p80_amount, updated_at = NOW()`,
        [b.age_group, b.job_type, b.category_id, b.period, b.avg, b.p80]
      );
    }
  });
  logger.info({ count: benchmarks.length }, 'seeded group spending benchmarks');
}

async function main() {
  const id = await ensureDemoUser();
  const walletId = await ensureDefaultWallet(id);
  await seedSampleTransactions(id, walletId);
  await seedGroupBenchmarks();
  await pool.end();
}

if (require.main === module) {
  main().catch((err) => {
    logger.error({ err: err.message }, 'seed failed');
    process.exit(1);
  });
}

module.exports = { main };
