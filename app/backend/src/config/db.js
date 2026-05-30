'use strict';

const { Pool } = require('pg');
const env = require('./env');
const logger = require('./logger');

if (!env.database.url) {
  // eslint-disable-next-line no-console
  console.warn('[db] DATABASE_URL is empty. Set it in .env before starting the server.');
}

// When ssl is an explicit object (e.g. no-verify), strip sslmode from the URL
// to prevent pg-connection-string from overriding rejectUnauthorized.
function buildConnString(url, ssl) {
  if (!url || typeof ssl !== 'object') return url || undefined;
  try {
    const u = new URL(url);
    u.searchParams.delete('sslmode');
    return u.toString();
  } catch {
    return url.replace(/([?&])sslmode=[^&]*/g, (_, sep) => sep === '?' ? '?' : '');
  }
}

const pool = new Pool({
  connectionString: buildConnString(env.database.url, env.database.ssl),
  ssl: env.database.ssl,
  max: 10,
  idleTimeoutMillis: 30000,
  application_name: 'moneystory-backend',
});

pool.on('error', (err) => {
  logger.error({ err }, 'Unexpected DB pool error');
});

async function query(text, params = []) {
  const started = Date.now();
  const result = await pool.query(text, params);
  const ms = Date.now() - started;
  if (ms > 200) {
    logger.warn({ ms, rows: result.rowCount, sql: text.slice(0, 120) }, 'slow query');
  }
  return result;
}

async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      logger.error({ err: rollbackErr }, 'rollback failed');
    }
    throw err;
  } finally {
    client.release();
  }
}

async function ping() {
  try {
    const r = await pool.query('SELECT 1 AS ok');
    return Number(r.rows[0].ok) === 1;
  } catch (err) {
    logger.error({ err: err.message }, 'db ping failed');
    return false;
  }
}

module.exports = { pool, query, withTransaction, ping };
