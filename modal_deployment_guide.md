# Hướng dẫn chuyển đổi và triển khai Modal bằng tài khoản khác

Vì hệ thống AI (xử lý OCR, nhận diện biên lai và chatbot LLM) của dự án đang chạy serverless trên nền tảng **Modal**, khi bạn muốn chuyển sang một tài khoản Modal khác để sử dụng, bạn sẽ cần thiết lập lại bộ nhớ (Storage Volume) cũng như các khoá bí mật (Secret Keys).

Dưới đây là các bước chi tiết để thực hiện.

---

## Bước 1: Đăng xuất và cấu hình lại tài khoản Modal mới

Mặc định, CLI của Modal lưu token đăng nhập trên máy của bạn. Bạn cần chạy lệnh sau để ghi đè token cũ bằng token của tài khoản mới:

```bash
# Trỏ vào thư mục chứa code AI
cd d:\Luan-Van\Project\expense-ocr-nlu

# Sinh token mới
modal token new
```

Lệnh này sẽ mở trình duyệt để bạn đăng nhập vào tài khoản Modal mới. Sau khi đăng nhập và xác thực thành công, Terminal sẽ lưu lại thông tin kết nối mới.

---

## Bước 2: Khởi tạo Secret Keys (Khoá bảo mật)

Ứng dụng yêu cầu khóa API (HuggingFace) để chạy các mô hình AI. Modal cho phép bảo mật các key này thông qua tính năng **Modal Secrets**.

Có 2 cách để thiết lập:

### Cách 1: Tự động qua file `.env` (Khuyên dùng)
Trong file `modal_app.py`, hệ thống đã được thiết kế để tự động nạp các key từ file `.env` ở máy trạm lên Modal khi bạn chạy lệnh deploy.
Hãy mở file `d:\Luan-Van\Project\expense-ocr-nlu\.env` và cập nhật lại API Key bằng tài khoản mới của bạn:
```env
HF_TOKEN=HUGGINGFACE_TOKEN_CUA_BAN
```
Khi bạn chạy lệnh deploy (ở bước sau), Modal sẽ tự mang các key này lên đám mây.

### Cách 2: Thiết lập tay trên Dashboard Modal
Nếu bạn không muốn lưu token ở máy tính, bạn có thể tạo secret trực tiếp:
1. Đăng nhập vào trang quản trị: [modal.com/secrets](https://modal.com/secrets)
2. Bấm **Create Secret** -> Chọn **Custom**.
3. Đặt tên Secret là: `gemini-secrets` *(Bắt buộc phải đúng tên này vì `modal_app.py` đang tham chiếu đến nó).*
4. Thêm các biến môi trường sau:
   - `HF_TOKEN`

---

## Bước 3: Về vấn đề Lưu trữ (Storage Volume)

Trong `modal_app.py`, ứng dụng đang gọi đến một Storage Volume tên là `expense-ocr-nlu-storage`:
```python
volume = modal.Volume.from_name("expense-ocr-nlu-storage", create_if_missing=True)
```
**Modal sẽ tự động tạo một volume trống mới với tên này** ở tài khoản mới của bạn.
> [!WARNING]
> Vì đây là tài khoản mới, Volume này sẽ trống, có nghĩa là các trọng số (weights) của mô hình Qwen, OCR hay LayoutLMv3 mà bạn từng lưu ở tài khoản cũ sẽ không tự động chuyển sang. 

Để tiết kiệm thời gian (không phải train lại) và giữ nguyên các mô hình đã fine-tune, bạn có thể **tải (download)** dữ liệu từ Modal cũ về máy, sau đó **đẩy (upload)** lên Modal mới.

*(Lưu ý: Bỏ qua thư mục `qwen_vismimo` chứa mô hình 28GB vì tải về rất lâu, thay vào đó ta sẽ dùng lệnh tải lại trực tiếp từ đám mây trên tài khoản mới. Đồng thời không tải về các file liên quan đến PhoGPT vì đã bị loại bỏ khỏi dự án).*

**Thực hiện theo trình tự sau:**

1. **Khi ĐANG Ở tài khoản Modal CŨ:**
   Mở terminal và tải các dữ liệu cần thiết về máy:
   ```bash
   # Tạo thư mục chứa backup
   mkdir modal_backup
   mkdir modal_backup\layoutlmv3
   mkdir modal_backup\exported
   mkdir modal_backup\qwen_vismimo_lora
   mkdir modal_backup\nlu_models
   
   # Tải các trọng số và dữ liệu quan trọng
   modal volume get expense-ocr-nlu-storage model_best.pth modal_backup/
   modal volume get expense-ocr-nlu-storage layoutlmv3/* modal_backup/layoutlmv3/
   modal volume get expense-ocr-nlu-storage exported/* modal_backup/exported/
   modal volume get expense-ocr-nlu-storage qwen_vismimo_lora/* modal_backup/qwen_vismimo_lora/
   modal volume get expense-ocr-nlu-storage nlu_models/* modal_backup/nlu_models/
   ```

2. **Chuyển sang tài khoản Modal MỚI:**
   Chạy lệnh để đăng nhập tài khoản mới (như Hướng dẫn ở Bước 1):
   ```bash
   modal token new
   ```

3. **Upload dữ liệu từ máy tính lên Modal MỚI:**
   Đẩy các tệp đã backup lên Storage của tài khoản mới:
   ```bash
   modal volume put expense-ocr-nlu-storage modal_backup/model_best.pth /
   modal volume put expense-ocr-nlu-storage modal_backup/layoutlmv3 /
   modal volume put expense-ocr-nlu-storage modal_backup/exported /
   modal volume put expense-ocr-nlu-storage modal_backup/qwen_vismimo_lora /
   modal volume put expense-ocr-nlu-storage modal_backup/nlu_models /
   ```

4. **Tải lại mô hình Base Qwen (Thay vì upload file 28GB):**
   Bạn chạy lệnh sau để kéo trực tiếp mô hình Qwen gốc từ HuggingFace về ổ cứng của Modal mới:
   ```bash
   modal run modal_app.py::reset_storage_to_base_qwen
   ```

---

## Bước 4: Deploy (Triển khai ứng dụng)

Sau khi đã nạp lại tài khoản và đảm bảo các key đã đúng, tiến hành đưa ứng dụng lên tài khoản Modal mới:

```bash
modal deploy modal_app.py
```

- Hệ thống sẽ build lại Docker Image (có thể mất một chút thời gian vì nó cần cài lại PyTorch, OpenCV, tải `vinai/phobert-base`,...).
- Sau khi build xong, Terminal sẽ hiển thị đường link webhook của FastAPI dưới dạng `https://<ten-user>--expense-ocr-nlu-fastapi-app.modal.run`.

---

## Bước 5: Cập nhật URL mới vào Backend

Link FastAPI được sinh ra ở tài khoản mới sẽ khác hoàn toàn với tài khoản cũ. Vì vậy, bạn **phải copy đường dẫn này** và dán vào file cấu hình môi trường của Backend NodeJS.

Mở file `d:\Luan-Van\Project\app\backend\.env`:
```env
AI_SERVICE_URL=https://<duong-dan-moi-vua-copy>
```
Sau đó khởi động lại Backend NodeJS (lệnh `npm run dev`) để Backend bắt đầu kết nối đến con AI ở tài khoản Modal mới của bạn.
