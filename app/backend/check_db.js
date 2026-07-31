const { query } = require('./src/config/db');

async function checkDb() {
  try {
    const userId = '13088b90-1e5b-433b-be15-ed19992fec4b'; // Assuming this is the user

    // Get latest transactions
    console.log('--- LATEST TRANSACTIONS ---');
    const txs = await query(
      `SELECT t.id, t.wallet_id, t.amount, t.type, t.note, t.occurred_at, t.created_at, t.is_deleted, s.id as story_id, ac.content_text as ai_comment
       FROM transactions t
       LEFT JOIN story_items si ON t.story_item_id = si.id
       LEFT JOIN stories s ON si.story_id = s.id
       LEFT JOIN ai_comments ac ON ac.story_id = s.id
       ORDER BY t.created_at DESC LIMIT 5`
    );
    console.log(JSON.stringify(txs.rows, null, 2));

    console.log('--- WALLETS ---');
    const wallets = await query(`SELECT id, type, name FROM wallets ORDER BY created_at DESC LIMIT 5`);
    console.log(JSON.stringify(wallets.rows, null, 2));

  } catch (e) {
    console.error('DB Error:', e);
  } finally {
    process.exit(0);
  }
}

checkDb();
