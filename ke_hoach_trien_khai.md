# Kế hoạch triển khai: Chuyển đổi kiến trúc NLU → Intent Classifier + Qwen2.5 LLM

> Tài liệu này đủ chi tiết để agent mới đọc và triển khai đúng mà không cần làm lại từ đầu.
> Tất cả phân tích chi tiết nằm ở: `phan_tich_kien_truc_intent_llm.md` (cùng thư mục).

---

## Tổng quan kiến trúc

### Trước (as-is)
```
User text
  → pipeline.py
    ├── backend = "tfidf/encoder": TF-IDF / PhoBERT → intent + category + action_type + slots
    └── backend = "llm": UNIFIED_NLU_PROMPT (1 lần gọi LLM, ~91 dòng)
          Ưu tiên: Qwen Modal → Qwen local → Gemini (fallback cuối)
```

### Sau (to-be)
```
User text + caller_context (chat | addstory)
  → Stage 1: Intent Classifier (1 trong 3 model được chọn trên WebAdmin: TF-IDF | Encoder | LLM Qwen)
      ├── confidence ≥ 0.65: lấy kết quả
      └── confidence < 0.65: majority vote (TF-IDF + PhoBERT + LLM Qwen classify)
      ├── caller_context = "addstory": bỏ qua Stage 1, intent = Record luôn
  → Stage 2: Xử lý theo intent (hai luồng tách biệt)
      ├── Action / Chitchat → Gọi LLM Qwen với ACTION_RULE hoặc CHITCHAT_RULE
      │     + Persona injection + Relationship injection + Context metadata
      │     → LLM trả JSON chuẩn (action_type, slots, emotion, response)
      └── Record → Category Classification + NLG Response
            ├── Backend chính: 1 trong 3 model được chọn trên WebAdmin
            │     ├── TF-IDF: classify category → sau đó gọi LLM sinh response/emotion
            │     ├── Encoder/PhoBERT: classify category → sau đó gọi LLM sinh response/emotion
            │     └── LLM Qwen: dùng RECORD_RULE, vừa classify category vừa sinh response (1 lần gọi)
            └── Output: JSON chuẩn (record_type, category, amount, item, emotion, response)
```

### Nguyên tắc bất biến
- Backend Node.js KHÔNG thay đổi logic (nhận cùng format JSON output).
- OCR pipeline (LayoutLMv3) KHÔNG liên quan, KHÔNG thay đổi.
- Không còn Gemini ở bất kỳ đâu trong codebase.
- Train NLU 2 tầng: Stage 1 (Intent) và Stage 2 (Category cho Record). Các task phức tạp (record_type, action_type, slots, NER) do LLM Qwen xử lý.
- **An toàn đồng thời (Concurrency & Multi-tenancy Safety):** Mọi request xử lý LLM trong FastAPI đều là **stateless**. Toàn bộ ngữ cảnh cá nhân hóa (`user_name`, `relationship_rules`, `budget_remain`, `caller_context`) chỉ được lưu trong scope của HTTP request, tuyệt đối không dùng biến toàn cục để tránh nhầm lẫn dữ liệu giữa nhiều người dùng.
- **Dữ liệu train sạch:** Dữ liệu train lấy từ MongoDB được lọc tự động các mẫu sai (bị đánh dấu qua nút `dislike` trên app với `is_intent_wrong=true`).


---

## HƯỚNG DẪN THỰC THI CHO AI AGENT (BẮT BUỘC ĐỌC TRƯỚC KHI CODE)

> **QUY TẮC VÀNG:** Tài liệu này cung cấp định hướng kiến trúc, luồng logic mới và tiêu chí kiểm thử. Tuy nhiên, **trước khi viết hoặc sửa bất kỳ dòng code nào**, Agent **BẮT BUỘC phải dùng tool `view_file` hoặc `read_file` để đọc trực tiếp file source code gốc hiện tại** nhằm nắm đúng số dòng, tên hàm và context xung quanh, TUYỆT ĐỐI KHÔNG đoán số dòng hay làm lại từ đầu.

### 1. Quy định triển khai
- **Triển khai tuần tự từng kế hoạch:** Khi người dùng yêu cầu (ví dụ: *"Triển khai KH1"* hoặc *"Làm KH2"*), chỉ tập trung làm dứt điểm và test cho Kế hoạch đó, không gộp sửa nhiều Kế hoạch cùng một lúc.
- **Tuân thủ đúng thứ tự ưu tiên:** Luôn hoàn thành KH1 (Xóa Gemini) trước tiên để làm sạch nền tảng, sau đó mới sang KH2 (Tạo rule JSON) và KH3 (Kết nối Pipeline).

### 2. Danh sách các file phức tạp BẮT BUỘC ĐỌC KỸ trước khi sửa

| File code nguồn | Cần chú ý gì khi đọc trước khi sửa |
|---|---|
| `src/nlu/llm_intent_handler.py` | Đọc cấu trúc hàm `run_llm_nlu()` và `_call_llm()` hiện tại, cách parse JSON và xử lý lỗi để viết hàm `run_llm_nlu_v2()` và inject rule/persona chính xác. |
| `src/nlu/pipeline.py` | Đọc luồng `if/else backend` trong `run_nlu()` để chèn đúng điểm gọi `llm_v2`, xử lý shortcut `caller_context == "addstory"` và logic majority vote. |
| `src/api/app/adapters/expense_ocr_nlu.py` | Đọc hàm `_load_nlu_bundle_unlocked()` để nắm danh sách model đang load, thêm `llm_rules.json` và chèn logic so sánh `mtime` giữa workspace vs `/storage`. |
| `src/api/app/routers/nlu.py` | File router rất dài, cần đọc đúng vị trí các endpoint `/nlu/infer`, `/nlu/test-prompt`, `/nlu/train/status` và thêm endpoint `/nlu/benchmark/llm-rules`. |
| `NluOpsPage.jsx` | Đọc kỹ cấu trúc layout của component trước khi xóa block Import CSV / Auto-retrain và thêm thanh tiến trình 6 stage, badge model mới, bảng benchmark LLM. |
| `src/prompts/prompts.json` | Đọc cấu trúc hiện tại để khi xóa các prompt cũ không làm mất/sai cấu trúc của key `emotions` và `relationship_override`. |

---

### 3. Nguyên tắc kiến trúc giải quyết 3 thách thức cốt lõi

#### 3.1. An toàn đồng thời nhiều người dùng trong luồng 2 tầng (Stateless Concurrency)
- **Vấn đề:** Khi hàng nghìn người dùng gửi truy vấn NLU đồng thời, luồng 2 tầng (Stage 1 Intent + Stage 2 Extraction/NLG) có rủi ro bị nhầm lẫn dữ liệu hoặc chéo hội thoại nếu xử lý theo dạng có nhớ trạng thái.
- **Giải pháp kỹ thuật:**
  - **Cô lập phạm vi yêu cầu (Request Scope):** Mỗi truy vấn `POST /api/v1/nlu/infer` khởi tạo một đối tượng yêu cầu hoàn toàn độc lập, có gắn `request_id`, `user_id` và `profile` riêng biệt.
  - **Tập luật bộ nhớ chỉ đọc (Read-only rules):** Các cấu hình trong `llm_rules.json` và `prompts.json` được nạp vào bộ nhớ đệm chéo dưới dạng chỉ đọc (thread-safe), không được phép chứa biến toàn cục lưu trạng thái người dùng.
  - **Phi trạng thái tuyệt đối:** Các hàm như `run_llm_nlu_v2()` không lưu thông tin lịch sử của người dùng này vào biến chung, giúp cho các tiến trình chạy song song trên đám mây Modal bảo đảm 100% không nhầm lẫn giữa các người dùng.

#### 3.2. Cơ chế lọc dữ liệu báo cáo cho RAG theo ví cá nhân và ví chung
- **Vấn đề:** Lấy dữ liệu báo cáo tại màn hình Chat cho "Ví cá nhân" và "Ví chung" có cơ chế lọc và ngữ cảnh khác nhau, dễ gây sai lệch số liệu khi đưa vào prompt RAG.
- **Giải pháp kỹ thuật:**
  - **Bắt ý định tại NLU Stage 2:** Tầng NLU trích xuất ý định `REPORT_GENERAL`, `REPORT_COMPARE` hoặc `SEARCH_RECORD` cùng khoảng thời gian (`time_range`) và danh mục (`category`).
  - **Lọc theo vùng ví tại Backend Node.js:**
    - **Ví cá nhân:** Lọc giao dịch theo `user_id = current_user` và `wallet_id = personal_wallet_id`.
    - **Ví chung (Group Wallet):** Lọc toàn bộ giao dịch theo `wallet_id = group_wallet_id` (tất cả thành viên), gom nhóm tổng chi và tỷ lệ đóng góp của từng thành viên (`by_member`).
  - **Tăng cường truy xuất cho RAG (Dynamic Structured RAG):** Bảng số liệu thô (cá nhân hoặc nhóm) được gửi sang LLM để sinh lời bình NLU, đánh giá sức khỏe tài chính và cảnh báo lạm chi một cách khách quan, không bị ảo giác số liệu.
  - **Hiển thị bong bóng tin nhắn:**
    - **Ý định RAG (REPORT, COMPARE, SEARCH):** Hiển thị 3 bong bóng tin nhắn (Bong bóng 1: Lời thoại NLU -> Bong bóng 2: Bảng/biểu đồ dữ liệu động -> Bong bóng 3: Lời nhận xét phân tích từ RAG).
    - **Ý định thường (SET_GOAL, SET_LIMIT...):** Hiển thị 2 bong bóng tin nhắn (Bong bóng 1: Lời thoại Mimo -> Bong bóng 2: Thẻ xác nhận hành động).

#### 3.3. Quy trình duyệt mô hình 3 trạng thái (Cũ - Hiện tại - Mới) trên WebAdmin
- **Vấn đề:** Khi huấn luyện xong mô hình mới, nếu áp dụng trực tiếp có thể gây lỗi hệ thống nếu mô hình mới kém chất lượng hơn mô hình đang chạy.
- **Giải pháp kỹ thuật:**
  - **Quy tắc 3 trạng thái (3-State Lifecycle):** Hệ thống duy trì đồng thời 3 mốc mô hình: **Mô hình cũ (Old)** để phục hồi dự phòng, **Mô hình hiện tại (Current / Active)** đang phục vụ suy luận, và **Mô hình mới (New / Candidate)** vừa hoàn tất huấn luyện.
  - **Cơ chế duyệt áp dụng trên WebAdmin (NluOpsPage):**
    - Trang WebAdmin hiển thị bảng so sánh các chỉ số (`F1 Macro`, `Accuracy`, `Latency`) giữa mô hình Mới và mô hình Hiện tại.
    - Tích hợp nút **"Duyệt áp dụng mô hình mới"**: Khi quản trị viên xác nhận duyệt, hệ thống dịch vị nhãn trạng thái (Hiện tại -> Cũ, Mới -> Hiện tại, và loại bỏ nhãn Cũ trước đó).

---

## KẾ HOẠCH 2 — Tạo file `llm_rules.json` và cập nhật Stage 2

### Mô tả
Tách `UNIFIED_NLU_PROMPT` và `INTENT_CLASSIFICATION_PROMPT` thành 4 rule block riêng, lưu trong `llm_rules.json`.
Mỗi rule chỉ chứa schema và quy tắc phù hợp với intent đó. Đảm bảo toàn bộ logic load rule và xử lý prompt trong `llm_intent_handler.py` là **stateless** (không lưu state người dùng vào biến toàn cục) để an toàn đồng thời cho nhiều người dùng.

### Cấu trúc cũ
- `src/prompts/llm_prompts.py`: chứa `UNIFIED_NLU_PROMPT` (dùng cho mọi intent), `INTENT_CLASSIFICATION_PROMPT`, `ACTION_SLOT_EXTRACTION_PROMPT`, `RECORD_SLOT_EXTRACTION_PROMPT`.
- `src/prompts/prompts.json`: chứa `llm_unified_prompt`, `llm_intent_classification`, `llm_action_slot_extraction`, `llm_record_slot_extraction`, `mood_personas`, `relationship_override`, `common`, `emotions`.
- `src/nlu/llm_intent_handler.py`: hàm `run_llm_nlu()` dùng `UNIFIED_NLU_PROMPT` cho mọi loại intent.

### Cấu trúc mới
- `src/prompts/llm_rules.json` (FILE MỚI): chứa:
  - `intent_classification_rule.system` (MỚI): rule phân loại intent (Record / Action / Chitchat) và confidence score, dùng cho Stage 1 và majority vote.
  - `record_rule.system`: rule đầy đủ cho Record (category, record_type, slots, missing, NLG, guardrails). Hỗ trợ cả 2 luồng: 1 lần gọi (LLM classify + response) và luồng gọi LLM chỉ sinh response (khi category do TF-IDF/PhoBERT xác định).
  - `action_rule.system`: rule đầy đủ cho Action (tất cả action_type, tool_type, time_range, missing).
  - `chitchat_rule.system`: rule cho Chitchat (suggested_actions, guardrails).
  - `action_slot_schema`: template missing slots cho từng action_type (để BE check).
- `src/prompts/prompts.json`: GIỮ NGUYÊN phần `emotions` và `relationship_override`. XÓA `llm_unified_prompt`, `llm_intent_classification`, `llm_action_slot_extraction`, `llm_record_slot_extraction`.
- `src/prompts/llm_prompts.py`: GIỮ NGUYÊN (dùng làm reference, không xóa ngay).
- `llm_intent_handler.py`: Mọi hàm xử lý LLM phải là stateless functions, khởi tạo prompt mới trong scope cục bộ dựa trên request parameters.


### Nội dung cốt lõi của từng rule (tham chiếu `phan_tich_kien_truc_intent_llm.md`)

**RECORD_RULE phải có:**
- Schema output: `record_type`, `slots.item`, `slots.category`, `slots.amount`, `emotion`, `response`, `suggested_actions: null`.
- 18 category với mô tả + ví dụ đầy đủ (theo llm_prompts.py).
- Note: category BẮT BUỘC cho cả Expense lẫn Income, KHÔNG BAO GIỜ null.
- Note: category cũng BẮT BUỘC với Action khi có đề cập danh mục trong câu.
- Missing: amount = null nếu không có, KHÔNG tự bịa.
- NLG: 2-3 câu TV, emoji, chèn CONTEXT. Nếu amount null → hỏi thêm số tiền.
- Guardrails: nội dung xúc phạm → emotion = "Error".

**ACTION_RULE phải có:**
- Schema output: `action_type`, `slots` (đầy đủ 13 field), `emotion`, `response`, `suggested_actions: null`.
- 11 action_type với mô tả chi tiết + ví dụ câu + điều kiện bắt buộc cho từng loại.
- category quy tắc: BẮT BUỘC nếu đề cập, null nếu tổng quát.
- time_range: BẮT BUỘC với REPORT_*/SEARCH_RECORD.
- loan: KHÔNG dùng SET_ALERT, phải dùng SET_GOAL + tool_type=loan.
- Missing: mọi field không có → null, KHÔNG tự bịa.

**CHITCHAT_RULE phải có:**
- Schema output: `emotion`, `response`, `suggested_actions` (mảng 3 phần tử).
- KHÔNG sinh ra: record_type, action_type, category, slots, item, amount.
- suggested_actions: 3 chức năng app phù hợp ngữ cảnh.
- Guardrails: tiếng Trung, nội dung nhạy cảm, hỏi kiến thức ngoài scope.

**action_slot_schema phải có:**
- Mỗi action_type: `required[]`, `optional[]`, `missing_check[]`, `conditional` (nếu có).
- BE dùng để check field nào null là thiếu thực sự (cần hỏi người dùng bổ sung).

### Quy tắc Persona Injection (bổ sung vào cuối system prompt)
- Lấy từ `prompts.json → emotions[persona_key]`.
- Inject: `system` (mô tả tính cách) + `user` (hướng dẫn viết response) + `slang_pool` (từ lóng).
- Base rule + Persona → KHÔNG chồng nhau: base định format/ngôn ngữ, persona định giọng điệu.
- Thứ tự ưu tiên: Base → Persona → Relationship (cao nhất).

### Quy tắc Relationship Injection (ghi đè persona)
**Cha mẹ/gia đình keywords:** cha, mẹ, me, ba, má, bố, ông, bà, anh, chị, em (ruột), anh hai, chị hai, anh ba, chị ba, ông bô, bà bô, ông nội, bà nội, ông ngoại, bà ngoại, mom, mommy, momy, má mỳ, dad, daddy, dady, cậu, mợ, dì, chú, thím, bác.
**Người yêu/vợ chồng keywords:** người yêu, bồ, vợ, chồng, gấu, crush, ny, cr, vk, ck, bã xã, bà xã, ông xã, iu, babe, baby, người thương, nửa kia.
- Rule từ `prompts.json → relationship_override.CHA_ME` / `NGUOI_YEU`.
- CHA_ME: KHÔNG khịa, KHÔNG dằn dỗi dù persona dan_doi. Ấm áp, khen ngợi.
- NGUOI_YEU (có chi tiêu): Trêu đùa ngọt ngào "vibe phát cẩu lương".
- NGUOI_YEU (không chi tiêu): Khịa nhẹ ghen tị đáng yêu.

### Tasks

| # | Task | File cần sửa/tạo | Hành động |
|---|---|---|---|
| 2.1 | Tạo llm_rules.json | `src/prompts/llm_rules.json` (MỚI) | Viết đầy đủ 4 rule (`intent_classification_rule`, `record_rule`, `action_rule`, `chitchat_rule`) + `action_slot_schema` |
| 2.2 | Thêm hàm _load_llm_rules() | `src/nlu/llm_intent_handler.py` | Load llm_rules.json một lần khi khởi động, cache lại (thread-safe readonly) |
| 2.3 | Thêm hàm _build_system_prompt() | `src/nlu/llm_intent_handler.py` | Ghép rule + persona + relationship injection (stateless function scope) |
| 2.4 | Thêm hàm _build_persona_addition() | `src/nlu/llm_intent_handler.py` | Lấy từ prompts.json.emotions theo persona key |
| 2.5 | Thêm hàm _build_relationship_addition() | `src/nlu/llm_intent_handler.py` | Check từ khóa quan hệ, inject rule từ prompts.json.relationship_override |
| 2.6 | Viết hàm run_llm_nlu_v2() | `src/nlu/llm_intent_handler.py` | Hàm mới thay run_llm_nlu() cho kiến trúc 2 tầng, hoàn toàn stateless |
| 2.7 | Dọn prompts.json | `src/prompts/prompts.json` | Xóa 4 section cũ: llm_unified_prompt, llm_intent_classification, llm_action_slot_extraction, llm_record_slot_extraction |


### Cách test sau khi sửa
1. `modal serve modal_app.py`.
2. Gọi `POST /nlu/infer` với 10 câu mẫu:
   - "ăn sáng 35k" → Record, category=Food, amount=35000.
   - "ăn sáng nè" → Record, category=Food, amount=null, response hỏi số tiền.
   - "tháng này tiêu bao nhiêu" → Action, action_type=REPORT_GENERAL.
   - "đặt hạn mức ăn uống 3 triệu" → Action, action_type=SET_LIMIT, category=Food, amount=3000000.
   - "hôm nay trời đẹp quá" → Chitchat, suggested_actions có 3 phần tử.
   - "mua áo cho người yêu 200k" → Record, response phải có vibe cẩu lương.
   - "tặng quà mẹ 500k" → Record, response phải ấm áp, không khịa.
3. Gọi với 4 persona khác nhau (dui_de, dan_doi, kho_tinh, ngot_ngao) với "ăn phở 50k" → response phải khác biệt rõ ràng.

### Đánh giá thành công
- PASS: Chitchat không có action_type, Record không có suggested_actions ≠ null.
- PASS: category không bao giờ null với Record/Income.
- PASS: 4 persona tạo ra 4 câu response khác nhau rõ ràng (đánh giá bằng mắt).
- PASS: Relationship rule ghi đè đúng dù persona khác.
- PASS: Response khi amount=null có câu hỏi thêm số tiền.
- PASS: Chỉ số Action Type Match Rate trên tập Golden Set đạt >= 90% (không phân loại nhầm giữa các lệnh hệ thống).


---

## KẾ HOẠCH 3 — Cập nhật Pipeline FastAPI (Stage 1 + Stage 2) và chuẩn hóa Registry `llm_v2`

### Mô tả
Cập nhật `pipeline.py`, `nlu_registry.py` và `llm_intent_handler.py` để kết nối chính thức luồng suy luận 2 tầng (`llm_v2` làm backend mặc định). Đảm bảo tuân thủ cơ chế **phi trạng thái (stateless)** cho đa người dùng, tích hợp luồng xử lý song song cho mô hình học máy truyền thống (`tfidf` / `pho_bert`), và áp dụng quy trình duyệt mô hình 3 trạng thái (`Cũ - Hiện tại - Mới`).

### Cấu trúc cũ
- `src/nlu/pipeline.py`: hàm `run_nlu()`, nhánh `backend == "llm"` gọi `run_llm_nlu()` trực tiếp (luồng 1 tầng cũ).
- `src/api/app/services/nlu_registry.py`: cấu hình backend mặc định ban đầu là `"llm"`.
- `src/api/app/schemas/nlu.py`: `NLURequest` không có field `caller_context`.
- Không hỗ trợ phân định cơ chế sinh lời thoại NLG riêng khi chạy bằng mô hình học máy `tfidf` hoặc `pho_bert`.

### Cấu trúc mới (Đã chuẩn hóa với các thảo luận và sửa đổi thực tế)

**1. Chuẩn hóa Backend Mặc định & Registry (`nlu_registry.py`):**
- Cập nhật backend suy luận mặc định thành `"llm_v2"` (bỏ hoàn toàn `"llm"` cũ ra khỏi luồng chính).
- Hỗ trợ đầy đủ 4 backend hợp lệ: `"llm_v2"`, `"llm"`, `"tfidf"`, `"pho_bert"`.
- Tích hợp API chuyển đổi backend (`POST /api/v1/nlu/inference-backend`) với thời gian phản hồi tức thì (không cần restart máy chủ).

**2. NLURequest — bổ sung field `caller_context` và cơ chế cô lập hội thoại (Stateless Request Scope):**
- Mặc định: `"chat"`.
- Giá trị hợp lệ: `"chat"` | `"addstory"`.
- Khi `caller_context == "addstory"` (ghi chép nhanh từ chức năng Add Story): bỏ qua Stage 1 (phân loại Intent), ép buộc `forced_intent = "Record"`, chuyển thẳng vào Stage 2 để trích xuất số tiền và danh mục.
- Tất cả truy vấn đều đi kèm `request_id`, `user_id` và `profile` độc lập, bảo đảm an toàn đồng thời cho hàng nghìn truy vấn song song.

**3. Luồng xử lý kép cho mô hình truyền thống (`tfidf` / `pho_bert`):**
- Khi hệ thống được cấu hình chạy bằng `tfidf` hoặc `pho_bert` tại Stage 2:
  - **Phân loại nhãn:** Mô hình học máy truyền thống thực hiện dự đoán danh mục/ý định và trả kết quả về Backend Node.js ngay lập tức.
  - **Sinh lời thoại phản hồi (NLG):** Đồng thời Backend gửi yêu cầu LLM lần 2 với prompt chuyên biệt chỉ để sinh câu trả lời tự nhiên (`response`), kết hợp hoàn hảo độ chính xác số học của ML truyền thống và độ tự nhiên của LLM.

**4. Majority Vote (Bỏ phiếu đa số khi `confidence < 0.65`):**
- Nếu Stage 1 của `llm_v2` phân loại ý định với độ tin cậy `< 0.65`: chạy song song 3 bộ phân loại (TF-IDF + PhoBERT + Qwen LLM).
- Chọn ý định chiến thắng theo nguyên tắc đa số (ít nhất 2/3 mô hình đồng ý).

**5. Quản trị vòng đời mô hình theo 3 trạng thái (Cũ - Hiện tại - Mới):**
- Thay vì tự động tải đè tệp mới theo `mtime`, hệ thống duy trì 3 trạng thái rõ rệt trong cơ sở dữ liệu: `Old` (Cũ) - `Current` (Hiện tại) - `New / Candidate` (Mới huấn luyện).
- Chỉ khi quản trị viên nhấn nút **"Duyệt áp dụng"** tại trang WebAdmin, mô hình mới mới chính thức thay thế mô hình hiện tại, và mô hình hiện tại chuyển thành mô hình cũ để sẵn sàng khôi phục dự phòng.

### Tasks (Đã hoàn thành triển khai & kiểm thử cú pháp)

| # | Task | File cần sửa | Hành động | Trạng thái |
|---|---|---|---|---|
| 3.1 | Thêm `caller_context` vào NLURequest | `src/api/app/schemas/nlu.py` | Thêm field `caller_context: str = "chat"` | Hoàn thành |
| 3.2 | Chuẩn hóa backend mặc định `llm_v2` | `src/api/app/services/nlu_registry.py` | Đặt `"llm_v2"` làm default, hỗ trợ `"llm_v2"`, `"tfidf"`, `"pho_bert"` | Hoàn thành |
| 3.3 | Thêm nhánh `llm_v2` vào pipeline | `src/nlu/pipeline.py` | Bổ sung luồng 2 tầng Stage 1 (Intent) -> Stage 2 (Extraction) | Hoàn thành |
| 3.4 | Xử lý `addstory` shortcut | `src/nlu/pipeline.py` | Nếu `caller_context == "addstory"` -> Ép buộc `intent = Record` | Hoàn thành |
| 3.5 | Implement luồng kép ML + LLM NLG | `src/nlu/pipeline.py` | Khi dùng `tfidf`/`pho_bert`, trả kết quả nhãn về BE đồng thời gọi LLM lần 2 sinh `response` | Hoàn thành |
| 3.6 | Implement Majority Vote | `src/nlu/pipeline.py` | Khi `confidence < 0.65`: gọi song song 3 bộ phân loại và lấy phiếu đa số | Hoàn thành |
| 3.7 | Cập nhật `models.py` & API Router | `src/nlu/models.py`, `src/api/app/routers/nlu.py` | Cập nhật tập backend hợp lệ và các endpoint `/nlu/infer`, `/nlu/inference-backend` | Hoàn thành |
| 3.8 | Chuẩn hóa bundle loader phi trạng thái | `src/api/app/adapters/expense_ocr_nlu.py` | Tải `llm_rules.json` chỉ đọc (read-only), bảo đảm an toàn đa người dùng | Hoàn thành |
| 3.9 | Đồng bộ quản trị 3 trạng thái mô hình | `src/api/app/adapters/expense_ocr_nlu.py`, `routers/nlu.py` | Kiểm tra trạng thái duyệt từ WebAdmin trước khi thay thế mô hình active | Hoàn thành |
| 3.10 | Truyền `caller_context` xuống adapter | `src/api/app/services/nlu_service.py` | Chuyển tiếp ngữ cảnh `caller_context` từ tầng API xuống `adapter.run_real_nlu()` | Hoàn thành |

### Cách test sau khi sửa
1. **Kiểm thử chế độ mặc định (`llm_v2`):** Gọi `POST /api/v1/nlu/infer` với `"ăn sáng 35k"`, kiểm tra `backend: "llm_v2"`, trả về đúng `intent = "Record"`, `category = "Food"`, `amount = 35000`.
2. **Kiểm thử chế độ phím tắt AddStory:** Gọi `POST /api/v1/nlu/infer` với `caller_context = "addstory"`, câu `"hôm nay trời đẹp quá"` -> Hệ thống bắt buộc trả về `intent = "Record"`, không nhầm sang Chitchat.
3. **Kiểm thử luồng kép `tfidf` / `pho_bert`:** Chuyển backend sang `"tfidf"`, gõ câu chi tiêu -> Kiểm tra nhãn danh mục trả về từ TF-IDF và lời thoại phản hồi NLG được sinh tự nhiên từ LLM.
4. **Kiểm thử bỏ phiếu đa số (Majority Vote):** Giả lập `confidence = 0.70` (< 0.75) -> Hệ thống tự động kích hoạt voting 3 bộ phân loại và chọn đúng ý định đa số.
5. **Kiểm thử quy trình duyệt 3 trạng thái:** Retrain xong mô hình -> Kiểm tra mô hình mới ở trạng thái `Candidate` -> Nhấn "Duyệt áp dụng" trên WebAdmin -> Xác nhận mô hình chuyển thành `Active` và suy luận với trọng số mới.

### Đánh giá thành công
- **PASS:** Mặc định hệ thống luôn chạy trên kiến trúc 2 tầng `llm_v2` ổn định, không bị fallback không mong muốn.
- **PASS:** Phím tắt `addstory` luôn ép ý định về `Record`, bất kể nội dung câu thoại.
- **PASS:** Luồng kép `tfidf` / `pho_bert` kết hợp LLM NLG trả về đúng nhãn danh mục và lời bình mượt mà, không xung đột.
- **PASS:** Quy trình duyệt 3 trạng thái hoạt động chính xác, không ghi đè mô hình đang chạy khi chưa có xác nhận từ quản trị viên.
- PASS: Workspace và storage đồng bộ model sau train.

---

## KẾ HOẠCH 4 — Cập nhật NluOpsPage (WebAdmin) với quản trị mô hình 3 trạng thái (ĐÃ HOÀN THÀNH)

### Cấu trúc cũ
- Import CSV: có nút + handler.
- Auto-retrain: có checkbox.
- COMPARISON_ROWS: nhiều rows (intent, category, record_type, action_type, action_slots, NER).
- Benchmark: intent_accuracy, category_accuracy, record_type_accuracy.
- Thanh tiến trình: ít stage, không rõ model_type.
- Dropdown backend: tfidf | encoder | llm.
- Chưa có quản trị vòng đời mô hình theo 3 trạng thái rõ rệt.

### Cấu trúc mới (Đã chuẩn hóa)
- **Xóa hoàn toàn tính năng thừa:** XÓA Import CSV và checkbox Auto-retrain, loại bỏ layer 2 cũ, chỉ giữ cá nhân hóa danh mục + train 2 tầng.
- **Quản trị mô hình 3 trạng thái (Old - Current - New):**
  - Hiển thị bảng danh sách phiên bản mô hình theo đúng 3 mốc: `Cũ (Old)` để khôi phục dự phòng, `Hiện tại (Current / Active)` đang chạy thực tế, và `Mới (New / Candidate)` vừa huấn luyện xong.
  - Thêm cột so sánh hiệu năng song song giữa Mô hình Mới và Mô hình Hiện tại (F1 Macro, Accuracy, Latency).
  - Tích hợp nút **"Duyệt áp dụng mô hình mới" (Approve & Promote Model)**: Nhấn duyệt sẽ chuyển trạng thái Hiện tại -> Cũ, Mới -> Hiện tại (Active), và loại bỏ bản Cũ trước đó.
- **COMPARISON_ROWS:** giữ các row cho 2 tầng (Intent Stage 1 + Category Stage 2 cho Record).
- **2 bảng Benchmark song song cho 3 model (TF-IDF, PhoBERT, LLM Qwen):**
  - Bảng Stage 1 Benchmark (Intent Classification): F1 macro, Accuracy, Latency.
  - Bảng Stage 2 Benchmark (Category Classification cho Record): F1 macro, Accuracy, Latency trên golden set 50 câu cố định.
- **Thanh tiến trình 6 stage:** `PREPARING` → `CLEANING` → `TRAINING` → `EVALUATING` → `SYNCING` → `SUCCESS`.
- **Dropdown backend:** Nhãn rõ ràng hơn, mặc định chọn `llm_v2`.

### Tasks

| # | Task | File cần sửa | Trạng thái |
|---|---|---|---|
| 4.1 | Xóa Import CSV | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.2 | Xóa auto-retrain toggle | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.3 | Cập nhật COMPARISON_ROWS | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.4 | Thêm 2 bảng Benchmark section | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.5 | Thêm endpoint POST /nlu/benchmark | `src/api/app/routers/nlu.py` | Đã hoàn thành |
| 4.6 | Tạo golden set cho 2 stage | `src/nlu/llm_benchmark.py` (MỚI) | Đã hoàn thành |
| 4.7 | Cập nhật label inference dropdown | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.8 | Cập nhật thanh tiến trình 6 stage | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.9 | Quản trị 3 trạng thái + Nút Duyệt áp dụng | `NluOpsPage.jsx` | Đã hoàn thành |
| 4.10 | Cập nhật TRAIN_STATUS_INFO BE | `src/api/app/routers/nlu.py` | Đã hoàn thành |

### Cách test
1. Mở NluOpsPage → không thấy Import CSV, không thấy auto-retrain.
2. Chạy retrain → theo dõi 6 stage qua UI, khi hoàn tất mô hình mới hiển thị nhãn `New / Candidate`.
3. Nhấn "Duyệt áp dụng mô hình mới" → xác nhận mô hình chuyển thành `Active`, mô hình cũ thành `Old`.
4. Nhấn "Chạy LLM Rule Benchmark" → 3 metric hiển thị trên 2 bảng so sánh.
5. Dropdown backend có nhãn mới + default `llm_v2`.

### Đánh giá thành công
- PASS: Không còn Import CSV và auto-retrain.
- PASS: 6 stage tiến trình hiển thị đúng thứ tự.
- PASS: Quản trị đúng 3 trạng thái mô hình, nút Duyệt áp dụng hoạt động chính xác.
- PASS: 3 LLM metric hiển thị sau benchmark.

---

## KẾ HOẠCH 5 — Cập nhật BotPromptsPage + Dashboard (ĐÃ HOÀN THÀNH)

### Cấu trúc cũ (BotPromptsPage)
- Test prompt: text + persona + override_prompt → gọi POST /nlu/test-prompt → run_llm_nlu().
- Không có caller_context, không có force intent.

### Cấu trúc mới (BotPromptsPage)
- Thêm dropdown caller_context: chat | addstory.
- Thêm dropdown force intent: Auto | Record | Action | Chitchat.
- Response hiển thị thêm: rule_used, intent, confidence.
- Endpoint /nlu/test-prompt đổi sang gọi run_llm_nlu_v2().

### Cấu trúc cũ (Dashboard)
- Biểu đồ nhãn "NLU Accuracy".

### Cấu trúc mới (Dashboard)
- Đổi nhãn "NLU Accuracy" → "Intent Accuracy".
- Giữ Telemetry Runs.

### Tasks

| # | Task | File cần sửa | Trạng thái |
|---|---|---|---|
| 5.1 | Thêm caller_context dropdown | `BotPromptsPage.jsx` | Đã hoàn thành |
| 5.2 | Thêm force intent dropdown | `BotPromptsPage.jsx` | Đã hoàn thành |
| 5.3 | Cập nhật response display | `BotPromptsPage.jsx` | Đã hoàn thành |
| 5.4 | Cập nhật test-prompt endpoint | `src/api/app/routers/nlu.py` dòng 602–633 | Đã hoàn thành |
| 5.5 | Thêm rule_used vào kết quả | `src/nlu/llm_intent_handler.py` | Đã hoàn thành |
| 5.6 | Đổi nhãn Dashboard | Dashboard component | Đã hoàn thành |


### Đánh giá thành công
- PASS: addstory force Record đúng qua test prompt.
- PASS: rule_used hiển thị trong kết quả.
- PASS: Dashboard label đã đổi.

---

## KẾ HOẠCH 6 — Cập nhật Backend Node.js và Quy chuẩn Hiển thị RAG

### Cấu trúc mới (Đã chuẩn hóa)
- **Lọc dữ liệu RAG theo đúng vùng ví (`wallet_id`):**
  - Khi xử lý ý định báo cáo (`REPORT_GENERAL`, `REPORT_COMPARE`) hoặc tra cứu (`SEARCH_RECORD`), Backend kiểm tra ngữ cảnh ví hiện tại.
  - **Ví cá nhân:** Lọc theo `user_id = current_user` và `wallet_id = personal_wallet_id`.
  - **Ví chung (Group Wallet):** Lọc toàn bộ giao dịch theo `wallet_id = group_wallet_id` (bao gồm chi tiêu của toàn bộ thành viên), gom nhóm theo danh mục và đóng góp từng thành viên (`by_member`).
  - Dữ liệu thô sau khi lọc được đóng gói thành bảng ngữ cảnh và gửi vào prompt RAG để LLM sinh lời bình, cảnh báo lạm chi.
- **Quy chuẩn hiển thị bong bóng tin nhắn tại Chat Screen:**
  - **Ý định RAG (REPORT, COMPARE, SEARCH):** Hiển thị 3 bong bóng tin nhắn (Bong bóng 1: Lời thoại dẫn từ NLU Stage 2 -> Bong bóng 2: Biểu đồ/bảng số liệu động -> Bong bóng 3: Lời nhận xét phân tích từ RAG).
  - **Ý định điều khiển (SET_GOAL, SET_LIMIT...):** Hiển thị 2 bong bóng tin nhắn (Bong bóng 1: Lời thoại Mimo -> Bong bóng 2: Thẻ xác nhận hành động).
- **Luồng xử lý kép cho mô hình truyền thống (`tfidf` / `pho_bert`):**
  - Khi hệ thống chạy bằng `tfidf` / `pho_bert`, Backend nhận kết quả nhãn danh mục/ý định ngay lập tức từ NLU, đồng thời gửi một yêu cầu riêng sang LLM với prompt rút gọn chỉ để sinh câu thoại trả lời (`response`).
- **Quản lý slots và phản hồi từ người dùng:**
  - `action.service.js`: thêm hàm `checkMissingSlots(action_type, slots)`.
  - Trả về `missing_slots[]` trong response để app hỏi người dùng bổ sung.
  - API Dislike Intent: cho phép người dùng báo cáo nhận diện sai từ Mobile App.

**Schema cần hardcode:**

| action_type | missing_check (các field cần null check) | conditional |
|---|---|---|
| SET_LIMIT | amount | — |
| REPORT_COMPARE | time_range | — |
| SET_GOAL | goal_name, amount, tool_type | tool_type=loan → contact_name, loan_type |
| ADD_GOAL | amount | — |
| SET_TONE | verbal_style | — |
| SET_ALERT | enabled | — |
| SYSTEM_SETTING | theme | — |
| SET_USERNAME | query | — |
| REPORT_GENERAL, SEARCH_RECORD, SUGGEST_BUDGET | (không bắt buộc) | — |

### Tasks

| # | Task | File cần sửa | Hành động |
|---|---|---|---|
| 6.1 | Kiểm tra xóa Gemini trong BE | `app/backend/src/` | grep gemini, xóa nếu có |
| 6.2 | Implement bộ lọc theo ví cho RAG | `app/backend/src/modules/ai/` | Lọc dữ liệu báo cáo/tra cứu theo đúng `personal_wallet_id` hoặc `group_wallet_id` (kèm `by_member`) |
| 6.3 | Implement luồng kép NLG cho ML | `app/backend/src/modules/ai/` | Gọi LLM lần 2 sinh `response` khi chạy NLU với `tfidf`/`pho_bert` |
| 6.4 | Thêm checkMissingSlots() | `app/backend/src/modules/ai/action.service.js` | Implement theo schema trên |
| 6.5 | Thêm missing_slots và quy chuẩn UI | `app/backend/src/modules/ai/ai.controller.js` | Trả `missing_slots[]` và cấu trúc bong bóng tin nhắn (3 bubble cho RAG vs 2 bubble cho Action) |
| 6.6 | Thêm API Dislike Intent | `app/backend/src/modules/ai/ai.controller.js` & `ai.service.js` | Nhận request khi bấm dislike trên app, cập nhật `is_intent_wrong=true` và `corrected_intent` |
| 6.7 | Cập nhật truy vấn train data | `app/backend/src/modules/ai/` | Đảm bảo khi export/query data cho retrain sẽ lọc các mẫu có `is_intent_wrong=true` |

### Cách test
1. "đặt hạn mức ăn uống" → missing_slots: ["amount"].
2. "nhắc hẹn cho Nam vay tiền" → missing_slots: ["amount", "due_date"].
3. "tháng này tiêu bao nhiêu" tại Ví chung -> Kiểm tra log BE lọc đúng `wallet_id = group_wallet_id` và UI hiển thị đủ 3 bong bóng tin nhắn.
4. "đặt mục tiêu tiết kiệm 10 triệu" -> UI hiển thị 2 bong bóng (Lời thoại + Thẻ xác nhận).

### Đánh giá thành công
- PASS: missing_slots đúng với từng action_type.
- PASS: Báo cáo RAG lọc chính xác theo từng loại ví (cá nhân vs ví chung), hiển thị đúng cấu trúc bong bóng tin nhắn.
- PASS: Luồng kép ML + LLM NLG hoạt động trơn tru.
- PASS: Không còn Gemini trong Node.js BE.

---

## KẾ HOẠCH 7 — OCR Training Progress (BillRetrainPage)

### Tasks

| # | Task | File cần sửa | Hành động |
|---|---|---|---|
| 7.1 | Thêm GET /ocr/train/status | Router OCR | Trả stage, progress_percent, message, elapsed |
| 7.2 | Cập nhật POST /ocr/train | Router OCR | Ghi stage vào status file/biến |
| 7.3 | Thêm thanh tiến trình | `BillRetrainPage.jsx` | Poll /ocr/train/status mỗi 3 giây |

---

## KẾ HOẠCH 8 — Retrain NLU 2 tầng (Intent Stage 1 + Category Stage 2) và Cơ chế Trạng thái Mô hình

### Cấu trúc cũ
- `retrain_all.py`: train intent + category + record_type + action_type + action_slots + NER.
- `retrain_encoders.py`: fine-tune PhoBERT cho nhiều task.
- Mô hình sau khi train tự động được load đè vào hệ thống suy luận mà không qua kiểm duyệt.

### Cấu trúc mới (Đã chuẩn hóa)
- `retrain_all.py`: train 2 tầng:
  - Tầng 1: Intent TF-IDF (3 class: Record/Action/Chitchat).
  - Tầng 2: Category TF-IDF (18 danh mục cho Record).
- `retrain_encoders.py`: fine-tune PhoBERT cho 2 tầng (intent encoder & category encoder).
- Xóa bỏ hoàn toàn việc train record_type, action_type, action_slots, NER (do LLM Qwen xử lý).
- `export_dataset.py` (MỚI): query CSDL MongoDB:
  - Lọc bỏ bản ghi bị người dùng bấm dislike (`is_intent_wrong = true`).
  - Lấy mẫu sửa intent đúng (`corrected_intent`) làm mẫu train cho Tầng 1.
  - Lấy mẫu sửa danh mục (`user_corrected_category`) làm mẫu train ưu tiên cho Tầng 2.
- **Cơ chế nhãn trạng thái sau huấn luyện:**
  - Mô hình mới huấn luyện xong được gán nhãn `Candidate / New` trong CSDL/metadata.
  - Hệ thống tiếp tục giữ mô hình `Active / Current` cũ chạy suy luận cho đến khi quản trị viên nhấn **"Duyệt áp dụng mô hình mới"** trên NluOpsPage.

### Tasks

| # | Task | File cần sửa | Hành động |
|---|---|---|---|
| 8.1 | Sửa retrain_all.py | `text_nlu/train/retrain_all.py` | Chỉ giữ train Intent (Stage 1) và Category (Stage 2 cho Record); xóa train record_type/action_type/action_slots/NER |
| 8.2 | Sửa retrain_encoders.py | `text_nlu/train/retrain_encoders.py` | Chỉ giữ fine-tune PhoBERT cho intent encoder & category encoder |
| 8.3 | Tạo export_dataset.py | `text_nlu/train/export_dataset.py` (MỚI) | Query CSDL MongoDB, lọc mẫu sai dislike, tạo dataset train 2 tầng |
| 8.4 | Cập nhật TRAIN_STATUS_INFO & Metadata | `src/api/app/routers/nlu.py` | Thêm model_type (intent / category), stage CLEANING, EVALUATING và gán trạng thái `New` sau khi train |

### Đánh giá thành công
- PASS: Chỉ thấy log train Intent và Category, không train model khác.
- PASS: Mẫu bị dislike trên app không xuất hiện trong dataset train.
- PASS: Intent F1 sau retrain ≥ 0.85, Category F1 ≥ 0.80.
- PASS: Mô hình mới sau khi train nằm đúng ở trạng thái `Candidate / New`, chờ Admin phê duyệt trên WebAdmin.


---

## KẾ HOẠCH 9 — Fine-tune data export

### Cấu trúc output mỗi mẫu
```json
{
  "instruction": "<RECORD_RULE | ACTION_RULE | CHITCHAT_RULE system string>",
  "input": "Ngữ cảnh (CONTEXT_META): {...}\nCâu thoại: {user_text}",
  "output": "{full JSON với emotion + response + slots}"
}
```
Tỷ lệ: 50% Record (250) + 35% Action (175) + 15% Chitchat (75) = 500 mẫu.

### Tasks

| # | Task | File cần sửa | Hành động |
|---|---|---|---|
| [x] 9.1 | Viết script export | `text_nlu/tools/export_finetune_data.py` (MỚI) | Query CSDL, random sample, format JSON |
| [x] 9.2 | Endpoint trigger | `src/api/app/routers/nlu.py` | POST /nlu/export-finetune-data |
| [x] 9.3 | Nút download WebAdmin | `NluOpsPage.jsx` | Nút "Xuất dữ liệu fine-tune" |

---

## Thứ tự triển khai khuyến nghị

```
KH 1 (Xóa Gemini) [~2h]
  ↓
KH 2 (llm_rules.json + Stage 2) [~4h]
  ↓
KH 3 (Pipeline Stage 1+2) [~3h]
  ↓  ↓
KH 6   KH 4 (NluOpsPage) [~3h]
(BE)    ↓
[~1h]  KH 5 (BotPromptsPage+Dashboard) [~1h]
        ↓
       KH 7 (OCR progress) [~1h]
        ↓
       KH 8 (Retrain chỉ intent) [~2h]
        ↓
       KH 9 (Fine-tune data) [~2h]
```

---

## Ma trận file thay đổi tổng hợp

| File | Kế hoạch | Loại |
|---|---|---|
| `src/llm/gemini_keys.py` | KH1 | XÓA |
| `src/llm/client.py` | KH1 | SỬA nhỏ |
| `src/nlu/llm_intent_handler.py` | KH1, 2, 3 | SỬA CHÍNH |
| `src/nlg/llm_runner.py` | KH1 | SỬA nhỏ |
| `src/nlu/disambiguation_generator.py` | KH1 | SỬA nhỏ |
| `src/prompts/llm_rules.json` | KH2 | TẠO MỚI |
| `src/prompts/prompts.json` | KH2 | SỬA (xóa sections cũ) |
| `src/nlu/pipeline.py` | KH3 | SỬA CHÍNH |
| `src/nlu/models.py` | KH3 | SỬA nhỏ |
| `src/api/app/schemas/nlu.py` | KH1, 3 | SỬA nhỏ |
| `src/api/app/services/nlu_service.py` | KH1, 3 | SỬA nhỏ |
| `src/api/app/adapters/expense_ocr_nlu.py` | KH3 | SỬA CHÍNH |
| `src/api/app/routers/nlu.py` | KH3, 4, 5, 9 | SỬA nhiều chỗ |
| `src/api/app/core/config.py` | KH1 | SỬA nhỏ |
| `src/nlu/llm_benchmark.py` | KH4 | TẠO MỚI |
| `text_nlu/train/retrain_all.py` | KH8 | SỬA CHÍNH |
| `text_nlu/train/retrain_encoders.py` | KH8 | SỬA CHÍNH |
| `text_nlu/train/export_intent_dataset.py` | KH8 | TẠO MỚI |
| `text_nlu/tools/export_finetune_data.py` | KH9 | TẠO MỚI |
| `app/backend/src/modules/ai/action.service.js` | KH6 | SỬA nhỏ |
| `app/backend/src/modules/ai/ai.controller.js` | KH6 | SỬA nhỏ |
| `NluOpsPage.jsx` | KH4 | SỬA CHÍNH |
| `BotPromptsPage.jsx` | KH5 | SỬA nhỏ |
| Dashboard component | KH5 | SỬA nhỏ |
| `BillRetrainPage.jsx` | KH7 | SỬA nhỏ |
| `.env` | KH1 | XÓA keys |
