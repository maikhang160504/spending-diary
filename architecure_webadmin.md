Cấu trúc Website Admin Tinh gọn 
1. Phân hệ Giám sát Kiểm soát Chất lượng Nhập liệu (Fusion & AI Dashboard)
Báo cáo Tỷ lệ Hội tụ (Fusion Success Rate): Xem có bao nhiêu % giao dịch tự động điền đúng cả 3 trường (Amount, Category, Date).

Cấu hình Trọng số Fusion (Fusion Weights Config): Giao diện chỉnh sửa nhanh quy tắc ưu tiên. Ví dụ: Nếu độ tự tin của OCR thấp, hệ thống tự động lấy Số tiền (Amount) do user tự gõ trong text hội thoại.

2. Phân hệ Vận hành NLU 3 Lớp & Quản lý Nhãn (NLU & Retraining Management) — Trọng tâm
Quản lý Quy tắc Ghi đè Tĩnh (Layer 1: Exact Match Mapping): Nơi xem và sửa các từ khóa map cứng theo từng cá nhân (user_exact:{user_id}).

Màn hình Gom cụm Sửa đổi (Layer 2: Correction Aggregation): Tự động nhóm các từ khóa bị nhiều user sửa đổi nhiều nhất (Ví dụ: 1000 người cùng sửa cụm "GrabBike" từ Entertainment thành Transport).

Trạm duyệt dữ liệu Tái huấn luyện (Global Train Curation): Admin duyệt các cụm từ chuẩn hóa để xuất file CSV làm giàu cho mô hình Global (TF-IDF + Logistic Regression/SVM).

Quản lý Phiên bản Model (Model Versioning & Hot-reload): Upload và kích hoạt file global_model.joblib mới trực tiếp từ giao diện.

3. Phân hệ Quản trị Người dùng & Giám sát "Story Timeline"
Tra cứu NLU State của User (User Inspector): Nhập user_id để kiểm tra các câu user đã sửa, dung lượng cache chiếm dụng trên Redis.

Nút "Clear & Reload Cache": Xóa bộ nhớ đệm Redis của user đó và nạp lại từ Postgres để sửa lỗi đồng bộ ngay lập tức cho khách hàng.

4. Phân hệ Quản lý Kịch bản Chat AI (AI Bot Scenarios & Prompt Management)
Quản lý System Prompt: Thay đổi tính cách và định dạng câu trả lời của Trợ lý tài chính AI.

Cấu hình Ngưỡng Cảnh báo (Alert Thresholds): Cài đặt điều kiện để Bot tự động sinh Story nhắc nhở (Ví dụ: Chi tiêu mục Shopping vượt quá 30% so với tuần trước).

# Ma trận Phân quyền & Kế hoạch Phát triển (Roadmap)

Tên Phân hệ,Chức năng chi tiết,Quyền truy cập,Ưu tiên
NLU & Retraining,"Tra cứu quy tắc, Gom cụm sửa đổi, Duyệt tập Train",AI Engineer / Ops,Giai đoạn 1 (MVP)
Quản trị User,"Xem NLU State, Clear & Reload Cache",Customer Support / Dev,Giai đoạn 1 (MVP)
Fusion Dashboard,"Xem tỷ lệ đoán đúng/sai, cấu hình trọng số",Product Owner / Data,Giai đoạn 2
Chat AI Scenarios,"Quản lý Prompt, cấu hình kịch bản nhắc nhở",Product Owner,Giai đoạn 3