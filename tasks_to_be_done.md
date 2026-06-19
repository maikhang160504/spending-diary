# Bill Retrain — Brainstorm & Implementation Plan

> Cập nhật: 2026-06-19 · Nguồn yêu cầu gốc (4 mục) + hiện trạng codebase

---

## Tổng quan kiến trúc liên quan

```
WebAdmin /bill-retrain
  → backend (billRetrainStore + admin.routes)
  → ai-service (bill_retrain_service → hybrid_pipeline)
  → expense-ocr-nlu/OCR (Paddle+VietOCR → parallel KIE → fusion)
  → Kaggle retrain (LayoutLMv3 / VietOCR kernels)
```

---

## Hiện trạng (đã làm / chưa làm)

| # | Yêu cầu | Trạng thái | Ghi chú |
|---|---------|------------|---------|
| 1 | Tiến độ Kaggle + thông báo hoàn thành | **Done** | Stepper, toast, badge global sidebar/topbar |
| 2 | Xóa nhãn + gán thủ công kéo thả + nút Gán nhãn auto | **Done** | Canvas edit, bảng editable, Lưu nháp, Xóa nhãn, confirm auto |
| 3 | ai-service không tự tải model khi startup | **Done** | `LAZY_LOAD_MODELS=true` (default); cần restart + `.env` |
| 4 | Bug nodemon restart + ảnh không xóa + cleanup sau export | **Done** | **4.3–4.9, 4.5** Done |

---

## TASK 1 — Kaggle retrain progress & notification

### Mục tiêu
Admin thấy tiến độ train realtime trên WebAdmin và nhận thông báo khi job `completed` / `failed`.

### Đã có
- `KaggleProgressPanel` (stepper + progress bar)
- Poll job mỗi 5s; resume job đang chạy khi mở trang
- Export/trigger gửi `webhookUrl` → backend auto `reloadModels('ocr')`
- Frontend gọi `reloadAiModels` khi poll thấy `completed`

### Còn thiếu / cần làm

| ID | Task | File / vị trí | Acceptance |
|----|------|---------------|------------|
| 1.1 | **Toast notification** khi job `completed` / `failed` (không chỉ banner text) | `BillRetrainPage.jsx`, CSS | Toast xuất hiện 1 lần/job; có link "Xem job" |
| 1.2 | Hiển thị **% tiến độ** + ETA ước lượng (từ step index) | `KaggleProgressPanel` | Bar + label "Bước 3/6 — Train trên Kaggle" |
| 1.3 | Badge **"Retrain đang chạy"** trên sidebar/topbar khi có job active | `Layout.jsx` | Nhìn thấy từ mọi trang admin ✅ |
| 1.4 | **Verify webhook** từ Kaggle runner → backend (log + UI "OCR đã reload") | `kaggle_runner.py`, `admin.routes.js` | Sau job xong, pill OCR = Online + message reload |
| 1.5 | **E2E test plan** (manual checklist) | `RETRAIN.md` hoặc comment trong PR | Export → Auto Kaggle → poll → deploy → reload |

### Rủi ro
- Kaggle poll timeout / GPU queue dài → cần message "đang chờ GPU" thay vì im lặng
- Webhook không tới được localhost → doc `BILL_RETRAIN_WEBHOOK_URL` + ngrok cho dev

---

## TASK 2 — Labeling: xóa nhãn, kéo thả thủ công, Gán nhãn auto

### Thay đổi so với phiên bản trước
Yêu cầu **mới** cho phép **chỉnh tay** (không còn read-only). Auto-label vẫn là nút riêng.

### UX flow đề xuất

```
Upload ảnh → (optional) Gán nhãn auto → chỉnh bbox/entity tay → Lưu nháp → Duyệt → Export
                ↑                           ↑
         Paddle+VietOCR+LayoutLMv3    Kéo/resize/xóa box, đổi entity
```

### Task breakdown

| ID | Task | File | Acceptance |
|----|------|------|------------|
| 2.1 | Bỏ `readOnly` trên canvas; bật drag/resize | `BillLabelCanvas.jsx` | Kéo box, resize góc hoạt động |
| 2.2 | Bảng nhãn **editable** (text + entity select) | `BillRetrainPage.jsx` | Sửa text/entity cập nhật `boxes` state |
| 2.3 | Nút **Xóa nhãn** (box đang chọn) + phím Delete | Page + canvas | Xóa 1 box; confirm nếu box cuối |
| 2.4 | Nút **Thêm bbox** (vẽ vùng mới) — optional P1 | Canvas | Click-drag tạo box OTHER |
| 2.5 | Khôi phục **Lưu nháp** (`PUT /samples/:id`) | Page + `api.js` | Lưu `adminLabels` không cần duyệt |
| 2.6 | **Gán nhãn auto** giữ tách khỏi Upload | Đã có `rePrelabelBillSample` | Upload không gọi model; auto ghi đè labels |
| 2.7 | Cảnh báo trước auto-label nếu đã có nhãn tay | Modal confirm | "Ghi đè N box hiện tại?" |
| 2.8 | Hiển thị `kie_backend` + số box sau auto | Toast / meta dưới canvas | layoutlmv3 vs heuristic rõ ràng |

### Backend
- Không đổi API lớn: `PUT`, `POST .../prelabel`, `POST .../approve` đã đủ
- Validate entity ∈ `{SELLER, ADDRESS, TIMESTAMP, TOTAL_COST, OTHER}`

### Phụ thuộc
- ai-service OCR loaded (lazy load lần đầu khi auto-label)
- `hybrid_pipeline` + `receipt_fusion` (đã refactor)

---

## TASK 3 — ai-service lazy load (không tự tải model startup)

### Trạng thái: **Done**

| ID | Task | Status |
|----|------|--------|
| 3.1 | `lazy_load_models: bool = True` default | Done |
| 3.2 | Lifespan skip `try_load()` khi lazy | Done |
| 3.3 | Document `.env.example` `LAZY_LOAD_MODELS=true` | **Todo** |
| 3.4 | Verify log startup: `"Lazy load enabled"` không còn load PhoBERT/Paddle | **Verify manual** |

### Verify command
```powershell
cd app\ai-service
$env:LAZY_LOAD_MODELS='true'
$env:USE_REAL_OCR='true'
uvicorn app.main:app --port 8000
# Expect: no "Starting model loading on startup"
# First POST prelabel → models load
```

---

## TASK 4 — Bugs storage & nodemon

### 4A — Backend restart khi xóa sample (nodemon)

**Nguyên nhân:** `writeIndex()` ghi `storage/bill_retrain/samples_index.json` → nodemon watch (nếu chưa ignore).

**Đã làm:** `app/backend/nodemon.json` ignore `storage/**`

| ID | Task | Acceptance |
|----|------|------------|
| 4.1 | Confirm `npm run dev` đọc `nodemon.json` (chạy từ `app/backend`) | Xóa sample → **không** restart |
| 4.2 | Nếu vẫn restart: đổi script `"dev": "nodemon --config nodemon.json src/index.js"` | package.json |

### 4B — Xóa sample nhưng file ảnh vẫn còn trong `storage/bill_retrain/images`

**Root cause (bug trong code):**

```javascript
// billRetrainStore.deleteSample — SAI thứ tự
writeIndex(idx);           // sample đã mất khỏi index
const img = readImage(id); // getSample(id) → null → không unlink được file
```

| ID | Task | File | Fix |
|----|------|------|-----|
| 4.3 | **Đọc `imageExt` + unlink TRƯỚC khi writeIndex** | `billRetrainStore.js` | `unlink(imagePathFor(id, sample.imageExt))` |
| 4.4 | Unit test: delete → file không còn trên disk | `tests/unit/billRetrainStore.test.js` | Assert `!fs.existsSync` |
| 4.5 | Orphan scan: xóa ảnh không có trong index (admin tool / script) | `scripts/clean_bill_retrain_orphans.js` | P2 — dọn ảnh rác hiện có |

### 4C — Sau export Kaggle: xóa ảnh đã export để giải phóng disk

**Chiến lược đề xuất:**

1. Export thành công → đánh dấu sample `exportedAt` + `exportBatchId`
2. **Option A (an toàn):** Xóa file ảnh, giữ metadata index (trạng thái `exported_archived`)
3. **Option B (gọn):** Xóa hẳn sample khỏi index sau export (chỉ giữ trong dataset Kaggle)

**Khuyến nghị: Option A** — admin vẫn thấy lịch sử đã export, ảnh gốc xóa local.

| ID | Task | File | Acceptance |
|----|------|------|------------|
| 4.6 | `archiveExportedSamples(batchId)` — unlink images, set status | `billRetrainStore.js` | Sau export, `images/` giảm |
| 4.7 | Gọi archive sau `POST /bill-retrain/export` success | `admin.routes.js` | Response có `archivedImages: N` |
| 4.8 | UI: sample exported hiển thị "Đã export — ảnh đã archive" | `BillRetrainPage.jsx` | Không serve image 404 confuse |
| 4.9 | Checkbox export: "Xóa ảnh local sau export" (default **on**) | Export panel | User có thể tắt nếu muốn giữ |

---

## Thứ tự thực hiện đề xuất (sprint)

### Sprint 1 — Bugfix nhanh (0.5–1 ngày) ✅ đã làm phần core
1. **4.3** Fix deleteSample unlink ảnh ✅
2. **4.1** Verify nodemon — `package.json` dùng `--config nodemon.json` ✅ (restart backend dev để áp dụng)
3. **3.3** Doc LAZY_LOAD_MODELS trong `.env.example` ✅
4. **4.4** Unit test assert file xóa khỏi disk ✅

### Sprint 2 — Labeling UX (1–2 ngày) ✅ core done
4. **2.1–2.3, 2.5–2.8** Manual label + auto + draft ✅
5. **2.7** Confirm ghi đè auto-label ✅
6. **2.4** Vẽ bbox mới — ✅ Done

### Sprint 3 — Export cleanup + Kaggle polish (1 ngày) ✅ core done
6. **4.6–4.9** Archive ảnh sau export ✅
7. **1.1–1.2** Toast + progress polish ✅
8. **1.4** Verify webhook E2E — manual

### Sprint 4 — Optional
9. ~~**2.4** Vẽ bbox mới~~ ✅
10. ~~**4.5** Orphan cleanup script~~ ✅
11. ~~**1.3** Global retrain badge~~ ✅
12. E2E bill-demo (`OCR/tests/bill-demo`) với `USE_REAL_OCR=true`

---

## Checklist verify tổng (Definition of Done)

- [ ] Xóa sample → backend **không** restart; file trong `storage/bill_retrain/images/` **biến mất**
- [ ] Export approved → ảnh local được archive (nếu bật option); dataset Kaggle vẫn đủ
- [ ] Upload không load model; **Gán nhãn auto** load model lần đầu
- [ ] Canvas: kéo/thả, sửa entity, xóa box, lưu nháp, duyệt
- [ ] Kaggle job: stepper cập nhật; toast khi xong; OCR reload
- [ ] ai-service startup < 10s (không load Paddle/LayoutLMv3/PhoBERT)

---

## Ghi chú kỹ thuật (không nằm trong 4 task gốc nhưng liên quan)

- Pipeline OCR: `receipt_fusion.py` — OCR → parallel(KIE, prep) → fusion
- Train LayoutLMv3 **không** đi qua Paddle ở runtime train; production **có**
- Metric Kaggle cao ≠ production accuracy → xem modal Hướng dẫn `/bill-retrain`

---

## Yêu cầu gốc (reference)

1. hiển thị tiến độ retrain của kaggle trên webadmin, thông báo khi hoàn thành
2. thêm xóa nhãn, và cho gán nhãn thủ công bằng cách kéo thả, thêm 1 nút gán nhãn auto
3. mô hình ở ai-service không còn tự tải khi khởi động
4. bug nodemon restart khi xóa; bug ảnh còn sau xóa; cleanup ảnh sau export Kaggle
