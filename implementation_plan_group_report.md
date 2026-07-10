# Kế hoạch Phân tách Báo cáo Cá Nhân và Ví Nhóm (Group Analytics)

Tài liệu này vạch ra kế hoạch kiến trúc và triển khai nhằm tách biệt hoàn toàn Trung tâm Báo cáo Cá Nhân (hiện tại) và Hệ thống Thống kê dành riêng cho Ví Nhóm (Group Wallet Analytics).

> [!IMPORTANT]
> Báo cáo cá nhân tập trung vào **Sự tăng trưởng tài sản (Net worth & Savings)**. 
> Báo cáo nhóm tập trung vào **Quản lý ngân sách sự kiện & Quyết toán (Split Bill)**.

## User Review Required

1. **Tính năng Quyết toán (Split Bill)**: Chức năng này yêu cầu bảng `transactions` phải có thêm cơ chế lưu trữ ai là người trả tiền (Paid By) và ai là người thụ hưởng (Split Among). Hiện tại bảng `transactions` có hỗ trợ việc này chưa? Nếu chưa, chúng ta sẽ cần thay đổi Database schema.
2. **Tab Báo Cáo Nhóm**: Bạn muốn đặt nó là một màn hình tách biệt hoàn toàn khi ấn từ màn hình Chi tiết Ví Nhóm, hay là một Tab dạng vuốt ngang (Swipe Tab) nằm ngay trong Chi tiết Ví Nhóm?

## Proposed Changes

### 1. Kiến trúc Dữ liệu (Database Schema)

### 2. Frontend Mobile - Tách biệt UI & Đồng bộ Components

#### [NEW/MODIFY] Tái cấu trúc & Đồng bộ UI (Sync Components)
- **Vấn đề:** Hiện tại `home_screen.dart` và `share_wallet_screen.dart` đang lặp lại rất nhiều code (khoảng 1000+ dòng) cho các thành phần Header, CardStory, Calendar, Gallery, Segment Tabs.
- **Giải pháp:** Tách các thành phần này ra thư mục `lib/widgets/` dùng chung:
  - `transaction_story_card.dart`
  - `story_gallery_card.dart`
  - `inline_calendar_view.dart`
- Tái sử dụng các widgets này cho cả màn hình Home (Cá nhân) và Share (Ví chung), giúp code tinh gọn và đồng bộ giao diện 100%.

#### [MODIFY] `app/frontend/mobile/lib/screens/wallet/share_wallet_screen.dart`
- Áp dụng các widgets dùng chung đã tạo ở trên để rút gọn file.
- Thay thế nút FAB hiện tại bằng **Radial Menu FAB (Nút đa chức năng dạng vòng cung)** ở góc dưới phải.
- Áp dụng toán học tọa độ cực: $X = -R \times \cos(\theta)$, $Y = -R \times \sin(\theta)$ với $R \approx 90\text{px}$.
- **4 nút chức năng theo góc bung:**
  1. **90° (Trên cùng):** Chat (Vị trí dễ bấm nhất).
  2. **60°:** Quét Bill (Scan Bill).
  3. **30°:** Thêm Ảnh (Photo).
  4. **0° (Trái cùng):** Báo cáo & Thống kê (Group Analytics).
- **Label:** Sử dụng dạng Tooltip.

#### [NEW] `app/frontend/mobile/lib/screens/group/group_analytics_screen.dart`
Màn hình Dashboard chuyên dụng cho ví nhóm, bao gồm 4 phần:
1. **Tổng quan Quỹ (Fund Overview)**: Thanh Progress Bar hiển thị Tổng thu (tiền đóng quỹ) vs Tổng chi vs Còn lại.
2. **Chi tiêu Danh mục (Category Pie Chart)**: Tái sử dụng logic biểu đồ tròn từ `category_spending_report_screen.dart` nhưng truyền cứng `walletId` của nhóm.
3. **Báo cáo Quyết toán (Split & Settlement)**: Hiển thị danh sách thành viên, số tiền đã đóng, số tiền đã tiêu lẹm, và Gợi ý chuyển tiền (AI Smart Settlement).
4. **Dòng thời gian (Activity Timeline)**: Bar chart hiển thị tốc độ đốt tiền theo từng ngày (burn rate by day).

### 3. Backend API - API Thống kê Nhóm

#### [NEW] `app/backend/src/modules/group/group_stats.controller.js` & `group_stats.service.js`
- `GET /api/groups/:walletId/overview`: Lấy tổng thu, tổng chi.
- `GET /api/groups/:walletId/categories`: Lấy chi tiêu theo danh mục.
- `GET /api/groups/:walletId/settlement`: Tính toán thuật toán quyết toán (Ai nợ ai bao nhiêu tiền) dựa trên các giao dịch.
- `GET /api/groups/:walletId/timeline`: Lấy chi tiêu nhóm theo ngày.

### 4. Tích hợp AI MiMo cho Nhóm

#### [MODIFY] `app/backend/src/modules/ai/ai.service.js`
- Viết thêm Prompt chuyên dụng cho Group Analytics. Thay vì khuyên tiết kiệm, AI sẽ cảnh báo tốc độ tiêu tiền của nhóm so với số quỹ còn lại (Ví dụ: "Quỹ chỉ còn 20%, các bạn nên hạn chế ăn uống sang trọng trong 2 ngày cuối").

## Verification Plan

### Automated Tests
- Kiểm thử API `/api/groups/:walletId/settlement` để đảm bảo thuật toán tính toán chia tiền (Split bill) ra kết quả cân bằng (tổng nợ = tổng thu).

### Manual Verification
- Tạo một ví nhóm với 3 người dùng giả lập.
- Nhập 5 giao dịch (trong đó A trả 3 giao dịch, B trả 2 giao dịch).
- Mở màn hình `GroupAnalyticsScreen` và kiểm tra xem thanh Ngân sách, Biểu đồ danh mục và đặc biệt là Bảng Quyết toán có hiển thị đúng "C nợ A bao nhiêu, C nợ B bao nhiêu" hay không.
