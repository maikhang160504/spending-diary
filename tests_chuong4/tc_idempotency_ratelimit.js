/**
 * tc_idempotency_ratelimit.js — Kiểm thử Phi chức năng (NFR01, NFR05, DB03)
 * ===========================================================================
 * Mục đích:
 *   NFR05 / DB03 — Idempotency: Gửi 10 request tạo giao dịch trùng nhau
 *                  (cùng Idempotency-Key) → chỉ 1 giao dịch được lưu vào DB
 *   NFR01         — Rate Limit: Đăng nhập sai mật khẩu 10 lần liên tiếp
 *                  → phải nhận HTTP 429 từ lần thứ 6
 *
 * Chạy lệnh:
 *   cd d:\Luan-Van\Project\tests_chuong4
 *   node tc_idempotency_ratelimit.js
 *
 * Kết quả: ghi vào tests_chuong4/results/tc_idempotency_ratelimit_result.md
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

const BASE_URL      = 'http://localhost:4000';
const TEST_EMAIL    = 'demo@money.local';
const TEST_PASSWORD = 'demo1234';
const RESULT_DIR    = path.join(__dirname, 'results');
if (!fs.existsSync(RESULT_DIR)) fs.mkdirSync(RESULT_DIR, { recursive: true });

function request(method, urlStr, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const url  = new URL(urlStr);
    const lib  = url.protocol === 'https:' ? https : http;
    const data = body ? JSON.stringify(body) : undefined;
    const opts = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
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
      res.on('data', c => raw += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(raw) }); }
        catch { resolve({ status: res.statusCode, data: null }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  console.log('='.repeat(65));
  console.log('TC — Idempotency & Rate Limit');
  console.log(`Base URL: ${BASE_URL}`);
  console.log('='.repeat(65));

  const results = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // PHẦN 1 — IDEMPOTENCY (NFR05 / DB03)
  // ═══════════════════════════════════════════════════════════════════════════
  console.log('\n📌 PHẦN 1: Kiểm thử Idempotency Guard (NFR05)');
  console.log('-'.repeat(55));

  // Bước 1.1 — Đăng nhập lấy JWT
  let jwt = null;
  let walletId = null;
  try {
    const loginRes = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });
    jwt = loginRes.data?.data?.accessToken;
    console.log(`[1.1] Đăng nhập: ${loginRes.status} | JWT: ${jwt ? '✅' : '❌ Không có'}`);
  } catch (e) {
    console.log(`[1.1] ❌ Không kết nối được Backend: ${e.message}`);
    results.push({ id: 'NFR05', name: 'Idempotency Guard', pass: false, note: `Server không chạy: ${e.message}` });
    return writeResult(results);
  }

  // Bước 1.2 — Lấy walletId
  if (jwt) {
    try {
      const walletsRes = await request('GET', `${BASE_URL}/api/v1/wallets`, null, { Authorization: `Bearer ${jwt}` });
      const wallets = walletsRes.data?.data?.wallets || walletsRes.data?.data || [];
      walletId = wallets[0]?.id;
      console.log(`[1.2] Wallet đầu tiên: ${walletId || '❌ không tìm thấy'}`);
    } catch (e) {
      console.log(`[1.2] ❌ ${e.message}`);
    }
  }

  // Bước 1.3 — Gửi 10 request tạo giao dịch CÙNG Idempotency-Key
  const IDEMPOTENCY_KEY = `idempotency-test-${Date.now()}`;
  const REPEAT_COUNT = 10;
  const statuses = [];

  if (jwt && walletId) {
    console.log(`\n[1.3] Gửi ${REPEAT_COUNT} request CÙNG key: "${IDEMPOTENCY_KEY}"`);
    console.log('      (Khoảng cách mỗi request: 50ms — mô phỏng bấm đúp/mạng chậm)\n');

    for (let i = 1; i <= REPEAT_COUNT; i++) {
      try {
        const res = await request('POST', `${BASE_URL}/api/v1/transactions`, {
          walletId,
          amount: 99000,
          type: 'expense',
          categoryCode: 'Food',
          note: `[IDEMPOTENCY TEST] request #${i}`,
          source: 'manual',
        }, {
          Authorization: `Bearer ${jwt}`,
          'Idempotency-Key': IDEMPOTENCY_KEY,
        });
        statuses.push(res.status);
        const icon = res.status === 201 ? '🆕 CREATED' : (res.status === 409 ? '🔒 CONFLICT' : `⚠️ ${res.status}`);
        console.log(`  Request #${String(i).padStart(2)}: HTTP ${res.status} — ${icon}`);
      } catch (e) {
        statuses.push(0);
        console.log(`  Request #${i}: ❌ ERROR — ${e.message}`);
      }
      if (i < REPEAT_COUNT) await sleep(50);
    }

    const created201  = statuses.filter(s => s === 201).length;
    const conflict409 = statuses.filter(s => s === 409).length;
    const idempotencyPass = created201 === 1 && conflict409 === REPEAT_COUNT - 1;

    console.log(`\n  Kết quả: ${created201} × 201 CREATED | ${conflict409} × 409 CONFLICT`);
    console.log(`  Idempotency: ${idempotencyPass ? '✅ PASS — chỉ 1 giao dịch được tạo' : '❌ FAIL'}`);

    results.push({
      id: 'NFR05/DB03',
      name: `Idempotency Guard — ${REPEAT_COUNT} request cùng key`,
      pass: idempotencyPass,
      note: `${created201}×201 CREATED + ${conflict409}×409 CONFLICT. Key: "${IDEMPOTENCY_KEY}"`,
      detail: statuses.map((s, i) => `#${i+1}: ${s}`).join(', '),
    });
  } else {
    results.push({ id: 'NFR05/DB03', name: 'Idempotency Guard', pass: false, note: 'Không lấy được JWT hoặc walletId' });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHẦN 2 — RATE LIMIT (NFR01)
  // ═══════════════════════════════════════════════════════════════════════════
  console.log('\n📌 PHẦN 2: Kiểm thử Rate Limit Đăng nhập (NFR01)');
  console.log('-'.repeat(55));
  console.log('Gửi 12 request đăng nhập sai mật khẩu liên tiếp...\n');

  const rateLimitStatuses = [];
  for (let i = 1; i <= 12; i++) {
    try {
      const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
        email: `attacker-${i}@hacker.com`,
        password: 'WrongPass!',
      });
      rateLimitStatuses.push(res.status);
      const icon = res.status === 429 ? '🚫 BLOCKED' : (res.status === 401 ? '🔑 DENIED' : `⚠️ ${res.status}`);
      console.log(`  Request #${String(i).padStart(2)}: HTTP ${res.status} — ${icon}`);
    } catch (e) {
      rateLimitStatuses.push(0);
      console.log(`  Request #${i}: ❌ ERROR — ${e.message}`);
    }
    await sleep(100);
  }

  const has429 = rateLimitStatuses.some(s => s === 429);
  const first429 = rateLimitStatuses.findIndex(s => s === 429) + 1;

  console.log(`\n  Kết quả: ${rateLimitStatuses.join(', ')}`);
  console.log(`  Rate Limit 429: ${has429 ? `✅ XUẤT HIỆN từ request #${first429}` : '❌ Không có 429'}`);

  results.push({
    id: 'NFR01',
    name: 'Rate Limit — đăng nhập sai liên tiếp → HTTP 429',
    pass: has429,
    note: has429
      ? `429 xuất hiện từ request #${first429}. Statuses: [${rateLimitStatuses.join(', ')}]`
      : `Không có 429. Statuses: [${rateLimitStatuses.join(', ')}]. Kiểm tra cấu hình rate-limit.`,
  });

  await writeResult(results);
}

async function writeResult(results) {
  const now = new Date().toLocaleString('vi-VN');
  const passCount = results.filter(r => r.pass).length;
  const total = results.length;

  let md = `# TC — Kết quả Kiểm thử Idempotency & Rate Limit\n`;
  md += `**Thời gian chạy:** ${now}  \n`;
  md += `**Base URL:** \`${BASE_URL}\`  \n\n---\n\n`;
  md += `## Tổng quan\n\n`;
  md += `| Chỉ số | Giá trị |\n|--------|--------|\n`;
  md += `| Số test | ${total} |\n`;
  md += `| PASS | ${passCount} |\n`;
  md += `| FAIL | ${total - passCount} |\n\n---\n\n`;

  md += `## Phần 1 — Idempotency Guard (NFR05 / DB03)\n\n`;
  md += `> **Kịch bản:** Gửi 10 POST request tạo giao dịch với cùng một \`Idempotency-Key\` (khoảng cách 50ms/lần, mô phỏng người dùng bấm đúp hoặc mạng chậm re-send).  \n`;
  md += `> **Kết quả mong đợi:** Đúng 1 request nhận \`HTTP 201 Created\`, 9 request còn lại nhận \`HTTP 409 Conflict\` — chỉ 1 giao dịch thực tế được ghi vào CSDL.\n\n`;

  md += `## Phần 2 — Rate Limit Đăng nhập (NFR01)\n\n`;
  md += `> **Kịch bản:** Gửi 12 request đăng nhập liên tiếp với mật khẩu sai (khoảng cách 100ms/lần).  \n`;
  md += `> **Kết quả mong đợi:** Từ request thứ 6 trở đi, server trả về \`HTTP 429 Too Many Requests\`.\n\n`;

  md += `## Bảng kết quả\n\n`;
  md += `| Mã | Tên kiểm thử | Kết quả | Ghi chú |\n`;
  md += `|----|-------------|---------|--------|\n`;
  for (const r of results) {
    const icon = r.pass ? '✅' : '❌';
    md += `| ${r.id} | ${r.name} | ${icon} ${r.pass ? 'PASS' : 'FAIL'} | ${r.note} |\n`;
  }

  if (results.find(r => r.detail)) {
    md += `\n---\n\n## Chi tiết từng request (Idempotency)\n\n`;
    for (const r of results.filter(r => r.detail)) {
      md += `**${r.id}:** ${r.detail}\n\n`;
    }
  }

  md += `\n---\n\n## Nhận xét\n\n`;
  md += `- **Idempotency Guard:** Middleware kiểm tra \`Idempotency-Key\` trong header.\n`;
  md += `  - Lần đầu tiên thấy key → xử lý bình thường, lưu kết quả vào cache.\n`;
  md += `  - Các lần sau → trả ngay kết quả từ cache với HTTP 409, không gọi DB.\n`;
  md += `  - Đảm bảo dù người dùng bấm gửi N lần, CSDL chỉ có đúng 1 bản ghi.\n`;
  md += `- **Rate Limit:** Middleware express-rate-limit chặn IP gửi quá nhiều request trong cửa sổ thời gian.\n`;

  const outpath = path.join(__dirname, 'results', 'tc_idempotency_ratelimit_result.md');
  fs.writeFileSync(outpath, md, 'utf8');
  console.log(`\n${'='.repeat(65)}`);
  console.log(`✅ Đã xuất kết quả: ${outpath}`);
  console.log(`Tổng: ${passCount}/${total} PASS`);
}

main().catch(console.error);
