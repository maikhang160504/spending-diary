'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const store = require('../../src/services/billRetrainStore');

test('sampleStats counts pending and approved', () => {
  store.upsertSample({ id: 's1', status: 'pending' });
  store.upsertSample({ id: 's2', status: 'approved', imageExt: '.jpg' });
  store.saveImage('s2', Buffer.from('x'), '.jpg');
  const stats = store.sampleStats();
  assert.ok(stats.pending >= 1);
  assert.ok(stats.approved >= 1);
  assert.ok(stats.approvedWithImage >= 1);
});
