'use strict';

/**
 * Migration: Add Premium & Orders support
 * Run: node scripts/migrate_premium.js
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'no-verify'
    ? { rejectUnauthorized: false }
    : process.env.DATABASE_SSL === 'false' ? false : true,
});

const migrations = [
  // 1. Add google_id column to users
  `ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE`,

  // 2. Add is_premium column to users
  `ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT FALSE`,

  // 3. Create orders table
  `CREATE TABLE IF NOT EXISTS orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code             VARCHAR(30) NOT NULL UNIQUE,
    amount           NUMERIC(15, 2) NOT NULL DEFAULT 49000,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending',
    transfer_content TEXT,
    paid_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,

  // 4. Create indexes for orders
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_code    ON orders(code)`,
  `CREATE INDEX IF NOT EXISTS idx_orders_user           ON orders(user_id)`,
  `CREATE INDEX IF NOT EXISTS idx_orders_pending        ON orders(user_id) WHERE status = 'pending'`,
  `CREATE INDEX IF NOT EXISTS idx_orders_status         ON orders(status)`,
  `CREATE INDEX IF NOT EXISTS idx_orders_created        ON orders(created_at)`,
];

async function run() {
  const client = await pool.connect();
  try {
    console.log('🚀 Running Premium migration...\n');
    for (const sql of migrations) {
      const label = sql.trim().split('\n')[0].substring(0, 60);
      try {
        await client.query(sql);
        console.log(`  ✅ ${label}`);
      } catch (err) {
        if (err.code === '42701' || err.message.includes('already exists')) {
          console.log(`  ⏭  Already exists — skipped: ${label}`);
        } else {
          throw err;
        }
      }
    }
    console.log('\n✅ Migration completed successfully!');
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((err) => {
  console.error('❌ Migration failed:', err.message);
  process.exit(1);
});
