'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

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
  expect(fs.existsSync(imgPath)).toBe(true);
  const removed = store.deleteSample(id);
  expect(removed).toBeTruthy();
  expect(store.getSample(id)).toBeNull();
  expect(store.readImage(id)).toBeNull();
  expect(fs.existsSync(imgPath)).toBe(false);
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
  expect(listed.some((s) => s.id === id)).toBe(true);
  const approved = store.approveSample(id, [{ text: 'WINMART', entity: 'SELLER' }], 'admin');
  expect(approved.status).toBe('approved');
  const exportRows = store.approvedForExport();
  expect(exportRows.length).toBeGreaterThanOrEqual(1);
});

test('billRetrainStore saveImage and readImage', () => {
  const id = 'test-image-1';
  store.upsertSample({ id, status: 'pending', imageExt: '.jpg' });
  const url = store.saveImage(id, Buffer.from('fake-image'), '.jpg');
  expect(url).toMatch(/\/image$/);
  const img = store.readImage(id);
  expect(img?.filePath).toBeTruthy();
  expect(img.ext).toBe('.jpg');
});

test('billRetrainStore archiveExportedSamples removes images and updates status', () => {
  const id = 'test-archive-1';
  store.upsertSample({ id, status: 'approved', imageExt: '.jpg', imageUrl: '/api/admin/bill-retrain/samples/x/image' });
  store.saveImage(id, Buffer.from('fake'), '.jpg');
  const imgPath = path.join(storePath, 'bill_retrain', 'images', `${id}.jpg`);
  expect(fs.existsSync(imgPath)).toBe(true);

  const result = store.archiveExportedSamples([id], 'batch-test-1');
  expect(result.archivedImages).toBe(1);
  expect(result.batchId).toBe('batch-test-1');
  expect(fs.existsSync(imgPath)).toBe(false);

  const sample = store.getSample(id);
  expect(sample.status).toBe('exported_archived');
  expect(sample.imageArchived).toBe(true);
  expect(sample.exportBatchId).toBe('batch-test-1');
  expect(sample.imageUrl).toBeNull();
  expect(store.readImage(id)).toBeNull();
  expect(store.approvedForExport().some((s) => s.id === id)).toBe(false);
});
