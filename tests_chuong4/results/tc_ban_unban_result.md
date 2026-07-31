# TC-W05/W06 — Kết quả Kiểm thử Ban / Unban Tài khoản
**Thời gian:** 20:24:29 29/7/2026  
**Base URL:** `http://localhost:4000`  

---

## Tổng quan

| Chỉ số | Giá trị |
|--------|--------|
| Test cases | 1 |
| PASS | 0 |
| FAIL | 1 |

---

## Kịch bản kiểm thử

1. Admin đăng nhập lấy JWT quyền quản trị.
2. Admin tìm userId của user cần test.
3. **TC-W05:** Admin gọi API `POST /admin/users/:id/ban` → User thử đăng nhập → phải bị từ chối (HTTP 403).
4. **TC-W06:** Admin gọi API `POST /admin/users/:id/unban` → User thử đăng nhập lại → phải thành công (HTTP 200).

---

## Bảng kết quả

| Mã | Tên kiểm thử | HTTP | Kết quả | Ghi chú |
|----|-------------|------|---------|--------|
| W05/PRE | Đăng nhập Admin | - | ❌ FAIL | Không lấy được JWT admin. Kiểm tra ADMIN_EMAIL/ADMIN_PASS. |
