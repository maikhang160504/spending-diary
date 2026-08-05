# BÁO CÁO HOÀN THÀNH KẾ HOẠCH 9

## 1. Mục tiêu
Kế hoạch 9 được thiết kế nhằm xây dựng công cụ xuất (export) dữ liệu tự động từ hệ thống để chuẩn bị cho quá trình huấn luyện tăng cường (Fine-tune) các mô hình Ngôn ngữ Lớn (LLM - cụ thể là Qwen2.5-14B) sau này. 

Dữ liệu xuất ra cần tuân thủ định dạng Alpaca/Instruct chuẩn (`instruction`, `input`, `output`).

## 2. Các công việc đã thực hiện

### 2.1. Xây dựng Script `export_finetune_data.py`
- Thay vì sử dụng bộ dữ liệu giả lập (mock data), hệ thống đã được lập trình để **kết nối trực tiếp vào CSDL PostgreSQL** của Backend (bảng `nlu_logs`).
- Script sẽ tự động lấy các ngữ cảnh giao tiếp thực tế của người dùng (những mẫu log có `log_type = 'chat'`).
- Cơ chế map dữ liệu:
  - **Instruction:** Trích xuất tự động `system_prompt` từ file `prompts.json` của kiến trúc NLU 2 tầng, để đảm bảo LLM học đúng hướng dẫn gốc.
  - **Input:** Tái tạo lại chuỗi ngữ cảnh hệ thống (thời gian, thông tin ví) kết hợp với câu thoại gốc của người dùng.
  - **Output:** Tái tạo lại chuỗi phản hồi chuẩn xác định dạng JSON do trợ lý Mimo sinh ra, bao gồm thông tin chi tiết (slots, action, intent) cũng như sắc thái cảm xúc (`emotion`) và câu trả lời tự nhiên.
- Dữ liệu được ghi ra file dưới định dạng `.jsonl` (JSON Lines).

### 2.2. Xây dựng Endpoint API
- **FastAPI (AI Service):** Thêm endpoint `POST /export-finetune`. Endpoint này khi được gọi sẽ kích hoạt (trigger) kịch bản Python bằng `subprocess` và trả về kết quả dưới dạng `FileResponse`.
- **Node.js (Backend):** Thêm API proxy `POST /api/admin/train/export-finetune`. API này sử dụng stream (pipe) để đẩy trực tiếp tệp từ AI Service về trình duyệt mà không cần lưu trữ trung gian trên RAM của server Node.js.

### 2.3. Tích hợp Giao diện WebAdmin
- Cập nhật trang `NluOpsPage.jsx`.
- Tại khu vực điều khiển "Fine-tune Qwen2.5-14B", một nút chức năng **Xuất JSONL** đã được thêm vào.
- Khi nhấn vào nút này, dữ liệu sẽ được tự động xử lý và trình duyệt sẽ tải về máy dưới tên file `dataset_finetune.jsonl`.
- Bổ sung cơ chế khóa nút bấm (disable) khi đang thực hiện các tác vụ nền, và hiển thị Toast thông báo trạng thái.

## 3. Ứng dụng cho Luận Văn
- Cơ chế xuất dữ liệu tự động này minh chứng cho vòng lặp phát triển liên tục (Continuous Improvement) của hệ thống Mimo.
- Nó cho phép quản trị viên thu thập và tận dụng dữ liệu người dùng thật một cách bảo mật và nhanh chóng để liên tục tinh chỉnh năng lực (fine-tune) cho trợ lý ảo nội bộ.
