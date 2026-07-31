require('dotenv').config();
const { Client } = require('pg');
const transactionsService = require('./src/modules/transactions/transactions.service');
const { pool } = require('./src/config/db'); // wait, transactions.service uses db.js

async function run() {
  const res = await pool.query('SELECT id FROM users LIMIT 1');
  const userId = res.rows[0].id;
  const resW = await pool.query('SELECT id FROM wallets LIMIT 1');
  const walletId = resW.rows[0].id;

  try {
    const tx = await transactionsService.create(userId, {
      walletId: walletId,
      amount: 10000,
      type: 'expense',
      categoryCode: 'Food',
      note: 'Test create',
      originalText: 'Test create text',
      source: 'text',
      aiComment: 'Test comment',
      mascotMood: 'Success'
    });
    console.log("SUCCESS", tx);
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    process.exit(0);
  }
}
run();
