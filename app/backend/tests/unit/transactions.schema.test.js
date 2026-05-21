'use strict';

const {
  createTxSchema,
  listTxQuerySchema,
} = require('../../src/modules/transactions/transactions.schema');

describe('transactions schemas', () => {
  test('createTx requires walletId + amount > 0', () => {
    const bad = createTxSchema.safeParse({ walletId: 'not-uuid', amount: -1 });
    expect(bad.success).toBe(false);
    const ok = createTxSchema.safeParse({
      walletId: '11111111-1111-1111-1111-111111111111',
      amount: 50000,
    });
    expect(ok.success).toBe(true);
    expect(ok.data.type).toBe('expense');
    expect(ok.data.source).toBe('manual');
  });

  test('list query coerces page/pageSize', () => {
    const parsed = listTxQuerySchema.parse({ page: '2', pageSize: '50' });
    expect(parsed.page).toBe(2);
    expect(parsed.pageSize).toBe(50);
  });
});
