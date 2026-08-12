# Hướng dẫn chi tiết Test Push Notification bằng Postman

Tài liệu này cung cấp các endpoint chính xác và cấu hình cụ thể trên Postman để bạn kích hoạt luồng **Cảnh báo Lạm chi Ngân sách**, qua đó kiểm chứng hệ thống Push Notification (FCM) hoạt động hoàn hảo khi ứng dụng đang tắt ngầm.

---

## 🛠 Điều kiện chuẩn bị trước khi test
1. Đảm bảo Backend Node.js đang chạy (đang ở port `4000`).
2. Mở ứng dụng điện thoại, đăng nhập vào tài khoản của bạn.
3. Vào mục **Ngân sách (Budget)**, cài đặt một hạn mức cho tháng này (Ví dụ: `5,000,000 VNĐ`).
4. **Quan trọng nhất:** Tắt hẳn ứng dụng hoặc thu nhỏ xuống background, khóa màn hình điện thoại lại.

---

## Bước 1: Đăng nhập để lấy JWT Token

- **Method:** `POST`
- **URL:** `http://localhost:4000/api/v1/auth/login`
- **Headers:** 
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
  ```json
  {
    "email": "demo@money.local",
    "password": "demo1234"
  }
  ```
- **Thao tác:** 
  Nhấn **Send**. Trong ô kết quả (Response) trả về, bạn hãy copy đoạn chuỗi dài thòong lọng nằm trong trường `"accessToken"`.

---

## Bước 2: Lấy ID Ví của bạn (Wallet ID)

- **Method:** `GET`
- **URL:** `http://localhost:4000/api/v1/wallets`
- **Headers:**
  - `Authorization`: `Bearer [Dán_chuỗi_Token_vừa_copy_ở_Bước_1_vào_đây]`
- **Thao tác:** 
  Nhấn **Send**. Trong mảng `data` trả về, tìm ví chính của bạn và copy mã `"id"` (Nó là một chuỗi UUID, ví dụ: `d290f1ee-6c54-4b01-90e6-d701748f0851`).

---

## Bước 3: Gọi API Thêm Giao Dịch (Kích hoạt Push Notification)

Đây là cú "chốt hạ". Chúng ta sẽ cố tình thêm một khoản chi tiêu cực lớn (Ví dụ: 10 triệu) để ép hệ thống nhận diện lạm chi và tự động kích hoạt Push Notification.

- **Method:** `POST`
- **URL:** `http://localhost:4000/api/v1/transactions`
- **Headers:**
  - `Content-Type`: `application/json`
  - `Authorization`: `Bearer [Dán_chuỗi_Token_vừa_copy_ở_Bước_1_vào_đây]`
- **Body (raw JSON):**
  ```json
  {
    "walletId": "dán_ID_ví_của_bạn_vào_đây_ví_dụ_123e4567-e89b-12d3...",
    "amount": 10000000, 
    "type": "expense",
    "categoryCode": "Food",
    "note": "Test ép lạm chi từ Postman",
    "occurredAt": "2026-08-10T12:00:00Z",
    "source": "manual"
  }
  ```

---

## 🎉 Bước 4: Tận hưởng kết quả
1. Nhấn nút **Send** ở Bước 3. Postman sẽ trả về `HTTP 200 OK` (Báo thêm giao dịch thành công).
2. Chưa đầy 1-2 giây sau, **điện thoại của bạn sẽ lập tức sáng màn hình, rung và đổ chuông** kèm theo một thông báo (Banner) cảnh báo lạm chi. 
3. *Chúc mừng bạn! Chu trình End-to-End từ Client (Postman) -> Máy chủ (Node.js) -> Đám mây (Firebase) -> Thiết bị cuối (Điện thoại) đã hoạt động xuất sắc!*
