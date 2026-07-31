/**
 * tc_ban_unban.js — Kiểm thử W05/W06: Khóa và Mở khóa tài khoản
 * ===============================================================
 * Mục đích:
 *   W05 — Admin khóa tài khoản → User không đăng nhập được
 *   W06 — Admin mở khóa (appeals) → User đăng nhập lại được
 *
 * Yêu cầu:
 *   - Backend đang chạy tại BASE_URL
 *   - ADMIN_EMAIL/ADMIN_PASSWORD có quyền admin
 *   - TARGET_EMAIL là tài khoản test có thể bị ban/unban
 *
 * Chạy lệnh:
 *   cd d:\Luan-Van\Project\tests_chuong4
 *   node tc_ban_unban.js
 *
 * Kết quả: ghi vào tests_chuong4/results/tc_ban_unban_result.md
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

const BASE_URL      = 'http://localhost:4000';
const ADMIN_EMAIL   = 'admin@spendingdiary.app'; // Thay bằng email admin thật
const ADMIN_PASS    = 'Admin@123456';              // Thay bằng mật khẩu admin thật
const TARGET_EMAIL  = 'demo@money.local';          // User bị test ban/unban
const TARGET_PASS   = 'demo1234';

const RESULT_DIR = path.join(__dirname, 'results');
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
  console.log('TC-W05/W06 — Kiểm thử Ban / Unban tài khoản');
  console.log(`Base URL: ${BASE_URL}`);
  console.log('='.repeat(65));

  const results = [];

  // ── Bước 1: Đăng nhập Admin ──────────────────────────────────────────────
  let adminJwt = null;
  let targetUserId = null;

  console.log('\n[B1] Đăng nhập Admin...');
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASS,
    });
    adminJwt = res.data?.data?.accessToken;
    const isAdmin = res.data?.data?.user?.role === 'admin' || !!adminJwt;
    console.log(`  Status: ${res.status} | Admin JWT: ${adminJwt ? '✅' : '❌'}`);
    if (!adminJwt) {
      results.push({ id: 'W05/PRE', name: 'Đăng nhập Admin', pass: false, note: 'Không lấy được JWT admin. Kiểm tra ADMIN_EMAIL/ADMIN_PASS.' });
      return writeResult(results);
    }
  } catch (e) {
    console.log(`  ❌ Lỗi kết nối: ${e.message}`);
    results.push({ id: 'W05/PRE', name: 'Kết nối Backend', pass: false, note: e.message });
    return writeResult(results);
  }

  // ── Bước 2: Tìm userId của TARGET_EMAIL ─────────────────────────────────
  console.log(`\n[B2] Tìm userId của ${TARGET_EMAIL}...`);
  try {
    const res = await request('GET', `${BASE_URL}/api/v1/admin/users?search=${encodeURIComponent(TARGET_EMAIL)}&pageSize=5`, null, {
      Authorization: `Bearer ${adminJwt}`,
    });
    const users = res.data?.data?.users || res.data?.data || [];
    const target = users.find(u => u.email === TARGET_EMAIL) || users[0];
    targetUserId = target?.id;
    console.log(`  Status: ${res.status} | userId: ${targetUserId || '❌ không tìm thấy'}`);
    if (!targetUserId) {
      results.push({ id: 'W05/PRE', name: `Tìm user ${TARGET_EMAIL}`, pass: false, note: 'Không tìm thấy userId. Kiểm tra TARGET_EMAIL.' });
      return writeResult(results);
    }
  } catch (e) {
    console.log(`  ❌ ${e.message}`);
    results.push({ id: 'W05/PRE', name: 'Lấy danh sách users', pass: false, note: e.message });
    return writeResult(results);
  }

  // ── Bước 3 (TC-W05): Admin ban tài khoản ───────────────────────────────
  console.log(`\n[W05] Admin khóa userId: ${targetUserId}...`);
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/admin/users/${targetUserId}/ban`, {
      reason: '[TEST] Kiểm thử chức năng ban/unban - sẽ unban ngay sau',
    }, { Authorization: `Bearer ${adminJwt}` });
    const pass = res.status === 200 || res.status === 204;
    console.log(`  Status: ${res.status} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'W05-BAN', name: 'Admin khóa tài khoản user', status: res.status, pass, note: `userId=${targetUserId}` });
  } catch (e) {
    results.push({ id: 'W05-BAN', name: 'Admin khóa tài khoản', pass: false, note: e.message });
  }

  await sleep(500);

  // ── Bước 4: User thử đăng nhập → phải bị từ chối ──────────────────────
  console.log(`\n[W05] User thử đăng nhập sau khi bị ban...`);
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: TARGET_EMAIL,
      password: TARGET_PASS,
    });
    // Mong đợi: 401 hoặc 403 (tài khoản bị khóa)
    const pass = res.status === 401 || res.status === 403;
    const msg = res.data?.message || res.data?.error || '';
    console.log(`  Status: ${res.status} | Message: ${msg} | ${pass ? '✅ PASS — bị chặn đúng' : '❌ FAIL — vẫn đăng nhập được'}`);
    results.push({
      id: 'W05-LOGIN',
      name: 'User đăng nhập sau khi bị ban → bị từ chối',
      status: res.status,
      pass,
      note: `Status: ${res.status}, Msg: "${msg}"`,
    });
  } catch (e) {
    results.push({ id: 'W05-LOGIN', name: 'User đăng nhập khi bị ban', pass: false, note: e.message });
  }

  // ── Bước 5 (TC-W06): Admin mở khóa (Unban / Appeals) ──────────────────
  console.log(`\n[W06] Admin mở khóa userId: ${targetUserId}...`);
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/admin/users/${targetUserId}/unban`, {}, {
      Authorization: `Bearer ${adminJwt}`,
    });
    const pass = res.status === 200 || res.status === 204;
    console.log(`  Status: ${res.status} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({ id: 'W06-UNBAN', name: 'Admin mở khóa tài khoản (Appeals)', status: res.status, pass, note: `userId=${targetUserId}` });
  } catch (e) {
    results.push({ id: 'W06-UNBAN', name: 'Admin mở khóa tài khoản', pass: false, note: e.message });
  }

  await sleep(500);

  // ── Bước 6: User thử đăng nhập lại → phải thành công ──────────────────
  console.log(`\n[W06] User thử đăng nhập sau khi được mở khóa...`);
  try {
    const res = await request('POST', `${BASE_URL}/api/v1/auth/login`, {
      email: TARGET_EMAIL,
      password: TARGET_PASS,
    });
    const pass = res.status === 200 && !!res.data?.data?.accessToken;
    console.log(`  Status: ${res.status} | Token: ${res.data?.data?.accessToken ? '✅' : '❌'} | ${pass ? '✅ PASS' : '❌ FAIL'}`);
    results.push({
      id: 'W06-LOGIN',
      name: 'User đăng nhập thành công sau khi được mở khóa',
      status: res.status,
      pass,
      note: `Status: ${res.status}`,
    });
  } catch (e) {
    results.push({ id: 'W06-LOGIN', name: 'User đăng nhập sau unban', pass: false, note: e.message });
  }

  await writeResult(results);
}

async function writeResult(results) {
  const now = new Date().toLocaleString('vi-VN');
  const passCount = results.filter(r => r.pass).length;
  const total = results.length;

  let md = `# TC-W05/W06 — Kết quả Kiểm thử Ban / Unban Tài khoản\n`;
  md += `**Thời gian:** ${now}  \n`;
  md += `**Base URL:** \`${BASE_URL}\`  \n\n---\n\n`;
  md += `## Tổng quan\n\n| Chỉ số | Giá trị |\n|--------|--------|\n`;
  md += `| Test cases | ${total} |\n| PASS | ${passCount} |\n| FAIL | ${total - passCount} |\n\n---\n\n`;
  md += `## Kịch bản kiểm thử\n\n`;
  md += `1. Admin đăng nhập lấy JWT quyền quản trị.\n`;
  md += `2. Admin tìm userId của user cần test.\n`;
  md += `3. **TC-W05:** Admin gọi API \`POST /admin/users/:id/ban\` → User thử đăng nhập → phải bị từ chối (HTTP 403).\n`;
  md += `4. **TC-W06:** Admin gọi API \`POST /admin/users/:id/unban\` → User thử đăng nhập lại → phải thành công (HTTP 200).\n\n---\n\n`;
  md += `## Bảng kết quả\n\n`;
  md += `| Mã | Tên kiểm thử | HTTP | Kết quả | Ghi chú |\n`;
  md += `|----|-------------|------|---------|--------|\n`;
  for (const r of results) {
    const icon = r.pass ? '✅' : '❌';
    md += `| ${r.id} | ${r.name} | ${r.status || '-'} | ${icon} ${r.pass ? 'PASS' : 'FAIL'} | ${r.note || ''} |\n`;
  }

  const outpath = path.join(__dirname, 'results', 'tc_ban_unban_result.md');
  fs.writeFileSync(outpath, md, 'utf8');
  console.log(`\n${'='.repeat(65)}`);
  console.log(`✅ Đã xuất kết quả: ${outpath}`);
  console.log(`Tổng: ${passCount}/${total} PASS`);
}

main().catch(console.error);
