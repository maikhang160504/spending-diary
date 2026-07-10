# Thiết kế Hệ thống Kiếm tiền (Monetization & Premium Model)

Tài liệu này phác thảo chiến lược kinh doanh và thiết kế hệ thống kỹ thuật để tạo ra doanh thu từ ứng dụng thông qua mô hình **Freemium + Quảng Cáo (Ads) + Thanh toán VietQR (SePay)**.

---

## 1. Mô hình Phân quyền Người dùng (User Tiers)

Hệ thống chia người dùng thành 2 nhóm với các đặc quyền khác nhau, nhằm bảo vệ tính năng "câu khách" (AI) nhưng vẫn tạo ra sự "khó chịu nhẹ" ở các tiện ích nâng cao để thúc đẩy việc mua gói Premium.

### 1.1. Tài khoản Miễn phí (Free User)
* **Tính năng AI (Cốt lõi):** Được sử dụng thả ga (hoặc giới hạn mức rất cao, VD: 30 lần/ngày) để tạo thói quen và giữ chân người dùng.
* **Giới hạn Tiện ích:**
  * Chỉ được tạo tối đa **2 Ví cá nhân** và **1 Ví nhóm**.
  * Tính cách Mascot (MiMo): Chỉ được dùng tính cách mặc định (Hài hước/Thân thiện).
  * Báo cáo Thống kê: Giới hạn xem dữ liệu trong 3 tháng gần nhất, không hỗ trợ xuất Excel.
* **Trải nghiệm Quảng cáo:** Phải xem quảng cáo (Banner & Interstitial) theo tần suất quy định.

### 1.2. Tài khoản Cao cấp (Premium User)
* **Chi phí:** Mua 1 lần vĩnh viễn (One-time purchase), ví dụ: 49.000đ.
* **Đặc quyền:**
  * **Không bao giờ thấy quảng cáo.**
  * Vô hạn số lượng Ví cá nhân và Ví nhóm.
  * Tùy chỉnh tính cách Mascot (Gắt gỏng, Ngọt ngào, Quản gia,...). App sẽ truyền cờ `verbal_style` tương ứng vào Prompt LLM.
  * Xem toàn bộ thống kê và xuất báo cáo Excel.

---

## 2. Chiến lược Tích hợp Quảng cáo (Google AdMob)

Không lạm dụng quảng cáo để tránh người dùng xóa App. Quảng cáo được chèn một cách khéo léo và không cắt ngang luồng suy nghĩ.

* **Vị trí 1 - Banner Ad (Tĩnh):** Đặt một dải banner mỏng ở sát đáy màn hình Trang Chủ. Tạo dòng tiền thụ động ổn định.
* **Vị trí 2 - Quảng cáo Xen ngang (Interstitial Ads) theo Tần suất:**
  * **Logic:** App Flutter sẽ giữ một biến đếm `actionCount = 0`. Mỗi khi người dùng *thêm thành công* 1 giao dịch (bằng tay, chụp ảnh, hoặc chat AI), biến đếm tăng thêm 1.
  * **Trigger:** Khi `actionCount == 5`, nhảy một quảng cáo xen ngang chiếm toàn màn hình (5 giây).
  * **UX:** Người dùng vừa hoàn thành xong tác vụ (đã cất được tiền vào sổ) nên tâm lý đang thoải mái. Quảng cáo lúc này ít gây ức chế nhất. Sau khi xem/tắt, reset `actionCount = 0`.

---

## 3. Luồng Thanh toán Tự động qua SePay (VietQR)

Sử dụng SePay để nhận thanh toán chuyển khoản ngân hàng tự động, lách mức chiết khấu 30% của Google Play / App Store.

### Kiến trúc Kỹ thuật
1. **User Action:** Tại App, người dùng bấm nút [Nâng cấp Premium - 49K].
2. **Create Order:** App gọi API Node.js `POST /payments/create`. Backend tạo một record trong bảng `payments` (trạng thái `pending`) và sinh ra cú pháp chuyển khoản duy nhất (VD: `MIMO 83921`).
3. **Show QR:** Backend gen mã VietQR trả về App. App hiển thị mã QR cùng hướng dẫn chuyển khoản.
4. **Webhook:** Người dùng dùng App Ngân hàng quét QR thanh toán. Trong vòng 5-10s, SePay nhận biến động số dư và gọi Webhook HTTP POST về Backend Node.js.
5. **Fulfillment:** 
   * Node.js verify Webhook, tìm record payment tương ứng, đổi trạng thái thành `paid`.
   * Cập nhật bảng `users`: `is_premium = true`.
   * Bắn WebSocket về điện thoại người dùng: *"Giao dịch thành công, tài khoản đã được nâng cấp!"*.
   * App lập tức ẩn toàn bộ AdMob và mở khóa tính năng.

---

## 4. Quản lý trên Web Admin Dashboard

Trên hệ thống React Web Admin, các chức năng sau sẽ được xây dựng để Ban quản trị (Admin) theo dõi dòng tiền:

1. **Dashboard Doanh Thu:**
   * Card hiển thị: Tổng doanh thu (Total Revenue), Doanh thu tháng này.
   * Biểu đồ đường (Line chart) theo dõi dòng tiền thanh toán mỗi ngày.
2. **Lịch sử Giao dịch (Payments Log):**
   * Bảng thống kê Real-time các giao dịch SePay đổ về (Thời gian, Số tiền, Nội dung, ID Người nạp).
3. **Quản lý Users:**
   * Trong bảng Users, thêm Badge trạng thái (Vàng 👑 cho Premium, Xám cho Free).
   * Cho phép Admin quyền gạt Toggle cấp/tước Premium thủ công cho một user bất kỳ (dành cho việc xử lý sự cố, tặng code cho bạn bè, hoặc tester).
