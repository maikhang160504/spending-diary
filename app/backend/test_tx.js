const { query } = require('./src/config/db');
const txService = require('./src/modules/transactions/transactions.service');

async function test() {
  try {
    const userId = '13088b90-1e5b-433b-be15-ed19992fec4b'; // Trí's ID
    const r = await query('SELECT id FROM wallets WHERE creator_id = $1', [userId]);
    const walletId = r.rows[0].id;

    const tx = await txService.createTransaction(userId, {
      walletId,
      amount: 12345,
      type: 'expense',
      categoryCode: 'FOOD_AND_DINING',
      note: 'test from script',
      originalText: 'ăn phở 12345',
      source: 'text',
      aiComment: 'Đã lưu nhé!',
      mascotMood: 'Success'
    });

    console.log('Created TX:', tx);

    // Now test listForUser
    const list = await txService.listForUser(userId, { walletId, limit: 10, offset: 0 });
    console.log('Top 1 TX in list:', list.items[0]);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
}

test();
