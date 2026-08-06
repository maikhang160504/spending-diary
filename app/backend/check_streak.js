'use strict';
require('dotenv').config({ path: __dirname + '/.env' });
const { query } = require('./src/config/db');

async function fix() {
  const sql = `UPDATE transactions SET occurred_at = '2019-12-06T00:00:00+07:00' WHERE id = 'a7816418-cb6f-4dc3-8bcb-5a162bbaae34'`;
  const r = await query(sql);
  console.log('Fixed rows:', r.rowCount);
  process.exit(0);
}
fix().catch(e => { console.error(e.message); process.exit(1); });
