# Kế hoạch Thiết kế Responsive cho Ứng dụng Spending Diary

Bản kế hoạch này phân tích kiến trúc giao diện hiện tại và đề xuất chiến lược responsive chi tiết cho 3 loại màn hình: **Điện thoại màn hình ngang (Landscape Mobile)**, **Tablet dọc (Portrait Tablet)**, và **Tablet ngang (Landscape Tablet)**. Mục tiêu là đảm bảo UI đẹp mắt, đúng chuẩn UX/UI của ứng dụng tài chính, và tuyệt đối không bị lỗi `RenderFlex overflowed`.

## 1. Kiến trúc Tổng thể & Breakpoints

Chúng ta sẽ thống nhất các breakpoints (ngưỡng kích thước) sau để áp dụng `LayoutBuilder` và `MediaQuery`:
- **Compact (Portrait Mobile):** Width < 600
- **Medium (Portrait Tablet & Large Foldables):** 600 <= Width < 900
- **Expanded (Landscape Tablet & Desktop):** Width >= 900
- **Landscape Mobile (Điện thoại ngang):** Height < 500 & Width > Height

### AppShell (Thanh Điều Hướng)
- **Compact & Landscape Mobile:** Sử dụng `BottomNavigationBar` ở dưới cùng. Tuy nhiên, với Landscape Mobile, chiều cao rất hẹp, nên chuyển sang `NavigationRail` mini ở cạnh trái để tiết kiệm không gian dọc.
- **Medium (Tablet dọc):** Sử dụng `NavigationRail` (dạng icon + text ngắn).
- **Expanded (Tablet ngang):** Sử dụng `NavigationRail` mở rộng (có nhãn rõ ràng) hoặc `Drawer` cố định bên trái.

---

## 2. Phân tích chi tiết và Chiến lược cho từng Màn hình

### A. Trang Chủ (Home Screen)
**Hiện trạng:** Đang dùng `CustomScrollView` với Header (chứa số dư) và Content (Tab: Story, Gallery, Calendar). Hiện đã có logic chia 2 cột (4/6) cho Width >= 768.

**Chiến lược nâng cấp:**
- **Điện thoại ngang (Landscape Mobile):** 
  - *Vấn đề:* Chiều cao quá thấp, Header chiếm hết chỗ.
  - *Giải pháp:* Chia màn hình thành `Row`. Trái (40%): Header thu gọn (ẩn biểu đồ nhỏ, chỉ hiện số dư tổng). Phải (60%): Danh sách giao dịch/Story scroll độc lập.
- **Tablet dọc (Medium):** 
  - *Giải pháp:* Không chia cột vì sẽ làm hai bên bị chật. Dùng 1 cột nhưng giới hạn chiều rộng tối đa (`MaxWidth` ~ 600px) căn giữa màn hình, hoặc trải đều Header nhưng Tab content hiển thị dưới dạng Grid (2 cột cho Story Card).
- **Tablet ngang (Expanded):** 
  - *Giải pháp:* Giữ nguyên layout chia cột (Trái: Header & Tóm tắt, Phải: Tabs).
  - Nâng cấp `Gallery`: Đổi `SliverGrid` từ 3 cột lên 4-5 cột để tránh ảnh bị quá to gây vỡ hạt.
  - Nâng cấp `Calendar`: Hiển thị lịch kích thước lớn hơn, tích hợp chi tiết giao dịch ngay bên cạnh (Master-Detail).

### B. Màn hình Chat (Chat Screen)
**Hiện trạng:** Cửa sổ chat tiêu chuẩn với `ListView` và TextField ở dưới.

**Chiến lược nâng cấp:**
- **Điện thoại ngang:** 
  - *Vấn đề:* Khi bàn phím bật lên, khu vực hiển thị tin nhắn gần như biến mất (chỉ còn ~50px).
  - *Giải pháp:* Ẩn AppBar khi bàn phím mở. Thu nhỏ thanh nhập liệu (bỏ bớt các nút phụ vào một nút `+`).
- **Tablet dọc:** 
  - *Vấn đề:* Bong bóng chat (Chat bubbles) chạy ngang hết màn hình trông rất xấu và khó đọc.
  - *Giải pháp:* Đặt `maxWidth` cho `Container` của bong bóng chat (khoảng 70% width của màn hình). Căn lề trái/phải rõ ràng.
- **Tablet ngang:** 
  - *Giải pháp:* Áp dụng Master-Detail. Bên trái là Lịch sử chat (Chat History) dạng list (chiếm 30%), bên phải là màn hình Chat hiện tại (chiếm 70%).

### C. Màn hình Báo cáo (Report Screen)
**Hiện trạng:** Biểu đồ Pie/Bar ở trên, danh sách chi tiết ở dưới.

**Chiến lược nâng cấp:**
- **Điện thoại ngang:** 
  - *Giải pháp:* Chuyển sang bố cục `Row`. Trái: Biểu đồ (Pie Chart thu nhỏ). Phải: Danh sách categories có thể cuộn.
- **Tablet dọc & ngang:** 
  - *Giải pháp:* Xây dựng giao diện **Dashboard**. 
  - Hàng 1: Các Card thống kê tổng quát (Thu, Chi, Số dư) nằm ngang (`Row`).
  - Hàng 2: Biểu đồ nằm cạnh nhau (Ví dụ: Pie chart chi tiêu bên trái, Bar chart xu hướng bên phải).
  - Hàng 3: Bảng chi tiết giao dịch (DataTable thay vì ListView để tối ưu không gian).

### D. Màn hình Mục tiêu & Công cụ (Goals / Financial Tools)
**Chiến lược chung:**
- **Điện thoại ngang:** Dùng `SliverGrid` 2 cột hoặc list cuộn ngang.
- **Tablet dọc:** `SliverGrid` 2 cột.
- **Tablet ngang:** `SliverGrid` 3-4 cột. Giới hạn tỷ lệ khung hình (`childAspectRatio`) để Card không bị kéo giãn quá mức (ví dụ duy trì tỷ lệ 3:4 hoặc 1:1).

---

## 3. Quản lý Widgets Dùng chung (Common Widgets)

Để tránh lỗi `RenderFlex overflowed` và đảm bảo UI đẹp mắt:

1. **`BottomSheet` (Ví dụ: `PremiumUpsellBottomSheet`, `BillProcessingBanner`):**
   - Trên Tablet (Medium/Expanded): Trông rất xấu nếu kéo dài full màn hình ngang. Bắt buộc bọc trong `ConstrainedBox(maxWidth: 450)` hoặc chuyển thành `AlertDialog` (Dialog hiển thị giữa màn hình).
2. **`TransactionStoryCard` & `AppCard`:**
   - Thay vì dùng `width: double.infinity`, hãy bọc nội dung trong `Center` + `ConstrainedBox(maxWidth: 600)` đối với các layout 1 cột trên Tablet dọc để mắt người dùng không phải quét từ mép trái sang mép phải quá xa.
3. **Typography & Icons:**
   - Sử dụng hệ thống text scale động. Trên màn hình Expanded, tăng kích thước font title (Heading) lên ~1.2x để cân đối với không gian trống.

## Yêu cầu người dùng (User Review Required)

> [!IMPORTANT]
> **Câu hỏi chờ xác nhận:**
> 1. Với thiết bị **Tablet ngang (iPad/Desktop)**, bạn có đồng ý chuyển màn hình Chat sang dạng **Master-Detail** (Trái: Lịch sử Chat, Phải: Nội dung Chat) không? Hiện tại lịch sử chat đang ở một màn hình riêng.
> 2. Với **Điện thoại ngang (Landscape Mobile)**, không gian rất hẹp. Bạn có đồng ý chuyển thanh điều hướng (Bottom Nav) sang cạnh trái màn hình (Rail thu nhỏ) để tối ưu chiều cao cho nội dung không?
> 3. Các BottomSheet (Menu xổ từ dưới lên) trên Tablet có nên được chuyển thành hộp thoại ở giữa màn hình (Dialog Box) để trông sang trọng và gọn gàng hơn không?

Vui lòng xem qua kế hoạch và cho ý kiến về các câu hỏi trên để bắt đầu chỉnh sửa code thực tế.
