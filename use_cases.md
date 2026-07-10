# Tài liệu Use Case Chi Tiết (MoneyStory)

Tài liệu này hệ thống hóa toàn bộ các luồng chức năng (Use Cases) của hệ thống, bao gồm cả Web Admin và Mobile App ở mức độ chi tiết nhất (từng action cụ thể).

---

## 1. Hệ thống Web Admin (React.js)

| Tên Trang | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Dashboard** | Thống kê tổng quan | - **Xem biểu đồ doanh thu/lượng người dùng mới** theo ngày/tuần/tháng.<br/>- **Theo dõi Health:** Xem trạng thái hoạt động (Up/Down) của các Service AI (NLU/OCR). |
| **User Management** | Quản lý tài khoản | - **Xem danh sách User:** Hiển thị tên, email, ngày tạo.<br/>- **Tìm kiếm/Lọc:** Lọc user theo trạng thái (Free/Premium).<br/>- **Khóa/Mở khóa:** Cấm (Ban) người dùng vi phạm.<br/>- **Cấp quyền:** Nâng cấp user lên Premium thủ công. |
| **Bot Prompts** | Quản lý cấu hình AI | - **Xem Prompt hiện tại:** Hiển thị System Prompt đang áp dụng cho MiMo.<br/>- **Chỉnh sửa Prompt:** Thay đổi luật giao tiếp (cách xưng hô, tính cách, từ chối trả lời câu nhạy cảm).<br/>- **Lưu & Áp dụng ngay:** Update xuống Database và áp dụng real-time không cần deploy. |
| **NLU Ops** | Quản lý & Huấn luyện NLU | - **Duyệt câu bị lỗi:** Xem danh sách các câu nhập liệu bị AI nhận dạng sai danh mục/số tiền.<br/>- **Gắn nhãn lại (Tagging):** Admin sửa lại kết quả phân tích cho đúng chuẩn.<br/>- **Trigger Retrain:** Bấm nút để gọi API fine-tune lại mô hình Qwen trên tập dữ liệu mới.<br/>- **Xem Benchmark:** Xem độ chính xác (Accuracy) sau mỗi lần train. |
| **Bill Retrain** | Quản lý & Huấn luyện OCR | - **Duyệt hóa đơn lỗi:** Hiển thị ảnh Bill mà người dùng báo cáo đọc sai.<br/>- **Sửa Bounding Box:** Vẽ lại khung tọa độ chứa chữ trên ảnh.<br/>- **Sửa Text:** Gõ lại nội dung chữ chính xác.<br/>- **Export Dataset:** Đẩy dữ liệu đã sửa lên HuggingFace để chuẩn bị train LayoutLMv3. |

---

## 2. Hệ thống Mobile App (Flutter)

### 2.1. Nhóm Đăng nhập & Khởi tạo (Auth)
| Tên Màn Hình | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Login / Register** | Xác thực | - **Đăng nhập:** Bằng Email/Password hoặc Google OAuth.<br/>- **Đăng ký:** Tạo tài khoản mới.<br/>- **Quên mật khẩu:** Gửi email reset pass. |
| **Onboarding** | Khởi tạo thông tin | - **Xem hướng dẫn:** Lướt qua 4 slide giới thiệu tính năng.<br/>- **Nhập Profile:** Chọn Tên gọi, avatar và giới tính để Bot MiMo xưng hô.<br/>- **Chọn Mục tiêu:** Setup mục tiêu tiết kiệm đầu tiên. |

### 2.2. Nhóm Quản lý Giao dịch (Home & Story)
| Tên Màn Hình | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Trang Chủ (Home)** | Khám phá & Quản lý | - **Xem List:** Cuộn danh sách các giao dịch dưới dạng Story (Timeline).<br/>- **Xem Calendar:** Xem lịch tháng, các ngày có chấm xanh là có giao dịch.<br/>- **Xem Gallery:** Hiển thị thư viện toàn bộ ảnh hóa đơn đã chụp.<br/>- **Lọc theo Ví:** Chọn xem giao dịch của một Ví cụ thể hoặc "Tất cả Ví". |
| **Chi tiết Story** | Tương tác giao dịch | - **Xem chi tiết:** Xem ảnh hóa đơn phóng to, comment của AI.<br/>- **Chỉnh sửa:** Đổi số tiền, đổi danh mục, đổi ngày.<br/>- **Xóa:** Xóa bỏ giao dịch.<br/>- **Bình luận:** Chat qua lại với các thành viên khác (Nếu là Ví nhóm). |
| **Quản lý Ví** | Quản lý nguồn tiền | - **Tạo Ví:** Tạo Ví cá nhân hoặc Ví nhóm (Tên ví, Số dư ban đầu).<br/>- **Chỉnh sửa/Xóa Ví:** Đổi tên hoặc xóa (chỉ owner).<br/>- **Chia sẻ Ví:** Lấy mã QR/Link mời bạn bè vào ví nhóm.<br/>- **Quản lý Thành viên:** Xem danh sách, kích thành viên, cấp quyền View/Edit.<br/>- **Rời nhóm:** Tự động rời khỏi ví nhóm của người khác. |

### 2.3. Nhóm Nhập liệu & AI (Input)
| Tên Màn Hình | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Camera (Chụp Bill)** | Nhập liệu bằng ảnh | - **Chụp ảnh / Chọn ảnh:** Mở camera hoặc thư viện.<br/>- **Cắt ảnh (Crop):** Cắt vùng chứa hóa đơn.<br/>- **Đợi OCR:** Gửi ảnh chạy nền, hiển thị loading nhận dạng LayoutLMv3. |
| **Nhập Văn Bản NLU** | Nhập liệu bằng chữ | - **Gõ Text:** VD: "Sữa 20k".<br/>- **Phân tích Async:** Gửi đoạn text lên Backend Qwen xử lý nền. |
| **Xác nhận (Confirm)** | Sửa lỗi AI | - **Review thông tin:** Nếu AI không chắc chắn (Độ tin cậy < 80%), hiện màn hình cho phép người dùng tự chọn lại Danh mục, Sửa số tiền, Ngày tháng trước khi Lưu. |
| **Chat AI** | Trò chuyện & Ra lệnh | - **Nhận văn bản/giọng nói:** Gõ hoặc thu âm gửi cho Bot.<br/>- **Ra lệnh:** "Thống kê tháng 6", "Tôi vừa tiêu 50k ăn trưa".<br/>- **Xem Lịch sử:** Cuộn xem lại lịch sử chat.<br/>- **Xóa Lịch sử:** Làm mới cuộc hội thoại. |

### 2.4. Nhóm Công cụ Tài chính (Financial Tools)
| Tên Màn Hình | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Tiết kiệm (Goal)** | Nuôi Heo đất | - **Tạo/Sửa/Xóa Mục tiêu:** Đặt tên, số tiền đích, ngày đến hạn.<br/>- **Đóng góp (Deposit):** Bỏ tiền vào hũ (Sẽ trừ tiền từ Ví tương ứng).<br/>- **Rút tiền (Withdraw):** Lấy tiền ra khỏi hũ.<br/>- **Quản lý Nhóm:** Tham gia hũ tiết kiệm nhóm bằng Code, rời khỏi nhóm.<br/>- **Xem Lịch sử:** Xem danh sách ai vừa bỏ bao nhiêu tiền vào hũ.<br/>- **Recap:** Xem hiệu ứng pháo hoa ăn mừng khi hũ đạt 100%. |
| **Thử thách** | Tiết kiệm thi đua | - **Các chức năng giống Tiết kiệm.**<br/>- **Bảng xếp hạng:** Xem ai đang đóng góp nhiều nhất trong Thử thách. |
| **Vay mượn (Loans)** | Quản lý Nợ | - **Tạo khoản nợ:** Ghi chú ai nợ ai (Đi vay / Cho vay), số tiền, ngày trả.<br/>- **Sửa/Xóa:** Cập nhật thông tin nợ.<br/>- **Xem Lịch sử trả nợ:** Xem tiến trình trả dần.<br/>- **Trả nợ (Repay):** Trả 1 phần hoặc toàn bộ (Tự động cập nhật vào số dư Ví). |
| **Hạn mức (Limits)** | Budgeting | - **Tạo/Sửa/Xóa Hạn mức:** Thiết lập số tiền tối đa được tiêu cho 1 Danh mục (VD: Ăn uống 3 triệu/tháng).<br/>- **Gợi ý AI:** Tự động điền số tiền gợi ý dựa trên lịch sử.<br/>- **Xem thanh tiến trình:** Xem % đã tiêu, nhận cảnh báo đỏ nếu vượt 90%. |
| **Luật lặp lại** | Tự động hóa | - **Tạo/Sửa/Xóa Luật:** Lên lịch trừ tự động (VD: Tiền điện, mỗi ngày 15 hàng tháng, trừ 500k). |

### 2.5. Nhóm Báo cáo & Gamification
| Tên Màn Hình | Chức năng chi tiết (Use Cases) | Mô tả hành động cụ thể |
| :--- | :--- | :--- |
| **Báo Cáo (Report)** | Thống kê phân tích | - **Cashflow:** Biểu đồ cột dòng tiền Thu/Chi theo tháng.<br/>- **Category Spending:** Biểu đồ tròn cơ cấu các khoản chi lớn nhất.<br/>- **Saving Trend:** Biểu đồ đường xu hướng tiết kiệm qua từng tháng.<br/>- **Lọc thời gian:** Chọn xem theo Tháng/Năm/Tùy chọn khoảng thời gian. |
| **Chuỗi duy trì (Streak)**| Gamification | - **Xem Streak:** Hiển thị số ngày liên tiếp có mở app nhập chi tiêu.<br/>- **Tương tác:** Nhấn nhận quà (Flame/Cây trồng). |
| **Cài đặt (Settings)** | Tùy chỉnh | - **Đổi tính cách Mascot (Premium):** Chọn lại Giọng điệu của MiMo.<br/>- **Export Data:** Xuất file Excel toàn bộ dữ liệu giao dịch.<br/>- **Đăng xuất / Xóa tài khoản.** |
