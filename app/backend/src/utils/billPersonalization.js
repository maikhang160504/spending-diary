'use strict';

const CATEGORY_CODES = new Set([
  'Food', 'Shopping', 'Essentials', 'Transport', 'Housing', 'Entertainment',
  'Health', 'Education', 'Beauty', 'Social', 'Business', 'Bonus', 'Charity',
  'Debt', 'Investment', 'Saving', 'Salary', 'Other', 'Others', 'Income',
]);

const CATEGORY_LABELS = [
  'ăn uống', 'mua sắm', 'đồ dùng thiết yếu', 'di chuyển', 'nhà ở', 'giải trí',
  'sức khỏe', 'giáo dục', 'làm đẹp', 'xã hội', 'kinh doanh', 'thưởng', 'từ thiện',
  'nợ', 'đầu tư', 'tiết kiệm', 'lương', 'khác', 'hoá đơn', 'hóa đơn',
];
const CATEGORY_LABELS_NORM = new Set(
  CATEGORY_LABELS.map((label) => label.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase())
);

const HEADER_SKIP = /hoa don|hóa đơn|tel|website|mst|ma so thue|so gd|thu ngan|xin cam/i;
const SKIP_LINE = /đơn\s*giá|don\s*gia|mã\s*sp|barcode|số\s*gd|so\s*gd|mst|mã\s*số\s*thuế/i;
const TABLE_HEADER = /mat\s*hang|mặt\s*hàng|don\s*gia|đơn\s*giá|\bsl\b|t\.?\s*tien|thanh\s*tien|ttien/i;
const TOTAL_LINE = /cộng\s*tiền|tổng\s*tiền|thanh\s*toán|tien\s*thanh\s*toan|phải\s*t\.?\s*toán|phai\s*t\.?\s*toan/i;
const AMOUNT_ONLY = /^[\d\s.,+\-/%]+$/;
const BARCODE = /^\d{8,}$/;
const QTY_PRICE = /^\s*\d+\s+[\d.,]+\s+[\d.,]+\s*$/;
const HAS_LETTERS = /[a-zA-Zà-ỹÀ-Ỹ]/;

function normalizeForCompare(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

function isInvalidPersonalizationKeyword(text) {
  const raw = String(text || '').trim();
  if (!raw) return true;
  if (raw.length > 100) return true;
  if (raw.includes('\n')) return true;
  const norm = normalizeForCompare(raw);
  if (CATEGORY_CODES.has(raw) || CATEGORY_CODES.has(norm.replace(/\s+/g, ''))) return true;
  if (CATEGORY_LABELS_NORM.has(norm)) return true;
  if (AMOUNT_ONLY.test(raw.replace(/\s/g, ''))) return true;
  return false;
}

function cleanProductLine(line) {
  let s = String(line || '').trim();
  if (!s) return null;
  s = s.replace(/^\s*\d+[\s.\-]+/, '').trim();
  if (s.length < 2 || s.length > 80) return null;
  if (HEADER_SKIP.test(s) || SKIP_LINE.test(s) || TOTAL_LINE.test(s)) return null;
  if (AMOUNT_ONLY.test(s.replace(/\s/g, ''))) return null;
  if (BARCODE.test(s.replace(/\s/g, ''))) return null;
  if (QTY_PRICE.test(s)) return null;
  if (!HAS_LETTERS.test(s)) return null;
  return s;
}

function ocrLines(ocr) {
  if (!ocr || typeof ocr !== 'object') return [];
  if (Array.isArray(ocr.lines)) {
    return ocr.lines
      .map((l) => (typeof l === 'string' ? l : l?.text))
      .filter(Boolean)
      .map((t) => String(t).trim());
  }
  if (typeof ocr.text === 'string' && ocr.text.trim()) {
    return ocr.text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  }
  return [];
}

function extractProductNamesFromLines(lines) {
  const products = [];
  let inTable = false;
  for (const raw of lines) {
    const line = String(raw).trim();
    if (!line) continue;
    if (TABLE_HEADER.test(line)) {
      inTable = true;
      continue;
    }
    if (inTable && TOTAL_LINE.test(line)) break;
    if (!inTable) continue;
    const name = cleanProductLine(line);
    if (name) products.push(name);
  }
  if (products.length) return products;

  const n = lines.length;
  if (n <= 4) return [];
  const start = Math.min(4, Math.max(1, Math.floor(n / 5)));
  const end = Math.max(start + 1, n - Math.max(2, Math.floor(n / 4)));
  for (let i = start; i < end; i += 1) {
    const name = cleanProductLine(lines[i]);
    if (name) products.push(name);
  }
  return products;
}

function resolveKeywordFromOcrPayload(ocr, noteFallback) {
  if (!ocr || typeof ocr !== 'object') return null;

  if (ocr.personalization_keyword && !isInvalidPersonalizationKeyword(ocr.personalization_keyword)) {
    return String(ocr.personalization_keyword).trim();
  }

  if (Array.isArray(ocr.product_names) && ocr.product_names.length) {
    const first = ocr.product_names.find((n) => !isInvalidPersonalizationKeyword(n));
    if (first) return String(first).trim();
  }

  const products = extractProductNamesFromLines(ocrLines(ocr));
  if (products.length) return products[0];

  const seller = ocr.kie_fields?.SELLER || ocr.kie_fields?.seller;
  if (seller && !isInvalidPersonalizationKeyword(seller)) {
    return String(seller).trim();
  }

  if (noteFallback && !isInvalidPersonalizationKeyword(noteFallback)) {
    return String(noteFallback).trim();
  }

  return null;
}

function resolveCategoryCorrectionKeyword(tx) {
  if (!tx) return null;
  const meta = tx.ai_meta || tx.aiMeta || {};
  const source = tx.source;

  if (meta.personalizationKeyword && !isInvalidPersonalizationKeyword(meta.personalizationKeyword)) {
    return String(meta.personalizationKeyword).trim();
  }

  if (source === 'bill' || meta.ocr) {
    const fromOcr = resolveKeywordFromOcrPayload(meta.ocr, tx.note);
    if (fromOcr) return fromOcr;
  }

  const nluText = meta.nlu?.text || meta.nlu?.clean_content;
  if (nluText && !isInvalidPersonalizationKeyword(nluText)) {
    return String(nluText).trim();
  }

  if (tx.note && !isInvalidPersonalizationKeyword(tx.note)) {
    return String(tx.note).trim();
  }

  return null;
}

function isStaleLayer1Rule(keyword, categoryCode) {
  if (isInvalidPersonalizationKeyword(keyword)) return true;
  if (!categoryCode) return false;
  const kw = normalizeForCompare(keyword);
  const cat = normalizeForCompare(categoryCode);
  if (kw === cat) return true;
  return false;
}

async function cleanupInvalidLayer1Rules(queryFn, { dryRun = true } = {}) {
  const res = await queryFn(`
    SELECT user_id AS "userId", keyword, category_code AS "categoryCode", updated_at AS "updatedAt"
    FROM user_category_mappings
    ORDER BY updated_at DESC
  `);
  const invalid = res.rows.filter((row) => isStaleLayer1Rule(row.keyword, row.categoryCode));
  if (dryRun || invalid.length === 0) {
    return { dryRun, removed: 0, invalid, totalScanned: res.rows.length };
  }

  let removed = 0;
  for (const row of invalid) {
    await queryFn(
      'DELETE FROM user_category_mappings WHERE user_id = $1 AND keyword = $2',
      [row.userId, row.keyword]
    );
    await queryFn(
      'DELETE FROM user_corrections WHERE user_id = $1 AND LOWER(TRIM(text)) = LOWER(TRIM($2))',
      [row.userId, row.keyword]
    );
    removed += 1;
  }
  return { dryRun: false, removed, invalid, totalScanned: res.rows.length };
}

module.exports = {
  resolveCategoryCorrectionKeyword,
  resolveKeywordFromOcrPayload,
  isInvalidPersonalizationKeyword,
  isStaleLayer1Rule,
  cleanupInvalidLayer1Rules,
};
