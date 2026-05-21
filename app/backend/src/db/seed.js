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

async function main() {
  const id = await ensureDemoUser();
  const walletId = await ensureDefaultWallet(id);
  await seedSampleTransactions(id, walletId);
  await pool.end();
}

if (require.main === module) {
  main().catch((err) => {
    logger.error({ err: err.message }, 'seed failed');
    process.exit(1);
  });
}

module.exports = { main };
