'use strict';

const fs = require('fs');
const path = require('path');

const { query } = require('../config/db');
const env = require('../config/env');
const billRetrainStore = require('./billRetrainStore');

const THRESHOLDS = {
  totalTransactions: 10000,   // NLU: khi CSDL đạt 10,000 giao dịch
  ocrScanned: 1000,           // OCR: khi đã quét được 1,000 ảnh hóa đơn
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
  const exportInfo = readExportedManifestCount();

  // OCR: đếm tổng ảnh hóa đơn đã quét (approved + pending)
  const totalScanned = (bill.approved || 0) + (bill.pending || 0);
  const ocrKie = readinessStatus(totalScanned, THRESHOLDS.ocrScanned);

  // NLU: đếm tổng số giao dịch trong CSDL (thay vì user corrections)
  let totalTransactions = 0;
  let correctionRows = 0;
  try {
    const txRes = await query('SELECT COUNT(*)::int AS c FROM transactions');
    totalTransactions = txRes.rows[0]?.c || 0;
    const corrRes = await query('SELECT COUNT(*)::int AS c FROM user_corrections');
    correctionRows = corrRes.rows[0]?.c || 0;
  } catch {
    totalTransactions = 0;
    correctionRows = 0;
  }

  const nlu = readinessStatus(totalTransactions, THRESHOLDS.totalTransactions);

  // Cả hai mô hình chỉ ready khi đạt được CẢ HAI điều kiện (10k NLU & 1k OCR)
  const isGlobalReady = (totalTransactions >= THRESHOLDS.totalTransactions) && (totalScanned >= THRESHOLDS.ocrScanned);
  
  if (!isGlobalReady) {
    if (ocrKie.ready) {
      ocrKie.ready = false;
      ocrKie.level = 'building';
    }
    if (nlu.ready) {
      nlu.ready = false;
      nlu.level = 'building';
    }
  }

  const recommendations = [];
  if (bill.pending > 0) {
    recommendations.push(`${bill.pending} bill đang chờ duyệt bbox trên Bill OCR Retrain.`);
  }
  if (!ocrKie.ready && totalScanned > 0) {
    recommendations.push(
      `OCR: ${totalScanned}/${THRESHOLDS.ocrScanned} ảnh hóa đơn đã quét — tiếp tục duyệt để đủ ngưỡng retrain.`,
    );
  }
  if (ocrKie.ready) {
    recommendations.push('Đủ ngưỡng OCR — có thể Export + Kaggle retrain mô hình nhận diện hóa đơn.');
  }
  if (nlu.ready) {
    recommendations.push('Đủ ngưỡng NLU — CSDL đã có 10,000 giao dịch, sẵn sàng retrain mô hình phân loại.');
  } else if (totalTransactions > 0) {
    recommendations.push(
      `NLU: ${totalTransactions}/${THRESHOLDS.totalTransactions} giao dịch — cần thêm dữ liệu trước khi retrain.`,
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
      scanned: totalScanned,
      exported: exportInfo.exported,
    },
    // Giữ field 'category' cho backward-compat với frontend (map sang nlu)
    category: {
      correctionRows,
      curatedPool: totalTransactions,
      ...nlu,
    },
    anyReady: ocrKie.ready && nlu.ready,
    recommendations,
    updatedAt: new Date().toISOString(),
  };
}

module.exports = {
  THRESHOLDS,
  getRetrainReadiness,
};
