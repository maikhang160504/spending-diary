'use strict';

const store = require('../../src/services/billRetrainStore');

test('sampleStats counts pending and approved', () => {
  store.upsertSample({ id: 's1', status: 'pending' });
  store.upsertSample({ id: 's2', status: 'approved', imageExt: '.jpg' });
  store.saveImage('s2', Buffer.from('x'), '.jpg');
  const stats = store.sampleStats();
  expect(stats.pending).toBeGreaterThanOrEqual(1);
  expect(stats.approved).toBeGreaterThanOrEqual(1);
  expect(stats.approvedWithImage).toBeGreaterThanOrEqual(1);
});
