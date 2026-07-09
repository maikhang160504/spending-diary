'use strict';

/**
 * Minimal idempotent migration runner.
 *
 * Looks for schema in this order (first hit wins):
 *   1. process.env.SCHEMA_SQL_PATH          (absolute or relative path)
 *   2. <backend>/database/schema.sql        (copied into Docker image)
 *   3. <repoRoot>/app/database/schema.sql   (when running outside Docker)
 *
 * Then runs any additional .sql in src/db/migrations/. Each filename is
 * recorded in `_migrations` so re-running is safe.
 */
require('../config/env');

const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const logger = require('../config/logger');

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

function resolveSchemaPath() {
  const candidates = [
    process.env.SCHEMA_SQL_PATH,
    path.join(__dirname, '..', '..', 'database', 'schema.sql'),
    path.join(__dirname, '..', '..', '..', 'database', 'schema.sql'),
  ].filter(Boolean);
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

async function ensureTracker() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

async function alreadyApplied(filename) {
  const r = await pool.query('SELECT 1 FROM _migrations WHERE filename = $1', [filename]);
  return r.rowCount > 0;
}

async function applyFile(absolutePath, recordName) {
  const filename = recordName || path.basename(absolutePath);
  if (await alreadyApplied(filename)) {
    logger.info({ filename }, 'migration already applied — skip');
    return;
  }
  const sql = fs.readFileSync(absolutePath, 'utf8');
  logger.info({ filename, bytes: sql.length }, 'applying migration');
  // Dùng dedicated client để chạy multi-statement SQL.
  const client = await pool.connect();
  const noTx = sql.includes('-- NO TRANSACTION');
  try {
    if (noTx) {
      const statements = sql
        .split(';')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      for (const stmt of statements) {
        await client.query(stmt);
      }
      await client.query('INSERT INTO _migrations(filename) VALUES ($1)', [filename]);
    } else {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO _migrations(filename) VALUES ($1)', [filename]);
      await client.query('COMMIT');
    }
    logger.info({ filename }, 'migration done');
  } catch (err) {
    if (!noTx) {
      await client.query('ROLLBACK').catch(() => {});
    }
    throw err;
  } finally {
    client.release();
  }
}

async function main() {
  if (!process.env.DATABASE_URL && !process.env.cluster_connect) {
    logger.error('DATABASE_URL is not set. Aborting.');
    process.exit(1);
  }
  await ensureTracker();

  const schema = resolveSchemaPath();
  if (schema) {
    await applyFile(schema, 'schema.sql');
  } else {
    logger.warn('master schema.sql not found, skipped');
  }

  if (fs.existsSync(MIGRATIONS_DIR)) {
    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    for (const f of files) {
      await applyFile(path.join(MIGRATIONS_DIR, f), `migrations/${f}`);
    }
  }

  logger.info('migrations completed');
  await pool.end();
}

if (require.main === module) {
  main().catch((err) => {
    logger.error({ err: err.stack || err.message }, 'migration failed');
    process.exit(1);
  });
}

module.exports = { main };
