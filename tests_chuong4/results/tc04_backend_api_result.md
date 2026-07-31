# TC04 — Kết quả Kiểm thử Backend REST API
**Thời gian chạy:** 20:31:04 29/7/2026  
**Base URL:** `http://localhost:4000`  

---

## Tổng quan

| Chỉ số | Giá trị |
|--------|--------|
| Số test case | 6 |
| PASS | 6 |
| FAIL | 0 |
| Tỷ lệ Pass | 100.0% |

---

## Bảng kết quả

| Mã | Tên kiểm thử | HTTP Status | Kết quả | Ghi chú |
|----|-------------|------------|---------|--------|
| TC04-01 | Đăng nhập đúng credentials | 200 | ✅ PASS | JWT nhận được (eyJhbGciOiJIUzI1NiIs...) |
| TC04-02 | Lấy danh sách ví | 200 | ✅ PASS | walletId=c5d72d98-67b5-4bff-b4e1-201feecc9e68, balance=400000 |
| TC04-03 | Tạo giao dịch chi 75000đ | 201 | ✅ PASS | txId=347b983e-1a56-47eb-bb0e-cdbb9e714201 |
| TC04-04 | Đọc lại giao dịch sau khi tạo (DB01) | 200 | ✅ PASS | Tìm thấy txId=347b983e-1a56-47eb-bb0e-cdbb9e714201, amount=75000 |
| TC04-05 | Số dư ví giảm đúng sau giao dịch (DB02) | 200 | ✅ PASS | Trước: 400000, Sau: 325000, Kỳ vọng: 325000 |
| TC04-06 | Đăng nhập sai mật khẩu → 401 | 401 | ✅ PASS | Mong đợi: 401, Nhận được: 401 |
