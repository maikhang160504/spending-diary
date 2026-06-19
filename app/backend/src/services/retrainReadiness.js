'use strict';

const fs = require('fs');
const path = require('path');

const { query } = require('../config/db');
const env = require('../config/env');
const billRetrainStore = require('./billRetrainStore');

const THRESHOLDS = {
  categoryCorrections: 500,
  ocrKieApproved: 2000,
};

function readinessStatus(current, threshold) {
  const pct = threshold > 0 ? Math.min(100, Math.round((current / threshold) * 100)) : 0;
  let level = 'low';
  if (current >= threshold) level = 'ready';
  else if (pct >= 50) level = 'building';
  return { current, threshold, percent: pct, ready: current >= threshold, level };
}

function readExportedManifestCount() {
  const manifestPath = path.join(
    env.rootDir,
    '..',
    '..',
    'expense-ocr-nlu',
    'OCR',
    'verified_ocr_labels',
    'incremental',
    'manifest.json',
  );
  if (!fs.existsSync(manifestPath)) return { exported: 0, manifestPath: null };
  try {
    const data = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return { exported: data.count || 0, manifestPath };
  } catch {
    return { exported: 0, manifestPath };
  }
}

async function getRetrainReadiness() {
  const bill = billRetrainStore.sampleStats();
  const ocrKie = readinessStatus(bill.approved, THRESHOLDS.ocrKieApproved);
  const exportInfo = readExportedManifestCount();

  let categoryPool = 0;
  let correctionRows = 0;
  try {
    const totalRes = await query('SELECT COUNT(*)::int AS c FROM user_corrections');
    correctionRows = totalRes.rows[0]?.c || 0;
    const poolRes = await query(
      'SELECT COUNT(*)::int AS c FROM user_corrections WHERE category_code IS NOT NULL',
    );
    categoryPool = poolRes.rows[0]?.c || 0;
  } catch {
    categoryPool = 0;
    correctionRows = 0;
  }

  const category = readinessStatus(categoryPool, THRESHOLDS.categoryCorrections);

  const recommendations = [];
  if (bill.pending > 0) {
    recommendations.push(`${bill.pending} bill đang chờ duyệt bbox trên Bill OCR Retrain.`);
  }
  if (!ocrKie.ready && bill.approved > 0) {
    recommendations.push(
      `OCR/KIE: ${bill.approved}/${THRESHOLDS.ocrKieApproved} bill approved — tiếp tục duyệt hoặc export batch nhỏ để thử.`,
    );
  }
  if (ocrKie.ready) {
    recommendations.push('Đủ ngưỡng OCR/KIE — có thể Export + Kaggle retrain (LayoutLMv3 / VietOCR).');
  }
  if (category.ready) {
    recommendations.push('Đủ ngưỡng category — duyệt NLU curation và retrain category model.');
  } else if (categoryPool > 0) {
    recommendations.push(
      `Category: ${categoryPool}/${THRESHOLDS.categoryCorrections} user corrections — gom thêm trước retrain.`,
    );
  }
  if (bill.approved > 0 && exportInfo.exported === 0) {
    recommendations.push('Có bill approved nhưng chưa export — bấm Export approved trên /bill-retrain.');
  }

  return {
    thresholds: THRESHOLDS,
    billOcr: {
      ...bill,
      ...ocrKie,
      exported: exportInfo.exported,
    },
    category: {
      correctionRows,
      curatedPool: categoryPool,
      ...category,
    },
    anyReady: ocrKie.ready || category.ready,
    recommendations,
    updatedAt: new Date().toISOString(),
  };
}

module.exports = {
  THRESHOLDS,
  getRetrainReadiness,
};
