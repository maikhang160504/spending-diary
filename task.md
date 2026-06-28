# Task List — Sửa lỗi & Cải thiện Hệ thống Mimo Chat

> Tham chiếu: [implementation_plan.md](file:///C:/Users/LENOVO/.gemini/antigravity-ide/brain/b29a6cfe-3826-424d-9e8f-1cf1776f3fdd/implementation_plan.md)
> Báo cáo audit: [dataset_audit_results.md](file:///C:/Users/LENOVO/.gemini/antigravity-ide/brain/b29a6cfe-3826-424d-9e8f-1cf1776f3fdd/dataset_audit_results.md)

---

## Phase 1: Cải thiện Dataset ✅ (phần lớn)

### 1.1 Audit & Clean intent_action.csv
- [x] Phân tích phân phối `action_type` hiện tại → 13 types, 150K rows
- [x] Xóa tất cả row `UPDATE_RECORD`, `DELETE_RECORD` → xóa 3,622 rows
- [x] Xóa mẫu trùng lặp (dedup) → xóa 103,825 rows (150K→42K)
- [x] Bổ sung slot `categoryCode` cho `REPORT_GENERAL` → đã có 77% (7,647/9,925)
- [x] Bổ sung/sửa mẫu `SEARCH_RECORD` → 3,122 rows, 100% có query, 81% có category_code
- [x] Bổ sung mẫu `SUGGEST_BUDGET` → đã có 1,539 mẫu
- [ ] Cân bằng số lượng mẫu giữa các `action_type` (max/min = 8x)

### 1.2 Audit & Clean intent_chitchat.csv
- [x] Kiểm tra và xóa mẫu trùng lặp → xóa 5 rows (22,192→22,187)
- [x] Phân tích chủ đề → Neutral: 11K, Positive: 6.7K, Negative: 4.5K
- [ ] Bổ sung mẫu tự nhiên hơn (gen hoặc viết tay)

### 1.3 Audit & Clean intent_record.csv
- [x] Kiểm tra và xóa mẫu trùng lặp → xóa 73 rows (212,837→212,764)
- [x] Phân tích phân phối danh mục → 18 categories, cân bằng tốt
- [x] Fix type casing: 'Expense' → 'expense' (1 row)
- [ ] Bổ sung mẫu đa dạng income (chỉ 17%)

### 1.4 Tạo Unified Fine-tune Dataset
- [x] Thiết kế format dataset → JSONL Alpaca-style
- [x] Gộp 3 dataset → 277,680 records, 163 MB (`unified_finetune.jsonl`)
- [x] Intent label rõ ràng: Record/Action/Chitchat
- [x] Bao gồm slot/entity extraction trong output
- [ ] Validate dataset (kiểm tra edge cases)

---

## Phase 2: Sửa Logic AI-Service ✅ (phần lớn)

### 2.1 Sửa action_executor.py
- [x] Xóa handler `UPDATE_RECORD`, `DELETE_RECORD`, `Edit`
- [x] Bổ sung `categoryCode` vào handler `REPORT_GENERAL`
- [x] Cải thiện handler `SEARCH_RECORD` — multi-filter, trả danh sách
- [x] Thiết kế logic `REPORT_COMPARE`, `SUGGEST_BUDGET`, `SET_ALERT`, `SET_INCOME`

### 2.2 Sửa pipeline.py & action_slots.py
- [x] Xóa ref `UPDATE_RECORD` trong action_slots.py
- [x] Thêm LLM fallback vào pipeline.py
- [x] Cập nhật `intent_backend` logic

### 2.3 Thêm LLM Local Handler
- [x] Tạo `src/nlu/llm_intent_handler.py` — classify intent + extract slots
- [x] Implement fallback logic: encoder → LLM khi confidence < 0.65
- [x] Tạo prompt riêng cho intent classification
- [x] Tạo prompt riêng cho slot extraction (action + record)

### 2.4 Cập nhật Prompts
- [x] Thêm prompt intent classification vào `prompts.json`
- [x] Thêm prompt slot extraction vào `prompts.json`
- [ ] Test prompts với các câu mẫu

---

## Phase 3: Xóa luồng Train/Retrain OCR trên Kaggle ✅ (phần lớn)

### 3.1 Xóa code Kaggle OCR
- [x] Xóa Kaggle OCR functions trong `bill_retrain_service.py`
- [x] Xóa Kaggle OCR router endpoints trong `bill_retrain.py`
- [ ] Review `kaggle_nlu_service.py` — tách phần OCR retrain ra khỏi NLU retrain
- [ ] Review & xóa `sync_kaggle_output.py`, `sync_nlu_kaggle.py`

### 3.2 Tạo luồng train local
- [ ] Refactor → train local/Docker (cần khi triển khai thực tế)
- [ ] Tạo script lưu ảnh export → dataset gốc
- [ ] Document flow train mới

---

## Phase 4: Gộp expense-ocr-nlu vào ai-service (chưa bắt đầu)

### 4.1 Phân tích dependency
- [ ] Liệt kê tất cả import path từ ai-service → expense-ocr-nlu
- [ ] Xác định module nào cần migrate
- [ ] Kiểm tra requirements.txt — gộp dependencies

### 4.2 Migrate code
- [ ] Di chuyển `src/nlu/` → `app/ai-service/app/nlu/`
- [ ] Di chuyển `src/llm/` → `app/ai-service/app/llm/`
- [ ] Di chuyển `src/nlg/` → `app/ai-service/app/nlg/`
- [ ] Di chuyển `src/prompts/` → `app/ai-service/app/prompts/`
- [ ] Di chuyển `OCR/` → `app/ai-service/app/ocr/`

### 4.3 Cập nhật imports & adapter
- [ ] Cập nhật tất cả import path
- [ ] Xóa hoặc simplify adapter layer
- [ ] Cập nhật Dockerfile
- [ ] Chạy test verify

---

## Phase 5: Gộp MC_OCR + Clean up (chưa bắt đầu)

### 5.1 Bổ sung flow gán nhãn tự động
- [ ] Tạo prompt LLM cho gán nhãn sản phẩm hóa đơn
- [ ] Tạo prompt LLM cho nhận dạng `categoryCode` bill
- [ ] Tích hợp bộ lọc sản phẩm cũ → LLM gán nhãn
- [ ] Tích hợp vào pipeline MC_OCR

### 5.2 Gộp & đổi tên MC_OCR
- [ ] Đổi tên thư mục cho phù hợp
- [ ] Gộp/clean cấu trúc
- [ ] Xóa file không cần thiết (.git riêng, zip, file tạm)
- [ ] Verify: flow train + demo trích xuất vẫn OK

### 5.3 Clean up toàn project
- [ ] Xóa file backup, log, pycache
- [ ] Cập nhật .gitignore
- [ ] Review & xóa script dataset generation thừa

---

## Tiến độ Tổng quan

| Phase | Hoàn thành | Tổng | % |
|-------|-----------|------|---|
| Phase 1 — Dataset | 13 | 17 | 76% |
| Phase 2 — Logic AI-Service | 11 | 12 | 92% |
| Phase 3 — Xóa Kaggle OCR | 2 | 7 | 29% |
| Phase 4 — Gộp expense-ocr-nlu | 0 | 10 | 0% |
| Phase 5 — Gộp MC_OCR + Clean | 0 | 12 | 0% |
| **Tổng** | **26** | **58** | **45%** |
