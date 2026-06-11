# MoneyStory (Expense AI) — Fullstack Expense Management with AI

Hệ thống quản lý chi tiêu cá nhân thông minh tích hợp AI hỗ trợ nhận dạng tự động: NLU văn bản tiếng Việt, OCR hóa đơn, trích xuất thương hiệu, bình luận từ linh vật (Mascot) Mimo và phân tích chi tiêu chuyên sâu.

## Cấu trúc Thư mục Dự án

```text
root/
├── app/
│   ├── ai-service/          FastAPI microservice nhận dạng (NLU + OCR + Merchant Extraction)
│   ├── backend/             Node.js/Express REST API (Quản lý User, Ví, Giao dịch, Định kỳ)
│   ├── database/            CSDL PostgreSQL/CockroachDB schema & migrations
│   └── frontend/
│       ├── mobile/          Flutter Mobile App (Android/iOS)
│       └── web-admin/       React + Vite Admin Dashboard
├── expense-ocr-nlu/         Mô hình & weights của NLU & OCR gốc (PaddleOCR + VietOCR + PhoBERT)
└── README.md
```

## Luồng Hoạt Động AI

1. **Xử lý Đầu vào**: 
   - **Giọng nói (STT)**: Chuyển giọng nói tiếng Việt thành văn bản trên mobile kèm chuẩn hóa từ lóng tiền tệ Việt Nam (`cành`, `lít`, `củ`, `xị`...) về số.
   - **Quét Hóa đơn (OCR)**: Chuyển ảnh hóa đơn thành text, trích xuất tổng tiền, gợi ý danh mục và nhận diện thương hiệu.
   - **Gộp Logic (Fusion)**: Ghi chú bằng giọng nói đè lên kết quả OCR hóa đơn mà vẫn giữ nguyên số tiền gốc.

2. **Insight Engine**:
   - Gợi ý hạn mức chi tiêu thông minh theo mùa vụ (Seasonal Adjustment Factor - hệ số lễ Tết) và lọc nhiễu 3-sigma.
   - Chống trùng lặp hành động trên client (Idempotency Guards).

3. **Bình luận Mascot**:
   - Mascot Mimo bình luận về chi tiêu của người dùng theo 2 vibe nói chuyện (Dui Dẻ - funny vs Dận Dữ - strict) kèm sticker cảm xúc.

4. **Trực quan Hóa Báo cáo**:
   - Biểu đồ tròn phân tích danh mục.
   - Biểu đồ cột nhóm so sánh chi tiêu tháng này với tháng trước (MoM).
   - Biểu đồ đường lũy kế chi tiêu thực tế so với ngân sách hạn mức tháng.

## Cách Khởi Chạy Dự Án Local

### 1. Cơ sở Dữ liệu & Backend Node.js
```bash
cd app/backend
npm install
npm run migrate      # Chạy các migration SQL (bao gồm user_settings, recurring_rules)
npm run seed         # Khởi tạo dữ liệu mẫu (demo@money.local / demo1234)
npm run dev          # Chạy dev server tại http://localhost:4000
```
*Tài liệu Swagger API có tại `http://localhost:4000/docs`.*

### 2. AI Service (Python FastAPI)
```bash
cd app/ai-service
python -m venv .venv
# Kích hoạt venv (Windows: .venv\Scripts\activate)
pip install -r requirements.txt
# Copy file .env.example -> .env và chỉnh sửa
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 3. Mobile App (Flutter)
```bash
cd app/frontend/mobile
flutter pub get
flutter run
```

### 4. Admin Dashboard (React)
```bash
cd app/frontend/web-admin
npm install
npm run dev
```

## Các Tính Năng Mới Cập Nhật

### 1. Giao dịch Định kỳ (Recurring Transactions)
- Tự động tạo giao dịch định kỳ theo ngày/tuần/tháng theo cấu hình của người dùng.
- Bắn thông báo real-time qua WebSocket và gửi tin nhắn Mimo khi giao dịch được tự động ghi nhận.
- Giao diện quản lý quy tắc định kỳ chuyên nghiệp trong Cài đặt của Mobile App.

### 2. Trích Xuất Thương Hiệu (Merchant Extraction)
- Tự động nhận dạng thương hiệu Việt Nam phổ biến (WinMart, Grab, Circle K, Phúc Long, Highlands...) khi quét hóa đơn để điền trực tiếp vào Ghi chú giao dịch.

### 3. Biểu đồ Phân tích Nâng cao
- Thống kê chi tiêu MoM theo từng danh mục.
- Line Chart so sánh chi tiêu lũy kế so với ngân sách hạn mức để ngăn ngừa chi tiêu quá nhanh ở đầu tháng.
