# BÁO CÁO HOÀN THÀNH KẾ HOẠCH 6 VÀ KẾ HOẠCH 7

## 1. Kế hoạch 6: Cập nhật Backend Node.js và Quy chuẩn Hiển thị RAG

**Tình trạng:** Đã hoàn thành toàn bộ và vượt qua 100% Test Suite.

**Chi tiết triển khai (Sử dụng cho Luận văn Chương 3 & 4):**
1. **Lọc dữ liệu thông minh theo phân vùng ví (Wallet Isolation):**
   - Đã điều chỉnh API AI Chat (`ai.controller.js` và `ai.service.js`) để bắt ngữ cảnh ví khi sinh Báo cáo (RAG).
   - Nếu `walletId` thuộc về Ví cá nhân, hệ thống thực hiện query SQL chỉ lấy giao dịch thuộc về người dùng đó.
   - Nếu `walletId` thuộc Ví chung, hệ thống truy xuất giao dịch của toàn bộ thành viên trong nhóm, đồng thời gom nhóm `by_member` để LLM có thể nhận xét chính xác tỷ lệ đóng góp của từng người.
2. **Quy chuẩn hiển thị bong bóng Chat (Bubble UI Standard):**
   - Backend đã chuẩn hóa cấu trúc trả về mảng `bubbles`.
   - Với ý định Báo cáo/So sánh (`REPORT_GENERAL`, `REPORT_COMPARE`), trả về 3 bong bóng: (1) Lời thoại từ NLU, (2) Biểu đồ/Thẻ dữ liệu động, (3) Lời nhận xét, phân tích chuyên sâu sinh bởi LLM RAG.
   - Với ý định hành động (Thêm giao dịch, Đặt hạn mức), trả về 2 bong bóng: (1) Lời thoại xác nhận, (2) UI Thẻ hành động.
3. **Cơ chế Luồng kép (Dual-NLG) cho mô hình truyền thống:**
   - Để đảm bảo tốc độ phản hồi, quá trình sinh lời bình LLM (khi dùng backend TF-IDF hoặc PhoBERT) được đẩy vào xử lý nền (Background Processing) sử dụng `setImmediate`. Node.js không block event loop chờ LLM.
4. **Cơ chế thu thập phản hồi người dùng (Feedback Loop):**
   - Đã triển khai API `POST /api/v1/ai/dislike-intent` để nhận diện các trường hợp AI phân loại sai ý định. Dữ liệu được ghi vào bảng `nlu_logs` với cờ `intent_disliked = true` kèm `corrected_intent` do người dùng đóng góp. Tập dữ liệu này sẽ là nguồn tài nguyên vô giá để tự động retraining mô hình (Triển khai ở Kế hoạch 8).
5. **Cập nhật Bộ Test Case:**
   - Đã sửa lại các file test unit (như `goalFuzzy.test.js`, `ai.service.test.js`) để khớp với luồng xử lý mới (thêm nhận diện Action `GOP_TIEN`). Toàn bộ 11/11 Test Suites đã PASS.

---

## 2. Kế hoạch 7: OCR Training Progress trên WebAdmin

**Tình trạng:** Đã hoàn thành.

**Chi tiết triển khai:**
1. **Theo dõi tiến độ huấn luyện LayoutLMv3 (Modal Cloud):**
   - Đã cập nhật giao diện `BillRetrainPage.jsx` trên WebAdmin, bổ sung thanh tiến trình (Progress Bar) mô phỏng động khi người dùng khởi chạy tiến trình huấn luyện đám mây.
   - Tích hợp endpoint `GET /api/admin/bill-retrain/train/status` trên Backend Node.js để cấp phát thông tin trạng thái `stage`, `progress_percent`, `message`, và `elapsed` cho WebAdmin.
   - Dù tiến trình thực tế chạy trên Modal (Serverless GPU), việc bổ sung thanh tiến trình tại Frontend giúp Quản trị viên nắm bắt vòng đời khởi tạo và tính toán mà không bị cảm giác "hệ thống bị treo".
