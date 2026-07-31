/**
 * tc04_backend_api.js — Kiểm thử Backend REST API (DB01, DB02)
 * =============================================================
 * Mục đích:
 *   1. Đăng nhập → lấy JWT
 *   2. Tạo giao dịch chi tiêu
 *   3. Đọc lại danh sách giao dịch → xác minh dữ liệu khớp (DB01)
 *   4. Xác minh số dư ví giảm đúng sau khi tạo giao dịch (DB02)
 *
 * Chạy lệnh:
 *   cd d:\Luan-Van\Project\tests_chuong4
 *   node tc04_backend_api.js
 *
 * Kết quả: ghi vào tests_chuong4/results/tc04_backend_api_result.md
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

// ─── Cấu hình ─────────────────────────────────────────────────────────────────
const BASE_URL = 'http://localhost:4000'; // Đổi thành production URL nếu cần
const TEST_EMAIL    = 'demo@money.local';
const TEST_PASSWORD = 'demo1234';
const RESULT_DIR = path.join(__dirname, 'results');
if (!fs.existsSync(RESULT_DIR)) fs.mkdirSync(RESULT_DIR, { recursive: true });

// ─── Helper: HTTP request wrapper ─────────────────────────────────────────────
function request(method, urlStr, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const isHttps = url.protocol === 'https:';
    const lib = isHttps ? https : http;

    const data = body ? JSON.stringify(body) : undefined;
    const opts = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        ...headers,
      },
    };

    const req = lib.request(opts, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(raw), raw });
        } catch {
          resolve({ status: res.statusCode, data: null, raw });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// ─── Chạy test ─────────────────────────────────────────────────────────────────
async function main() {
  console.log('='.repeat(60));
  console.log('TC04 — Kiểm thử Backend REST API');
  console.log(`Base URL: ${BASE_URL}`);
  console.log('='.repeat(60));

  const results = [];
  let jwt = null;
  let walletId = null;
  let walletBalanceBefore = null;
  let createdTxId = null;
  const testAmount = 75000;

  // ── TC04-01: Đăng nhập ──────────────────────────────────────────────────────
  console.log('\n[TC04-01] Đăng nhập...');
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });
    const pass = res.status === 200 && res.data?.data?.accessToken;
    jwt = res.data?.data?.accessToken;
    console.log(`  Status: ${res.status} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'TC04-01', name: 'Đăng nhập đúng credentials', status: res.status, pass, note: pass ? `JWT nhận được (${jwt?.slice(0,20)}...)` : 'Không có token' });
  } catch (e) {
    console.log(`  ❌ ERROR: ${e.message}`);
    results.push({ id: 'TC04-01', name: 'Đăng nhập', pass: false, note: `Lỗi kết nối: ${e.message}` });
    return writeResult(results, 'Không thể kết nối Backend. Server có đang chạy không?');
  }

  if (!jwt) return writeResult(results, 'Dừng: không có JWT để tiếp tục');

  // ── TC04-02: Lấy danh sách ví ───────────────────────────────────────────────
  console.log('\n[TC04-02] Lấy danh sách ví...');
  try {
    const res = await request('GET', `${BASE_URL}/api/v1/wallets`, null, { Authorization: `Bearer ${jwt}` });
    const wallets = res.data?.data?.wallets || res.data?.data || [];
    walletId = wallets[0]?.id;
    walletBalanceBefore = wallets[0]?.balance ?? wallets[0]?.amount ?? 0;
    const pass = res.status === 200 && walletId;
    console.log(`  Status: ${res.status} | Ví đầu tiên: ${walletId} | Số dư: ${walletBalanceBefore} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'TC04-02', name: 'Lấy danh sách ví', status: res.status, pass, note: `walletId=${walletId}, balance=${walletBalanceBefore}` });
  } catch (e) {
    console.log(`  ❌ ERROR: ${e.message}`);
    results.push({ id: 'TC04-02', name: 'Lấy danh sách ví', pass: false, note: e.message });
  }

  if (!walletId) return writeResult(results, 'Dừng: không có walletId');

  // ── TC04-03: Tạo giao dịch ──────────────────────────────────────────────────
  console.log(`\n[TC04-03] Tạo giao dịch chi ${testAmount}đ...`);
  const idempotencyKey = `test-tc04-${Date.now()}`;
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/transactions`, {
      walletId,
      amount: testAmount,
      type: 'expense',
      categoryCode: 'Food',
      note: '[TEST] TC04 ăn trưa',
      source: 'manual',
    }, {
      Authorization: `Bearer ${jwt}`,
      'Idempotency-Key': idempotencyKey,
    });
    const pass = res.status === 201;
    createdTxId = res.data?.data?.id || res.data?.id;
    console.log(`  Status: ${res.status} | TxID: ${createdTxId} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'TC04-03', name: `Tạo giao dịch chi ${testAmount}đ`, status: res.status, pass, note: `txId=${createdTxId}` });
  } catch (e) {
    console.log(`  ❌ ERROR: ${e.message}`);
    results.push({ id: 'TC04-03', name: 'Tạo giao dịch', pass: false, note: e.message });
  }

  // ── TC04-04: Đọc lại giao dịch vừa tạo (DB01) ──────────────────────────────
  console.log('\n[TC04-04] Đọc lại lịch sử giao dịch (DB01)...');
  try {
    await new Promise(r => setTimeout(r, 500)); // Chờ DB ghi xong
    const res = await request('GET', `${BASE_URL}/api/v1/transactions?walletId=${walletId}&pageSize=5`, null, { Authorization: `Bearer ${jwt}` });
    const txData = res.data?.data;
    const txList = Array.isArray(txData) ? txData : (txData?.items || txData?.transactions || []);
    console.log('  DEBUG txList length:', txList.length, 'first tx id:', txList[0]?.id, 'createdTxId:', createdTxId);
    const found = Array.isArray(txList) ? txList.find(t => t.id === createdTxId || (t.note && t.note.includes('TC04'))) : null;
    const pass = res.status === 200 && !!found;
    console.log(`  Status: ${res.status} | Tìm thấy tx: ${found ? '✅' : '❌'} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'TC04-04', name: 'Đọc lại giao dịch sau khi tạo (DB01)', status: res.status, pass, note: found ? `Tìm thấy txId=${found.id}, amount=${found.amount}` : 'Không tìm thấy giao dịch vừa tạo' });
  } catch (e) {
    console.log(`  ❌ ERROR: ${e.message}`);
    results.push({ id: 'TC04-04', name: 'Đọc lại giao dịch', pass: false, note: e.message });
  }

  // ── TC04-05: Kiểm tra số dư giảm đúng (DB02) ────────────────────────────────
  console.log('\n[TC04-05] Kiểm tra số dư ví sau giao dịch (DB02)...');
  try {
    const res = await request('GET', `${BASE_URL}/api/v1/wallets`, null, { Authorization: `Bearer ${jwt}` });
    const wallets = res.data?.data?.wallets || res.data?.data || [];
    const wallet = wallets.find(w => w.id === walletId) || wallets[0];
    const balanceAfter = wallet?.balance ?? wallet?.amount ?? 0;
    const expectedBalance = walletBalanceBefore - testAmount;
    const pass = res.status === 200 && (balanceAfter === expectedBalance);
    console.log(`  Số dư trước: ${walletBalanceBefore} | Sau: ${balanceAfter} | Mong đợi: ${expectedBalance} | ${pass ? '✅ PASS' : '⚠️ CHECK'}`);
    results.push({
      id: 'TC04-05',
      name: 'Số dư ví giảm đúng sau giao dịch (DB02)',
      status: res.status,
      pass,
      note: `Trước: ${walletBalanceBefore}, Sau: ${balanceAfter}, Kỳ vọng: ${expectedBalance}`
    });
  } catch (e) {
    console.log(`  ❌ ERROR: ${e.message}`);
    results.push({ id: 'TC04-05', name: 'Kiểm tra số dư', pass: false, note: e.message });
  }

  // ── TC04-06: Đăng nhập sai mật khẩu ────────────────────────────────────────
  console.log('\n[TC04-06] Đăng nhập sai mật khẩu...');
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: TEST_EMAIL,
      password: 'SaiMatKhau123!',
    });
    const pass = res.status === 401 || res.status === 400;
    console.log(`  Status: ${res.status} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'TC04-06', name: 'Đăng nhập sai mật khẩu → 401', status: res.status, pass, note: `Mong đợi: 401, Nhận được: ${res.status}` });
  } catch (e) {
    results.push({ id: 'TC04-06', name: 'Đăng nhập sai mật khẩu', pass: false, note: e.message });
  }

  await writeResult(results);
}

// ─── Xuất Markdown ─────────────────────────────────────────────────────────────
async function writeResult(results, extraNote = '') {
  const now = new Date().toLocaleString('vi-VN');
  const passCount = results.filter(r => r.pass).length;
  const total = results.length;

  let md = `# TC04 — Kết quả Kiểm thử Backend REST API\n`;
  md += `**Thời gian chạy:** ${now}  \n`;
  md += `**Base URL:** \`${BASE_URL}\`  \n\n---\n\n`;

  if (extraNote) md += `> ⚠️ **Ghi chú:** ${extraNote}\n\n---\n\n`;

  md += `## Tổng quan\n\n`;
  md += `| Chỉ số | Giá trị |\n|--------|--------|\n`;
  md += `| Số test case | ${total} |\n`;
  md += `| PASS | ${passCount} |\n`;
  md += `| FAIL | ${total - passCount} |\n`;
  md += `| Tỷ lệ Pass | ${total ? (passCount/total*100).toFixed(1) : 0}% |\n\n---\n\n`;

  md += `## Bảng kết quả\n\n`;
  md += `| Mã | Tên kiểm thử | HTTP Status | Kết quả | Ghi chú |\n`;
  md += `|----|-------------|------------|---------|--------|\n`;

  for (const r of results) {
    const icon = r.pass ? '✅' : '❌';
    md += `| ${r.id} | ${r.name} | ${r.status || '-'} | ${icon} ${r.pass ? 'PASS' : 'FAIL'} | ${r.note || ''} |\n`;
  }

  const outpath = path.join(__dirname, 'results', 'tc04_backend_api_result.md');
  fs.writeFileSync(outpath, md, 'utf8');
  console.log(`\n${'='.repeat(60)}`);
  console.log(`✅ Đã xuất kết quả: ${outpath}`);
  console.log(`Tổng: ${passCount}/${total} PASS`);
}

main().catch(console.error);
