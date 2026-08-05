# BÁO CÁO HOÀN THÀNH KẾ HOẠCH 8

## 1. NLU 2 tầng (Intent & Category) - Đơn giản hóa kiến trúc

**Tình trạng:** Đã hoàn thành cấu trúc mới phía Python Backend (`expense-ocr-nlu`).

**Chi tiết (Sử dụng cho Luận văn Chương 3):**
1. **Loại bỏ các mô hình AI dư thừa:**
   - Đã gỡ bỏ hoàn toàn các module huấn luyện và mô hình Machine Learning truyền thống cho NER (Nhận dạng thực thể), `action_type`, `record_type`, và `action_slots`. Các tác vụ chiết xuất thông tin chi tiết (như bóc tách số tiền, tên người, nội dung giao dịch) giờ đây được giao hoàn toàn cho **Tầng 3 (LLM - Qwen/Gemini)** thông qua cơ chế RAG, đảm bảo độ chính xác ngữ cảnh cao hơn.
2. **Kiến trúc NLU 2 Tầng (Stage 1 & Stage 2):**
   - **Stage 1 (Intent Model):** Mô hình học máy TF-IDF (hoặc PhoBERT) giờ đây chỉ chịu trách nhiệm phân loại 3 ý định gốc: `Record` (Ghi chép), `Action` (Hành động), `Chitchat` (Giao tiếp thông thường).
   - **Stage 2 (Category Model):** Chỉ kích hoạt khi Stage 1 nhận diện là `Record`. Mô hình này phân loại văn bản vào 1 trong 18 danh mục chi tiêu/thu nhập.
   - Cả script `retrain_all.py` (dành cho TF-IDF) và `retrain_encoders.py` (dành cho PhoBERT) đã được cập nhật để chỉ chạy quá trình huấn luyện cho 2 tầng này. Thời gian huấn luyện giảm đi đáng kể (trên 60%).

---

## 2. Đồng bộ hóa dữ liệu từ Phản hồi Người dùng (Feedback Loop)

**Chi tiết:**
1. **Script `export_dataset.py`:**
   - Xây dựng một tập lệnh Python chạy ngầm trước khi bắt đầu huấn luyện. Script này sẽ kết nối trực tiếp vào CSDL **PostgreSQL** của Backend Node.js thông qua chuỗi kết nối `DATABASE_URL`.
   - Script tự động truy vấn bảng `nlu_logs` để tìm kiếm các dữ liệu có nhãn `log_type = 'dislike'` (khi người dùng bấm nút báo sai ý định ở UI Chat).
   - Nếu tìm thấy, script sẽ tự động cập nhật hoặc thêm mới (append) mẫu dữ liệu đó vào tập huấn luyện `intent_action.csv` cùng với nhãn đúng (`corrected_intent` và `corrected_category`) do người dùng cung cấp. Cơ chế này tạo thành một vòng lặp học máy (Continuous Learning) hoàn chỉnh.

---

## 3. Cơ chế Duyệt Mô hình 3 Trạng thái (WebAdmin)

**Chi tiết:**
1. **3 Trạng thái Mô hình:**
   - `models_old`: Phiên bản cũ (dự phòng).
   - `models`: Phiên bản đang được sử dụng (Production).
   - `models_new`: Phiên bản ứng viên (Vừa huấn luyện xong).
2. **API Phê duyệt (Promote):**
   - Đã tích hợp API `POST /api/v1/nlu/models/promote` tại FastAPI và map API `POST /api/admin/train/promote` tại Node.js.
   - Quản trị viên tại WebAdmin (trang NluOpsPage) có thể so sánh chỉ số của mô hình `models_new` với `models` hiện tại. Nếu chất lượng (F1-score, Accuracy) của bản mới vượt trội nhờ dữ liệu feedback, họ có quyền bấm duyệt. Hệ thống sẽ tự động hoán đổi (swap) thư mục và tải lại mô hình (hot-reload) vào bộ nhớ mà không cần khởi động lại server.
