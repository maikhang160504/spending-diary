require('dotenv').config();
const { pool } = require('./src/config/db');
const storiesService = require('./src/modules/stories/stories.service');

async function run() {
  const userRes = await pool.query('SELECT id FROM users LIMIT 1');
  const userId = userRes.rows[0].id;
  const resW = await pool.query('SELECT id FROM wallets LIMIT 1');
  const walletId = resW.rows[0].id;

  try {
    const list = await storiesService.list(userId, walletId);
    console.log("LIST:", list.length);
    console.log(list.map(s => s.id));
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    process.exit(0);
  }
}
run();
