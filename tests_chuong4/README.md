# Kế hoạch Kiểm thử Toàn diện — Chương 4: Spending Diary

> **Mục đích:** Tài liệu này là cơ sở để chạy từng tool và thu số liệu thực trước khi viết Chương 4.  
> Tool có sẵn → tái sử dụng. Thiếu → viết thêm. Kết quả thực → mới điền vào luận văn.

---

## Phân nhóm kiểm thử

| Nhóm | Phạm vi | Phương pháp |
|------|---------|-------------|
| **A** | App di động (Flutter) | Usability + Functional |
| **W** | Web Admin (React) | Functional |
| **AI** | AI Pipeline (NLU + OCR/KIE) | Benchmark + Regression |
| **BE** | Backend Node.js (API + Logic) | Unit Test (Jest) |
| **DB** | Cơ sở dữ liệu CockroachDB | Database Testing |
| **NFR** | Phi chức năng (Security, Performance, Reliability) | API Test Script |

---

## NHÓM A — Kiểm thử Ứng dụng Di động (Mobile App)

### A.1 — Xác thực và Tài khoản

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A01 | Đăng ký tài khoản | Tạo tài khoản mới thành công | Nhập email chưa có trong hệ thống + mật khẩu hợp lệ → Nhấn Đăng ký | Hệ thống gửi email xác nhận, tài khoản được tạo | Manual |
| A02 | Đăng ký trùng email | Ngăn tạo tài khoản trùng | Nhập email đã tồn tại → Nhấn Đăng ký | Hiện lỗi "Email đã được sử dụng" | Manual |
| A03 | Đăng nhập đúng | Xác thực đăng nhập hợp lệ | Nhập đúng email + mật khẩu của tài khoản thật | Chuyển vào màn hình Trang chủ, hiển thị số dư ví | Manual |
| A04 | Đăng nhập sai mật khẩu | Ngăn truy cập trái phép | Nhập đúng email nhưng mật khẩu sai | Hiện thông báo lỗi, không vào được app | Manual |
| A05 | Quên mật khẩu | Khôi phục tài khoản | Nhấn "Quên mật khẩu" → Nhập email → Kiểm tra hộp thư | Nhận được email chứa mã OTP hoặc link đặt lại | Manual |
| A06 | Đăng nhập Google | Xác thực qua Social Login | Nhấn "Đăng nhập bằng Google" → Chọn tài khoản Google | Đăng nhập thành công bằng tài khoản Google | Manual |

### A.2 — Ghi chép Giao dịch (NLU — Chat với MiMo)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A07 | NLU — chi tiêu thông thường | AI nhận diện đúng khoản chi | Nhắn: *"ăn trưa bún bò 45k"* | Ghi nhận: 45.000đ / Ăn uống / Chi tiêu | `tc01_nlu_functional.py` |
| A08 | NLU — tiếng lóng | AI hiểu từ lóng giới trẻ | Nhắn: *"bay 2 trăm hg trân châu"* | Ghi nhận: 200.000đ / Ăn uống | `tc01_nlu_functional.py` |
| A09 | NLU — thu nhập | Phân biệt thu / chi | Nhắn: *"nhận lương tháng 8 triệu"* | Ghi nhận: 8.000.000đ / Lương / Thu nhập | `tc01_nlu_functional.py` |
| A10 | NLU — thiếu số tiền | AI hỏi lại thay vì báo lỗi | Nhắn: *"sáng nay đi ăn phở"* (không có số tiền) | MiMo hỏi lại: *"Bạn chi bao nhiêu vậy?"* | `tc_nlu_missing_slot.py` |
| A11 | NLU — lệnh xem báo cáo | Phân biệt Action vs Record | Nhắn: *"tháng này tôi tiêu bao nhiêu"* | MiMo trả về báo cáo tổng chi từ DB, không tạo giao dịch | `tc01_nlu_functional.py` |
| A12 | NLU — chitchat | Xử lý câu không liên quan | Nhắn: *"hôm nay trời đẹp quá"* | MiMo phản hồi tự nhiên, không tạo giao dịch | `tc01_nlu_functional.py` |
| A13 | Xác nhận trước khi lưu | Cho phép sửa trước khi lưu | Sau khi AI bóc tách xong, người dùng sửa lại số tiền | Giao dịch được lưu đúng với số tiền đã chỉnh | Manual |

### A.3 — Quét Hóa đơn (OCR)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A14 | OCR — hóa đơn rõ nét | Bóc tách thông tin cơ bản | Chụp hóa đơn siêu thị rõ nét | Trích xuất đúng: Tên cửa hàng + Tổng tiền | `test_bill_insert.js` |
| A15 | OCR — hóa đơn mờ/nhăn | Kiểm tra độ bền mô hình | Chụp hóa đơn in nhiệt mờ, bị nhăn | Vẫn bóc tách được Tổng tiền (sai số < 5%) | `test_bill_insert.js` |
| A16 | OCR — ảnh nghiêng | Kiểm tra xử lý ảnh góc nghiêng | Chụp hóa đơn nghiêng ~30 độ | Hệ thống tự chỉnh và vẫn đọc được | Manual |
| A17 | Người dùng sửa kết quả OCR | Cho phép chỉnh sai sót | Sau khi OCR xong, sửa lại số tiền bị nhận sai | Giao dịch lưu đúng số tiền đã chỉnh | Manual |

### A.4 — Quản lý Ví tiền

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A18 | Tạo ví cá nhân | Tạo ví mới thành công | Nhấn "Tạo ví" → Nhập tên "Tiền mặt" → Lưu | Ví mới xuất hiện trong danh sách, số dư = 0 | Manual |
| A19 | Tạo ví dùng chung (Group) | Tính năng nhóm | Tạo ví nhóm → Mời thêm thành viên bằng email | Thành viên nhận được lời mời, ví hiển thị nhiều member | Manual |
| A20 | Giới hạn ví (Free account) | Kiểm tra rule Premium | Dùng tài khoản Free, tạo ví thứ 3 trở đi | Hiện popup yêu cầu nâng cấp Premium | Manual |

### A.5 — Quản lý Ngân sách

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A21 | Đặt ngân sách tháng | Lưu hạn mức chi tiêu | Vào "Ngân sách" → Đặt hạn mức Ăn uống = 2.000.000đ | Hạn mức được lưu, hiển thị thanh tiến trình | `budgetCalibrate.test.js` |
| A22 | Cảnh báo vượt ngân sách | Kích hoạt cảnh báo đúng lúc | Chi tiêu vượt qua 80% ngân sách đã đặt | Ứng dụng hiển thị cảnh báo màu vàng/đỏ | `budgetCalibrate.test.js` |
| A23 | Gợi ý ngân sách AI | Tính năng tư vấn | Nhắn: *"gợi ý hạn mức chi tiêu tháng này"* | MiMo đề xuất hạn mức dựa trên lịch sử chi tiêu | `action.service.test.js` |

### A.6 — Báo cáo và Lịch sử

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A24 | Xem lịch sử giao dịch | Hiển thị đúng danh sách | Vào tab "Lịch sử" | Danh sách giao dịch hiển thị đúng thứ tự ngày mới nhất | Manual |
| A25 | Lọc giao dịch | Bộ lọc đa chiều | Lọc theo Danh mục "Ăn uống" trong tháng 7 | Chỉ hiển thị giao dịch thuộc ăn uống trong tháng 7 | Manual |
| A26 | Xem lịch tháng | Giao diện dạng Calendar | Chuyển sang chế độ xem "Lịch" | Các ngày có giao dịch được đánh dấu màu | Manual |
| A27 | Biểu đồ báo cáo | Vẽ đúng biểu đồ | Vào "Báo cáo" → Xem biểu đồ tháng | Biểu đồ tròn và cột hiển thị đúng tỷ lệ theo danh mục | Manual |
| A28 | Tính năng Recap (Nhìn lại hành trình) | Story card cuối năm | Vào tính năng Recap | Hiển thị thẻ Story với bình luận AI hóm hỉnh đúng dữ liệu | Manual |

### A.7 — Chia sẻ Mạng xã hội

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A29 | Tạo ảnh chia sẻ | Xuất ảnh giao dịch | Chọn giao dịch → Nhấn "Chia sẻ" | Tạo ra tấm ảnh trang trí đẹp chứa thông tin giao dịch | Manual |
| A30 | Chia sẻ lên mạng xã hội | Tích hợp share intent | Nhấn nút "Chia sẻ ảnh" → Chọn Messenger | Mở ứng dụng Messenger với ảnh đã đính kèm | Manual |

### A.8 — Nâng cấp Premium

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| A31 | Xem bảng giá | Hiển thị đúng quyền lợi | Vào màn hình "Nâng cấp Premium" | Hiển thị bảng so sánh Free vs Pro rõ ràng | Manual |
| A32 | Thanh toán VNPay | Luồng thanh toán hoàn chỉnh | Nhấn "Mua Premium" → Mở WebView VNPay | WebView mở đúng trang VNPay, đóng lại sau khi thanh toán | Manual |

---

## NHÓM W — Kiểm thử Trang Quản trị (Web Admin)

### W.1 — Dashboard AIOps

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W01 | Dashboard tổng quan | Hiển thị đúng các chỉ số | Đăng nhập Admin → Vào Dashboard | Hiển thị: Tổng lượt AI, Độ hội tụ AI, Doanh thu Premium | Manual |
| W02 | Thanh Retrain Readiness | Theo dõi ngưỡng huấn luyện lại | Xem thanh tiến trình NLU và OCR Retrain | Thanh % tăng đúng theo số lượng dữ liệu đã phê duyệt | Manual |

### W.2 — Quản lý Người dùng

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W03 | Tìm kiếm người dùng | Tra cứu đúng tài khoản | Nhập email người dùng vào ô tìm kiếm | Danh sách hiển thị đúng tài khoản khớp | Manual |
| W04 | Lọc theo nhóm nhân khẩu | Phân loại người dùng | Lọc theo "Sinh viên" + "18-22 tuổi" | Chỉ hiển thị tài khoản thuộc nhóm đó | Manual |
| W05 | Khóa tài khoản vi phạm | Kiểm tra cơ chế ban | Nhấn "Khóa" tài khoản test → Thử đăng nhập lại app | App báo lỗi "Tài khoản đã bị khóa", không vào được | `tc_ban_unban.js` (cần viết) |
| W06 | Mở khóa tài khoản (Appeals) | Quy trình xử lý khiếu nại | Nhấn "Mở khóa" tài khoản đã bị ban → Thử đăng nhập lại | Đăng nhập vào app thành công | `tc_ban_unban.js` (cần viết) |
| W07 | Nâng cấp Premium thủ công | Xử lý lỗi Webhook | Tìm user → Nhấn toggle "Kích hoạt Premium" | Tài khoản nhận được ngày VIP, app hiển thị badge Premium | Manual |

### W.3 — MLOps / NLU Retrain

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W08 | Thêm luật từ khóa (Layer 1) | Gán luật cứng cho từ lóng | Thêm luật: "cf" → Danh mục "Ăn uống" | Câu nhắn "đi cf 30k" → AI tự phân vào Ăn uống | Manual |
| W09 | Duyệt dữ liệu đính chính (Layer 2) | Phê duyệt dữ liệu người dùng sửa | Xem danh sách curation → Nhấn "Phê duyệt" | Dữ liệu chuyển sang trạng thái "approved" | Manual |
| W10 | Kích hoạt Retrain | Bắt đầu tiến trình huấn luyện | Nhấn nút "Retrain NLU Model" | Trạng thái trên DevOps Strip chuyển sang "Training..." | Manual |

### W.4 — Bill OCR Retrain (Gán nhãn hóa đơn)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W11 | Kéo thả gán nhãn Canvas | Công cụ gán nhãn hoạt động | Kéo thả khung bao quanh "Tên cửa hàng" trên ảnh | Tọa độ bounding box và nhãn SELLER được lưu chính xác | Manual |
| W12 | Auto-label AI | Gợi ý nhãn tự động | Nhấn nút "Auto-label" trên ảnh hóa đơn | AI tự vẽ các khung dự đoán vị trí SELLER, TOTAL | Manual |
| W13 | Export dữ liệu đã duyệt | Xuất dữ liệu huấn luyện | Nhấn "Export Dataset" | File tải về dạng ZIP chứa ảnh + JSON annotation | Manual |

### W.5 — Bot Prompt & LLM Calibrator

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W14 | Chỉnh sửa System Prompt | Prompt mới có hiệu lực ngay | Đổi prompt tính cách "Vui vẻ" → Lưu | Chat thử ở Sandbox, MiMo đổi giọng theo prompt mới | `test_modal_http.py` |
| W15 | Kiểm thử Sandbox | Thử nghiệm prompt trước khi deploy | Nhập câu thử "mua cafe 35k" → Nhấn Test | Kết quả trả về ngay lập tức trong cửa sổ Sandbox | `test_modal_http.py` |
| W16 | Điều chỉnh Temperature | Kiểm soát độ sáng tạo | Tăng Temperature lên 0.9 → Test nhiều lần | Phản hồi đa dạng hơn, ít lặp | Manual |

### W.6 — Giám sát Doanh thu (Monetization)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| W17 | Biểu đồ doanh thu | Cập nhật real-time | Vào trang Monetization xem biểu đồ 30 ngày | Biểu đồ hiển thị đúng, có ngày cao điểm rõ ràng | Manual |
| W18 | Danh sách giao dịch thanh toán | Tra cứu đơn hàng | Tìm một mã đơn hàng cụ thể | Hiện đúng thông tin: tên user, số tiền, trạng thái | Manual |

---

## NHÓM AI — Kiểm thử AI Pipeline

### AI.1 — NLU Benchmark (PhoBERT vs TF-IDF vs Qwen)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| AI01 | Phân loại Intent (300 test cases) | Đo Accuracy & F1 trên tập kiểm thử | Chạy benchmark 3 mô hình trên CSV dataset | PhoBERT: Intent Acc ≥ 99%, Category F1 ≥ 90% | `tests/batch_benchmark.py` |
| AI02 | Phân loại Action Type | Kiểm tra nhận diện loại lệnh | 100 câu lệnh điều khiển (SET_LIMIT, REPORT...) | F1 Action ≥ 90% | `tests/batch_benchmark.py` |
| AI03 | Nhận diện Income vs Expense | Phân biệt thu / chi | 50 câu thu nhập, 50 câu chi tiêu | Record Type F1 ≥ 95% | `tests/batch_benchmark.py` |
| AI04 | Đo Latency PhoBERT | Đảm bảo < 2 giây | Đo thời gian trung bình trên 300 câu | Avg Latency < 200ms (local model) | `tests/batch_benchmark.py` |
| AI05 | Regression test NLU fixes | Không tái hồi phục lỗi cũ | Chạy 17 test cases đã fix trước đây | 100% PASS (không tái hồi lỗi) | `tests/test_nlu_fixes.py` |
| AI06 | NLU thiếu slot (missing slot) | AI hỏi lại thay vì báo lỗi | Gửi 5 câu thiếu số tiền lên Modal HTTP | Mỗi câu trả về yêu cầu bổ sung số tiền | `tc_nlu_missing_slot.py` |
| AI07 | Test 4 tính cách Persona | MiMo thể hiện đúng giọng điệu | Gửi cùng 1 câu với 4 persona khác nhau | Phản hồi khác biệt rõ ràng theo từng tính cách | `test_modal_http.py` |

### AI.2 — OCR/KIE Pipeline

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| AI08 | KIE Baseline Regex | Xác nhận giới hạn của Regex | Chạy baseline trên văn bản OCR mẫu | SELLER F1 ≈ 52%, TIMESTAMP ≈ 78%, TOTAL ≈ 64% | `test_kie_baseline.py` |
| AI09 | LayoutLMv3 vs Baseline | So sánh mô hình mới vs cũ | Đối chiếu số liệu LayoutLMv3 từ tập validation | LayoutLMv3 SELLER ≥ 88%, TOTAL ≥ 85%, Macro F1 ≥ 90% | Số liệu benchmark sẵn |

---

## NHÓM BE — Kiểm thử Backend Node.js (Unit Tests)

| Mã | File Test | Mục đích kiểm thử | Chạy bằng | Kết quả mong đợi |
|----|----------|------------------|-----------|-----------------|
| BE01 | `action.service.test.js` | Hàm xử lý REPORT, SEARCH, SET_LIMIT với mock DB | `npm test` | Tất cả assert PASS |
| BE02 | `ai.service.test.js` | Sliding window context, fallback text khi LLM trống, RAG profile | `npm test` | Tất cả assert PASS |
| BE03 | `budgetCalibrate.test.js` | Quy tắc 50% Needs, gợi ý ngân sách đúng danh mục | `npm test` | Tất cả assert PASS |
| BE04 | `transactions.schema.test.js` | Validation schema (walletId, amount > 0, type default) | `npm test` | Tất cả assert PASS |
| BE05 | `goalFuzzy.test.js` | Fuzzy matching tên mục tiêu tiết kiệm | `npm test` | Tất cả assert PASS |
| BE06 | `billRetrainStore.test.js` | Logic lưu và quản lý queue hóa đơn cần retrain | `npm test` | Tất cả assert PASS |
| BE07 | `retrainReadiness.test.js` | Tính toán % ngưỡng sẵn sàng retrain | `npm test` | Tất cả assert PASS |

---

## NHÓM DB — Kiểm thử Cơ sở dữ liệu (CockroachDB)

| Mã | Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|-----------|------------------|--------------------|--------------------|-----------|
| DB01 | Ghi giao dịch và đọc lại | Dữ liệu không mất sau khi lưu | Tạo giao dịch → Đọc lại bằng API lịch sử | Giao dịch xuất hiện đúng số tiền, category, thời gian | `tc04_backend_api.js` |
| DB02 | Tính toán số dư sau mỗi giao dịch | Số dư cập nhật chính xác | Thêm giao dịch chi 100.000đ vào ví | Số dư ví giảm đúng 100.000đ | `tc04_backend_api.js` |
| DB03 | Giao dịch nguyên tử (Transaction ACID) | Không có giao dịch nửa vời | Giả lập lỗi giữa chừng trong luồng tạo giao dịch | Hoặc lưu toàn bộ, hoặc rollback hoàn toàn | `tc05_idempotency.js` |
| DB04 | Toàn vẹn dữ liệu khi xóa ví | Cascade delete đúng | Xóa ví → kiểm tra giao dịch con | Giao dịch liên quan bị xóa hoặc được chuyển theo rule | Manual |

---

## NHÓM NFR — Kiểm thử Phi chức năng

### NFR.1 — Bảo mật (Security)

| Mã | Yêu cầu | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|---------|------------------|--------------------|--------------------|-----------|
| NFR01 | Rate limit đăng nhập | Ngăn brute-force mật khẩu | Gửi 10 request đăng nhập sai liên tiếp trong 10 giây | Server trả về HTTP 429 từ lần thứ 6 | `tc_idempotency_ratelimit.js` |
| NFR02 | Mật khẩu được mã hóa | Không lưu mật khẩu thô | Truy vấn trực tiếp bảng `users` trong CockroachDB | Cột `password_hash` chứa chuỗi bcrypt, không phải plaintext | `check_db.js` |
| NFR03 | JWT hết hạn | Token không dùng được sau khi hết hạn | Chờ token Access hết hạn (15 phút) → Gọi API | Server trả về HTTP 401 Unauthorized | Manual |
| NFR04 | Webhook HMAC-SHA256 | Chống giả mạo thanh toán | Gửi webhook VNPay giả không có chữ ký đúng | Server từ chối với HTTP 401 | Manual |

### NFR.2 — Độ tin cậy (Reliability)

| Mã | Yêu cầu | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|---------|------------------|--------------------|--------------------|-----------|
| NFR05 | Idempotency — không trùng giao dịch | Ngăn lưu 2 lần khi bấm đúp | Gửi 10 POST request tạo giao dịch cùng `Idempotency-Key` | DB chỉ có đúng 1 giao dịch được tạo, 9 request còn lại trả về HTTP 409 | `tc_idempotency_ratelimit.js` |
| NFR06 | Khả năng phục hồi kết nối DB | Hệ thống vẫn hoạt động khi 1 node CockroachDB lỗi | (Mô phỏng) Node DB ngừng hoạt động | Ứng dụng vẫn xử lý được từ node còn lại | Tài liệu CockroachDB |

### NFR.3 — Hiệu năng (Performance)

| Mã | Yêu cầu | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi | Tool chạy |
|----|---------|------------------|--------------------|--------------------|-----------|
| NFR07 | Latency NLU PhoBERT < 2 giây | Phản hồi AI đủ nhanh | Đo latency trung bình trên 300 câu | Avg < 200ms (local), < 2000ms (qua Modal HTTP) | `batch_benchmark.py` |
| NFR08 | Tải đồng thời 500 user (Stress test) | Hệ thống không bị nghẽn | Chạy k6 giả lập 500 Virtual Users gọi API cùng lúc | Không có timeout, error rate < 1% | `k6` tool (cần cài) |

---

## Tổng hợp Tool — Có sẵn vs Cần viết

| Tool | Vị trí | Nhóm TC | Trạng thái |
|------|--------|---------|-----------|
| `tests/batch_benchmark.py` | `expense-ocr-nlu/` | AI01-04 | ✅ Có sẵn |
| `tests/test_nlu_fixes.py` | `expense-ocr-nlu/` | AI05 | ✅ Có sẵn |
| `test_modal_http.py` | `expense-ocr-nlu/` | AI07, W14-15 | ✅ Có sẵn |
| `test_kie_baseline.py` | `expense-ocr-nlu/` | AI08 | ✅ Có sẵn |
| `test_bill_insert.js` | `app/backend/` | A14-15 | ✅ Có sẵn |
| `npm test` (Jest) | `app/backend/` | BE01-07 | ✅ Có sẵn |
| `check_db.js` | `app/backend/` | NFR02 | ✅ Có sẵn |
| `tc_nlu_missing_slot.py` | `tests_chuong4/` | A10, AI06 | 🔧 Cần viết |
| `tc04_backend_api.js` | `tests_chuong4/` | DB01-02 | 🔧 Cần viết |
| `tc_idempotency_ratelimit.js` | `tests_chuong4/` | NFR01, NFR05, DB03 | 🔧 Cần viết |
| `tc_ban_unban.js` | `tests_chuong4/` | W05-06 | 🔧 Cần viết |

---

## Lệnh chạy theo thứ tự thu số liệu

```bash
# Bước 1 — Unit Tests Backend (Jest) — khoảng 30 giây
cd d:\Luan-Van\Project\app\backend
npm test 2>&1 | Tee-Object results\be_unit_test.txt

# Bước 2 — NLU Benchmark (cần model local) — khoảng 2-5 phút
cd d:\Luan-Van\Project\expense-ocr-nlu
python -m tests.batch_benchmark

# Bước 3 — NLU Regression
python tests/test_nlu_fixes.py

# Bước 4 — KIE Baseline
python test_kie_baseline.py

# Bước 5 — Modal HTTP (AI cloud — serverless, tự tắt)
python test_modal_http.py

# Bước 6 — Các tool cần viết thêm
cd d:\Luan-Van\Project\tests_chuong4
python tc_nlu_missing_slot.py
node tc04_backend_api.js
node tc_idempotency_ratelimit.js
node tc_ban_unban.js
```
