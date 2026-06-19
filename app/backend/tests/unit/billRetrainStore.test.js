'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');

const storePath = path.join(os.tmpdir(), `bill_retrain_test_${Date.now()}`);
const originalStorage = path.join(__dirname, '../../storage/bill_retrain');

// Patch storage path via re-require pattern
process.env.BILL_RETRAIN_TEST = storePath;

const store = require('../../src/services/billRetrainStore');

test('billRetrainStore deleteSample removes index and image', () => {
  const id = 'test-delete-1';
  store.upsertSample({ id, status: 'pending', imageExt: '.jpg' });
  store.saveImage(id, Buffer.from('fake'), '.jpg');
  const imgPath = path.join(storePath, 'bill_retrain', 'images', `${id}.jpg`);
  assert.ok(fs.existsSync(imgPath), 'image file should exist before delete');
  const removed = store.deleteSample(id);
  assert.ok(removed);
  assert.equal(store.getSample(id), null);
  assert.equal(store.readImage(id), null);
  assert.ok(!fs.existsSync(imgPath), 'image file should be removed from disk');
});

test('billRetrainStore upsert and approve', () => {
  const id = 'test-sample-1';
  store.upsertSample({
    id,
    status: 'pending',
    imageExt: '.jpg',
    autoLabels: { boxes: [{ text: 'WINMART', entity: 'SELLER' }] },
    adminLabels: [{ text: 'WINMART', entity: 'SELLER' }],
  });
  const listed = store.listSamples('pending');
  assert.ok(listed.some((s) => s.id === id));
  const approved = store.approveSample(id, [{ text: 'WINMART', entity: 'SELLER' }], 'admin');
  assert.equal(approved.status, 'approved');
  const exportRows = store.approvedForExport();
  assert.ok(exportRows.length >= 1);
});

test('billRetrainStore saveImage and readImage', () => {
  const id = 'test-image-1';
  store.upsertSample({ id, status: 'pending', imageExt: '.jpg' });
  const url = store.saveImage(id, Buffer.from('fake-image'), '.jpg');
  assert.match(url, /\/image$/);
  const img = store.readImage(id);
  assert.ok(img?.filePath);
  assert.equal(img.ext, '.jpg');
});

test('billRetrainStore archiveExportedSamples removes images and updates status', () => {
  const id = 'test-archive-1';
  store.upsertSample({ id, status: 'approved', imageExt: '.jpg', imageUrl: '/api/admin/bill-retrain/samples/x/image' });
  store.saveImage(id, Buffer.from('fake'), '.jpg');
  const imgPath = path.join(storePath, 'bill_retrain', 'images', `${id}.jpg`);
  assert.ok(fs.existsSync(imgPath));

  const result = store.archiveExportedSamples([id], 'batch-test-1');
  assert.equal(result.archivedImages, 1);
  assert.equal(result.batchId, 'batch-test-1');
  assert.ok(!fs.existsSync(imgPath));

  const sample = store.getSample(id);
  assert.equal(sample.status, 'exported_archived');
  assert.equal(sample.imageArchived, true);
  assert.equal(sample.exportBatchId, 'batch-test-1');
  assert.equal(sample.imageUrl, null);
  assert.equal(store.readImage(id), null);
  assert.equal(store.approvedForExport().some((s) => s.id === id), false);
});
