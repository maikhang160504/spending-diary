# TC — Kết quả Kiểm thử Idempotency & Rate Limit
**Thời gian chạy:** 20:23:44 29/7/2026  
**Base URL:** `http://localhost:4000`  

---

## Tổng quan

| Chỉ số | Giá trị |
|--------|--------|
| Số test | 1 |
| PASS | 0 |
| FAIL | 1 |

---

## Phần 1 — Idempotency Guard (NFR05 / DB03)

> **Kịch bản:** Gửi 10 POST request tạo giao dịch với cùng một `Idempotency-Key` (khoảng cách 50ms/lần, mô phỏng người dùng bấm đúp hoặc mạng chậm re-send).  
> **Kết quả mong đợi:** Đúng 1 request nhận `HTTP 201 Created`, 9 request còn lại nhận `HTTP 409 Conflict` — chỉ 1 giao dịch thực tế được ghi vào CSDL.

## Phần 2 — Rate Limit Đăng nhập (NFR01)

> **Kịch bản:** Gửi 12 request đăng nhập liên tiếp với mật khẩu sai (khoảng cách 100ms/lần).  
> **Kết quả mong đợi:** Từ request thứ 6 trở đi, server trả về `HTTP 429 Too Many Requests`.

## Bảng kết quả

| Mã | Tên kiểm thử | Kết quả | Ghi chú |
|----|-------------|---------|--------|
| NFR05 | Idempotency Guard | ❌ FAIL | Server không chạy:  |

---

## Nhận xét

- **Idempotency Guard:** Middleware kiểm tra `Idempotency-Key` trong header.
  - Lần đầu tiên thấy key → xử lý bình thường, lưu kết quả vào cache.
  - Các lần sau → trả ngay kết quả từ cache với HTTP 409, không gọi DB.
  - Đảm bảo dù người dùng bấm gửi N lần, CSDL chỉ có đúng 1 bản ghi.
- **Rate Limit:** Middleware express-rate-limit chặn IP gửi quá nhiều request trong cửa sổ thời gian.
