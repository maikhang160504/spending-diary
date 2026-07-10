# Kế hoạch Triển khai Responsive Design (Mobile & Tablet)

Mục tiêu: Đảm bảo ứng dụng Flutter hoạt động hoàn hảo trên mọi kích thước màn hình (Điện thoại dọc/ngang, Máy tính bảng dọc/ngang) mà **không làm thay đổi logic nghiệp vụ hiện tại**.

## 1. Phân tích các màn hình hiện tại và Gợi ý thiết kế

Dưới đây là danh sách các màn hình cốt lõi và chiến lược "biến hình" (Responsive Strategy) tương ứng khi xoay ngang hoặc dùng màn hình lớn (Tablet).

### 1.1. App Shell (Khung Navigation)
* **Hiện tại:** Dùng `BottomNavigationBar` ở dưới đáy màn hình.
* **Vấn đề khi xoay ngang:** Thanh BottomBar chiếm diện tích chiều dọc quá quý giá, làm không gian hiển thị nội dung bị bóp nghẹt.
* **Gợi ý thiết kế:** 
  * Sử dụng `LayoutBuilder`. 
  * Nếu `width < 600` (Mobile dọc): Giữ nguyên `BottomNavigationBar`.
  * Nếu `width >= 600` (Mobile ngang / Tablet): Chuyển sang dùng `NavigationRail` (Thanh điều hướng dọc nằm ở mép trái màn hình).

### 1.2. Màn hình Trang chủ (Home - List/Calendar)
* **Hiện tại:** Danh sách Story cuộn dọc (`ListView`). Bấm vào 1 Story sẽ bị chuyển trang (`Navigator.push`) sang chi tiết.
* **Gợi ý thiết kế (Tablet / Mobile Ngang):** Áp dụng kiến trúc **Master-Detail (Chia đôi màn hình)**.
  * Khung bên trái (Master): Hiển thị danh sách Story (tỷ lệ 40% màn hình).
  * Khung bên phải (Detail): Thay vì chuyển trang, bấm vào Story bên trái sẽ trực tiếp nạp nội dung của `DetailStoryScreen` vào khung bên phải (tỷ lệ 60%). Điều này tận dụng triệt để không gian thừa.

### 1.3. Màn hình Nhập liệu (Camera / Hóa đơn)
* **Hiện tại:** Màn hình chụp ảnh với các nút bấm nằm ở dưới cùng.
* **Gợi ý thiết kế (Xoay ngang):** 
  * Giao diện ngắm chụp (Viewfinder) chiếm 70% bên trái. 
  * Các nút bấm (Chụp, Đèn flash, Chọn ảnh từ thư viện) chuyển thành một cột dọc ở mép phải màn hình để ngón cái dễ với tới.

### 1.4. Màn hình Công cụ Tài chính & Báo cáo (Grid & Charts)
* **Hiện tại:** Lưới (Grid) các icon công cụ, hoặc Biểu đồ nằm đè lên trên danh sách thống kê.
* **Gợi ý thiết kế:** 
  * GridView: Bắt giá trị `MediaQuery.of(context).size.width`. Điện thoại dọc: 2 cột. Điện thoại ngang: 4 cột. Tablet: 6 cột.
  * Báo cáo: Biểu đồ (Pie Chart/Bar Chart) đẩy sang nửa trái màn hình, danh sách diễn giải đẩy sang nửa phải. Không bắt người dùng phải cuộn chuột nhiều.

---

## 2. Công cụ kỹ thuật (Flutter Utils)

Sẽ không sửa đổi logic lấy dữ liệu (API, Provider/State), chỉ bọc giao diện lại bằng các Widget của Flutter:
1. `LayoutBuilder`: Phát hiện không gian trống để render giao diện phù hợp.
2. `MediaQuery.of(context).orientation`: Phát hiện thiết bị đang xoay ngang hay dọc.
3. `SafeArea`: Tránh tai thỏ (Notch) đặc biệt là khi xoay ngang điện thoại.
4. `Flexible` / `Expanded` / `Wrap`: Tránh lỗi thần thánh `RenderFlex overflowed`.

---

## 3. Lộ trình Thực thi (Phases)

* **Giai đoạn 1 (Ưu tiên số 1):** Sửa lỗi `AppShell` (áp dụng NavigationRail) và chia cột động cho các màn hình dạng Grid (`FinancialTools`, `Limits`).
* **Giai đoạn 2 (Ưu tiên số 2):** Cấu trúc lại luồng Home & Story Detail thành dạng Master-Detail cho màn ngang. Sửa giao diện Report (Biểu đồ).
* **Giai đoạn 3 (Ưu tiên số 3):** Tối ưu giao diện Camera ngang và các Form nhập liệu (không bị che lấp bởi bàn phím ảo ngang).
* **Giai đoạn 4:** Unit/Widget Test. Xoay thiết bị liên tục trên Emulator để dò tìm các lỗi `Bottom Overflowed`.

---

> [!IMPORTANT]
> **User Review Required**
> Vui lòng xem xét các gợi ý thiết kế Master-Detail và NavigationRail. Nếu bạn đồng ý với kế hoạch Responsive này, hãy bấm "Proceed" để tôi bắt tay vào code **Giai đoạn 1 (AppShell + Grid)** nhé!
