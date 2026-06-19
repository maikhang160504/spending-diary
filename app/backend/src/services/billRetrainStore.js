'use strict';

const fs = require('fs');
const path = require('path');

const env = require('../config/env');
const logger = require('../config/logger');

const STORAGE_ROOT = process.env.BILL_RETRAIN_TEST
  ? path.join(process.env.BILL_RETRAIN_TEST, 'bill_retrain')
  : path.join(env.rootDir, 'storage', 'bill_retrain');
const INDEX_PATH = path.join(STORAGE_ROOT, 'samples_index.json');
const IMAGES_DIR = path.join(STORAGE_ROOT, 'images');

function ensureStorage() {
  if (!fs.existsSync(STORAGE_ROOT)) {
    fs.mkdirSync(STORAGE_ROOT, { recursive: true });
  }
  if (!fs.existsSync(IMAGES_DIR)) {
    fs.mkdirSync(IMAGES_DIR, { recursive: true });
  }
  if (!fs.existsSync(INDEX_PATH)) {
    fs.writeFileSync(INDEX_PATH, JSON.stringify({ samples: [] }, null, 2), 'utf8');
  }
}

function imagePathFor(id, ext = '.jpg') {
  const safeExt = ext.startsWith('.') ? ext : `.${ext}`;
  return path.join(IMAGES_DIR, `${id}${safeExt}`);
}

function saveImage(id, buffer, ext = '.jpg') {
  ensureStorage();
  const filePath = imagePathFor(id, ext);
  fs.writeFileSync(filePath, buffer);
  return `/api/admin/bill-retrain/samples/${id}/image`;
}

function readImage(id) {
  const sample = getSample(id);
  if (!sample?.imageExt) return null;
  const filePath = imagePathFor(id, sample.imageExt);
  if (!fs.existsSync(filePath)) return null;
  return { filePath, ext: sample.imageExt };
}

function readIndex() {
  ensureStorage();
  return JSON.parse(fs.readFileSync(INDEX_PATH, 'utf8'));
}

function writeIndex(data) {
  ensureStorage();
  fs.writeFileSync(INDEX_PATH, JSON.stringify(data, null, 2), 'utf8');
}

function listSamples(status) {
  const idx = readIndex();
  let rows = idx.samples || [];
  if (status) rows = rows.filter((s) => s.status === status);
  return rows.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

function getSample(id) {
  return listSamples().find((s) => s.id === id) || null;
}

function upsertSample(sample) {
  const idx = readIndex();
  const rows = idx.samples || [];
  const i = rows.findIndex((s) => s.id === sample.id);
  if (i >= 0) rows[i] = { ...rows[i], ...sample, updatedAt: new Date().toISOString() };
  else rows.unshift({ ...sample, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
  idx.samples = rows;
  writeIndex(idx);
  return sample;
}

function approveSample(id, adminLabels, reviewedBy) {
  const sample = getSample(id);
  if (!sample) return null;
  return upsertSample({
    ...sample,
    status: 'approved',
    adminLabels,
    reviewedBy,
    reviewedAt: new Date().toISOString(),
  });
}

function sampleStats() {
  const all = listSamples();
  const approved = all.filter((s) => s.status === 'approved');
  const withImage = approved.filter((s) => readImage(s.id)).length;
  return {
    total: all.length,
    pending: all.filter((s) => s.status === 'pending').length,
    approved: approved.length,
    approvedWithImage: withImage,
  };
}

function deleteSample(id) {
  const sample = getSample(id);
  if (!sample) return null;

  const ext = sample.imageExt || '.jpg';
  const filePath = imagePathFor(id, ext);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }

  const idx = readIndex();
  idx.samples = (idx.samples || []).filter((s) => s.id !== id);
  writeIndex(idx);
  return sample;
}

function approvedForExport() {
  return listSamples('approved').map((s) => {
    const img = readImage(s.id);
    return {
      id: s.id,
      admin_labels: s.adminLabels || s.autoLabels?.boxes || [],
      image_url: s.imageUrl,
      image_path: img?.filePath || null,
      image_ext: s.imageExt || null,
      metadata: s.metadata || {},
    };
  });
}

function archiveExportedSamples(sampleIds, batchId) {
  if (!Array.isArray(sampleIds) || !sampleIds.length) {
    return { archivedImages: 0, batchId: batchId || null, sampleIds: [] };
  }
  const idx = readIndex();
  const now = new Date().toISOString();
  const exportBatchId = batchId || now;
  let archivedImages = 0;
  const archivedIds = [];

  for (const id of sampleIds) {
    const rows = idx.samples || [];
    const i = rows.findIndex((s) => s.id === id);
    if (i < 0) continue;
    const sample = rows[i];
    const ext = sample.imageExt || '.jpg';
    const filePath = imagePathFor(id, ext);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      archivedImages += 1;
    }
    rows[i] = {
      ...sample,
      status: 'exported_archived',
      exportedAt: now,
      exportBatchId,
      imageArchived: true,
      imageUrl: null,
      updatedAt: now,
    };
    archivedIds.push(id);
  }

  idx.samples = idx.samples || [];
  writeIndex(idx);
  logger.info('Archived %d bill retrain images (batch %s)', archivedImages, exportBatchId);
  return { archivedImages, batchId: exportBatchId, sampleIds: archivedIds };
}

module.exports = {
  STORAGE_ROOT,
  IMAGES_DIR,
  listSamples,
  getSample,
  upsertSample,
  approveSample,
  deleteSample,
  approvedForExport,
  archiveExportedSamples,
  sampleStats,
  saveImage,
  readImage,
};
