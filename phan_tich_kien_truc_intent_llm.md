# Phân tích kiến trúc chuyển sang Intent Classifier + LLM (Phiên bản hoàn chỉnh)

> Phiên bản cuối sau khi tổng hợp đầy đủ các comment và yêu cầu bổ sung. Chỉ dùng Qwen2.5 qua Modal. Chuyển hoàn toàn, không A/B.

---

## 1. Hiện trạng & vấn đề cần giải quyết

```
User text → UNIFIED_NLU_PROMPT (1 lần gọi LLM, ~91 dòng)
   Ưu tiên: Qwen2.5 Modal → Qwen2.5 local → Gemini (BỎ HOÀN TOÀN)
```

**Vấn đề:**
- Prompt khổng lồ ôm tất cả → LLM dễ quên rule, không tối ưu.
- Schema đầu ra không phân tách theo intent → dư thừa field (chitchat trả action_type, v.v.).
- Gemini còn là fallback cuối cùng → xóa hoàn toàn.
- Không phân biệt context chat (thiếu tiền?) vs addstory (luôn Record).

---

## 2. Kiến trúc mới — luồng 2 tầng

```
User text  +  caller_context (chat | addstory)
  ↓
[Stage 1: Intent Classifier]
  ├── Backend chính: TF-IDF hoặc PhoBERT (nhanh, chạy trên Modal)
  ├── Khi confidence < 0.65:
  │     Chạy song song: TF-IDF + PhoBERT + LLM Qwen (3 lần classify)
  │     → Majority vote → lấy kết quả đa số (2/3 đồng ý)
  └── ĐẶC BIỆT — caller_context == "addstory":
        → Bỏ qua Stage 1, luôn đặt intent = "Record"
  ↓
[Stage 2: Load Rule theo intent từ llm_rules.json]
  ├── Record   → RECORD_RULE  +  caller_context check
  ├── Action   → ACTION_RULE
  └── Chitchat → CHITCHAT_RULE
  ↓
[Gọi Qwen2.5 trên Modal]
  Input = Rule + Persona injection + Relationship rule injection + Context metadata + User text
  Output = JSON chuẩn theo schema của từng intent
  ↓
[BE nhận kết quả]
  → Kiểm tra missing slots theo từng action_type
  → Trả về missing_slots[] nếu thiếu → Mobile/App yêu cầu người dùng bổ sung
```

---

## 3. XÓA toàn bộ luồng Gemini (ưu tiên cao nhất)

| File | Hành động cụ thể |
|---|---|
| `src/llm/gemini_keys.py` | Xóa file hoàn toàn |
| `src/llm/client.py` | Xóa `call_gemini`, `ensure_gemini_system_instruction`; chỉ export `call_qwen` |
| `src/nlu/llm_intent_handler.py` | Xóa block Gemini fallback (dòng 210-227); giữ nguyên Qwen Modal + local |
| `src/nlg/llm_runner.py` | Xóa `from src.llm.gemini_keys import call_gemini_with_key_fallback` (dòng 10, 184) |
| `src/nlu/disambiguation_generator.py` | Xóa Gemini import + call (dòng 14, 85) |
| `src/api/app/schemas/nlu.py` | Xóa field `gemini_json` (dòng 106), giữ `llama_json` hoặc đổi tên thành `llm_json` |
| `src/api/app/services/nlu_service.py` | Xóa `_normalize_real` reference đến `gemini_json`, thay bằng `llm_json` |
| `.env` | Xóa: `gemini_API_v1`, `gemini_API_v2`, `gemini_API_v3`, `GEMINI_MODEL`, `gemini_API`, `GEMINI_API` |
| `src/api/app/core/config.py` | Xóa `GEMINI_API_KEY`, `GEMINI_MODEL` settings |

Hàm `_call_llm()` sau khi dọn:

```python
def _call_llm(system_prompt: str, user_prompt: str) -> str:
    # Nhánh 1: Qwen2.5 trên Modal Cloud (ưu tiên)
    use_modal = os.environ.get("USE_MODAL_PHOGPT") == "1" or os.environ.get("IS_MODAL") == "true"
    if use_modal:
        try:
            from modal_app import QwenModel
            text = QwenModel().generate.remote(system_prompt, user_prompt)
            if text: return text
        except Exception as e:
            # Thử from_name nếu direct import fail
            import modal
            QwenModel = modal.Cls.from_name("expense-ocr-nlu", "QwenModel")
            text = QwenModel().generate.remote(system_prompt, user_prompt)
            if text: return text

    # Nhánh 2: Qwen2.5 local (LM Studio / Ollama)
    local_url = os.environ.get("LOCAL_LLM_URL")
    if local_url:
        resp = call_lmstudio(local_url, "qwen2.5-3b-instruct", system_prompt, user_prompt, temperature=0.1)
        text = extract_chat_text(resp)
        if text: return text

    raise RuntimeError("Qwen2.5 LLM không khả dụng. Kiểm tra Modal (modal serve) hoặc local server.")
```

---

## 4. Rule blocks — `src/prompts/llm_rules.json`

Toàn bộ rule kế thừa từ `llm_prompts.py` hiện tại. Cấu trúc:

```
llm_rules.json
├── record_rule        ← kế thừa UNIFIED_NLU_PROMPT phần Record + RECORD_SLOT_EXTRACTION_PROMPT
├── action_rule        ← kế thừa UNIFIED_NLU_PROMPT phần Action + ACTION_SLOT_EXTRACTION_PROMPT
├── chitchat_rule      ← kế thừa UNIFIED_NLU_PROMPT phần Chitchat
├── action_slot_schema ← template đầu ra cố định cho từng action_type (để BE check missing)
└── relationship_rules ← CHA_ME, NGUOI_YEU (kế thừa từ prompts.json relationship_override)
```

### 4.1 RECORD_RULE — đầy đủ kế thừa từ llm_prompts.py

```
[SCHEMA ĐẦU RA — RECORD]
{
  "record_type": "Expense" | "Income",
  "slots": {
    "item": "<tên giao dịch tiếng Việt ngắn gọn>" | null,
    "category": "<xem danh sách category bên dưới>",
    "amount": <số nguyên, ví dụ: 50000> | null
  },
  "emotion": "<xem danh sách emotion>",
  "response": "<NLG tiếng Việt, 2-3 câu, kèm emoji>",
  "suggested_actions": null
}

[QUY TẮC RECORD_TYPE]
- "Expense": chi tiền ra — mua, đóng, ăn, trả, đổ, nạp.
- "Income": nhận tiền vào — lương, thưởng, bán đồ, được cho, nhận lãi.

[QUY TẮC CATEGORY — BẮT BUỘC ĐIỀN, KHÔNG BAO GIỜ null cho Record]
[LƯU Ý: BẮT BUỘC trích xuất category đối với CẢ giao dịch chi tiêu (Expense), thu nhập (Income)
VÀ các câu lệnh báo cáo/tìm kiếm (Action có nhắc đến danh mục). TUYỆT ĐỐI không trả về null
nếu người dùng có đề cập đến danh mục dù ở bất kỳ intent nào.]

- Food: Chi tiêu cho bữa ăn uống hàng ngày của cá nhân hoặc gia đình.
  Liên quan đến: ăn sáng, ăn trưa, đi chợ, đồ ăn, quán ăn, trà sữa, v.v.

- Transport: Chi phí di chuyển, đi lại và bảo dưỡng phương tiện.
  Liên quan đến: đổ xăng, gửi xe, sửa xe, đi grab, taxi, vé xe, v.v.

- Shopping: Chi mua sắm trang phục, phụ kiện hoặc đồ dùng cá nhân không phải thực phẩm.
  Liên quan đến: quần áo, giày dép, túi xách, sắm đồ online, Shopee, v.v.

- Beauty: Chi phí chăm sóc sắc đẹp và ngoại hình cá nhân.
  Liên quan đến: mỹ phẩm, làm đẹp, spa, cắt tóc, mua son môi, son dưỡng, làm nails, v.v.

- Social: Chi phí giao lưu các mối quan hệ xã hội, bạn bè và lễ nghi.
  Liên quan đến: đi ăn cưới, quà cáp, sinh nhật, giao lưu bạn bè, đi chơi với bạn, v.v.

- Health: Chi phí chăm sóc sức khỏe, y tế và rèn luyện thể chất.
  Liên quan đến: thuốc men, thuốc cảm, khám bệnh, nha khoa, tập gym, thể thao, v.v.

- Housing: Chi phí cố định liên quan đến chỗ ở và tiện ích nhà ở.
  Liên quan đến: tiền thuê nhà, tiền trọ, điện nước, bình gas, internet, phí quản lý, v.v.

- Education: Chi phí cho học tập, đào tạo và phát triển kiến thức.
  Liên quan đến: học phí, mua sách vở, sách lập trình, khóa học online, v.v.

- Entertainment: Chi phí giải trí, thư giãn và sở thích cá nhân.
  Liên quan đến: xem phim chiếu rạp, nghe nhạc, tài khoản Netflix, nạp thẻ game, v.v.

- Essentials: Chi mua vật dụng tiêu hao thiết yếu phục vụ sinh hoạt hàng ngày.
  Liên quan đến: đi siêu thị mua đồ dùng sinh hoạt, chai dầu gội, kem đánh răng, nước giặt, v.v.

- Business: Các khoản thu chi phát sinh trong hoạt động buôn bán, kinh doanh.
  Liên quan đến: chi phí quảng cáo, nhập hàng, thu nhập bán hàng, khách mua hàng của shop, v.v.

- Charity: Các khoản tiền quyên góp, từ thiện vì mục đích cộng đồng.
  Liên quan đến: từ thiện, ủng hộ quỹ vaccine, quyên góp đồng bào lũ lụt, v.v.

- Debt: Các khoản giao dịch liên quan đến thanh toán nợ hoặc cho mượn tiền.
  Liên quan đến: trả nợ thẻ tín dụng, trả tiền mượn bạn, cho người khác vay, v.v.

- Savings: Các khoản tiền tích lũy, gửi tiết kiệm cho tương lai.
  Liên quan đến: gửi tiền tiết kiệm ngân hàng, bỏ ống heo, chuyển vào quỹ tiết kiệm, v.v.

- Investment: Các khoản chi đầu tư sinh lời hoặc thu nhập từ tài sản đầu tư.
  Liên quan đến: mua cổ phiếu, đầu tư chứng khoán, mua vàng, nhận tiền lời/lãi gửi tiết kiệm, v.v.

- Bonus: Các khoản thu nhập bất thường, thưởng hoặc tiền được tặng không cố định.
  Liên quan đến: tiền thưởng lễ Tết, thưởng dự án, trúng số, được mẹ/người thân cho tiền, tiền lộc, v.v.

- Salary: Thu nhập định kỳ từ tiền lương công việc.
  Liên quan đến: nhận lương hàng tháng, lương làm thêm, v.v.

- Others: Các khoản thu chi khác không thuộc bất kỳ nhóm danh mục nào ở trên.
  LƯU Ý: Thu nhập (Income) như lương, thưởng, lãi, trúng số BẮT BUỘC vào đúng danh mục
  (Salary, Bonus, Investment). KHÔNG để null.

[TRƯỜNG HỢP MISSING SLOTS — QUAN TRỌNG]
- Thiếu amount (câu không có số tiền): slots.amount = null. TUYỆT ĐỐI KHÔNG tự bịa số tiền.
- Thiếu item (câu quá ngắn, không rõ mua gì): slots.item = null.
- category KHÔNG BAO GIỜ null khi intent = Record.

[QUY TẮC NLG response]
- 2-3 câu, TIẾNG VIỆT 100%, kèm emoji phù hợp với sắc thái.
- BẮT BUỘC chèn ít nhất 1 yếu tố từ CONTEXT (thời tiết, buổi trong ngày, ngày tới lương).
- Ví dụ TỐT: "Sáng sớm nắng ấm thế này mà {tên} đã tiêu tiền rồi sao? Mimo ghi nhận rồi nha! ☀️"
- TUYỆT ĐỐI KHÔNG dùng tiếng nước ngoài, không lặp từ vô nghĩa (cấm lặp "mascot").
- Nếu amount = null: response phải yêu cầu người dùng nhập số tiền. Ví dụ: "Mimo ghi nhận ăn sáng cho {tên} rồi nha! Bạn chi hết bao nhiêu vậy? 🍳"
- emotion PHẢI ĐỒNG BỘ với nội dung. Không chọn Happy/Celebrate nếu response là cảnh báo/hỏi thêm.

[GUARDRAILS]
- Nội dung xúc phạm/nhạy cảm/chính trị/bạo lực/tình dục: từ chối lịch sự, emotion = "Error".
- Chỉ phản hồi chủ đề tài chính cá nhân và chitchat thân thiện.
- Hỏi "Ai tạo ra mày?": "Mimo là trợ lý tài chính thông minh được tạo ra để giúp bạn quản lý chi tiêu tốt hơn nha! 🌟"
```

### 4.2 ACTION_RULE — đầy đủ kế thừa từ llm_prompts.py

```
[SCHEMA ĐẦU RA — ACTION]
{
  "action_type": "REPORT_GENERAL | REPORT_COMPARE | SET_LIMIT | SET_GOAL | ADD_GOAL |
                  SET_TONE | SEARCH_RECORD | SUGGEST_BUDGET | SYSTEM_SETTING |
                  SET_USERNAME | SET_ALERT",
  "slots": {
    "item": null,
    "category": "Food | Transport | Shopping | Entertainment | Health | Education |
                 Beauty | Housing | Social | Business | Bonus | Charity | Essentials |
                 Debt | Investment | Savings | Salary | Others | null",
    "amount": <số nguyên> | null,
    "verb": "SET" | "ADD" | "SUB" | "GT" | "LT" | null,
    "goal_name": "<tên mục tiêu / nội dung vay mượn>" | null,
    "tool_type": "saving_personal" | "saving_group" | "challenge" | "challenge_group" | "loan" | null,
    "loan_type": "lend" | "borrow" | null,
    "contact_name": "<tên người vay / người cho vay>" | null,
    "due_date": "YYYY-MM-DD" | null,
    "enabled": true | false | null,
    "theme": "dark" | "light" | null,
    "verbal_style": "dui_de" | "dan_doi" | "kho_tinh" | "ngot_ngao" | null,
    "time_range": "<khoảng thời gian hoặc mảng [\"từ\", \"đến\"]>" | null,
    "query": "<từ khóa tìm kiếm tiếng Việt>" | null
  },
  "emotion": "<xem danh sách 28 emotion>",
  "response": "<NLG tiếng Việt, 2-3 câu, kèm emoji>",
  "suggested_actions": null
}

[QUY TẮC ACTION_TYPE — BẮT BUỘC có khi intent = Action]

- REPORT_GENERAL: Khi người dùng muốn xem biểu đồ, thống kê tổng quát, báo cáo.
  Ví dụ: "tháng này tiêu hết bao nhiêu", "báo cáo chi tiêu", "ví tháng này thế nào".

- REPORT_COMPARE: Khi người dùng muốn so sánh chi tiêu của mình với thời gian trước.
  Ví dụ: "tháng này so với tháng trước", "tuần vừa rồi có khác tuần này không".
  → time_range là mảng ["tháng trước", "tháng này"] hoặc chuỗi mô tả.

- SET_LIMIT: Khi người dùng muốn đặt hạn mức / ngân sách chi tiêu.
  Ví dụ: "đặt hạn mức tháng này 20 triệu", "giới hạn ăn uống 3 triệu".
  LƯU Ý: NẾU THIẾU SỐ TIỀN → slots.amount = null (KHÔNG ĐƯỢC TỰ BỊA).
         NẾU LÀ TỔNG CHI TIÊU → slots.category = null.
         KHÔNG NHẦM VỚI SET_ALERT (cảnh báo vượt mức).

- SET_GOAL: Khi người dùng TẠO MỚI mục tiêu tiết kiệm, quỹ nhóm, thử thách, hoặc vay mượn.
  Ví dụ: "tạo mục tiêu tiết kiệm 10 triệu mua xe", "tạo quỹ nhóm đi du lịch 50 triệu",
         "nhắc hẹn cho Nam vay 2 triệu hạn 15/08".
  BẮT BUỘC trích xuất slots.tool_type:
  + saving_personal: Tiết kiệm cá nhân (MẶC ĐỊNH, trừ khi nói rõ nhóm/quỹ chung).
  + saving_group: Tiết kiệm tập thể / quỹ chung rủ thêm người tham gia.
  + challenge: Thử thách tiết kiệm cá nhân (MẶC ĐỊNH cho thử thách cá nhân).
  + challenge_group: Thử thách tiết kiệm nhóm có rủ bạn bè đua tiến độ.
  + loan: Vay mượn / nhắc hẹn nợ. Dù người dùng dùng từ "nhắc",
          TUYỆT ĐỐI dùng tool_type="loan", KHÔNG dùng SET_ALERT.
          BẮT BUỘC trích xuất: contact_name, loan_type ("lend"=cho vay, "borrow"=đi vay), due_date.

- ADD_GOAL: Khi người dùng NẠP TIỀN / THÊM TIỀN / CHUYỂN THÊM vào mục tiêu/quỹ ĐÃ CÓ.
  Ví dụ: "Nạp 500k vào quỹ mua xe", "Chuyển thêm 2 triệu vào heo đất", "Đóng 500k vô quỹ nhóm".
  KHÔNG NHẦM VỚI SET_GOAL (tạo mới). BẮT BUỘC trích xuất amount.

- SET_TONE: Khi người dùng ra lệnh thay đổi giọng điệu Mimo.
  Ví dụ: "đổi giọng điệu sang vui vẻ", "nói chuyện nghiêm túc đi", "giọng ngọt ngào đi"
  BẮT BUỘC trích xuất verbal_style theo ý định người dùng:
  + dui_de: vui vẻ, năng lượng, tích cực
  + dan_doi: dằn dỗi, xéo xắt, cằn nhằn
  + kho_tinh: nghiêm khắc, kỷ luật, premium
  + ngot_ngao: ngọt ngào, chữa lành, dỗ dành

- SET_ALERT: Khi người dùng bật/tắt cảnh báo chi tiêu (KHÔNG phải nhắc nợ).
  Ví dụ: "bật cảnh báo chi tiêu", "tắt thông báo vượt hạn mức".
  BẮT BUỘC trích xuất enabled (true=bật, false=tắt).

- SYSTEM_SETTING: Khi người dùng đổi màu app / giao diện.
  Ví dụ: "chuyển sang nền tối", "bật dark mode", "giao diện sáng đi".
  BẮT BUỘC trích xuất theme ("dark" hoặc "light").

- SEARCH_RECORD: Khi người dùng muốn xem danh sách, liệt kê, hoặc tra cứu cụ thể.
  Ví dụ: "liệt kê giao dịch hôm nay", "tìm khoản ăn uống", "hôm qua mua gì".
  BẮT BUỘC trích xuất time_range nếu có đề cập.

- SUGGEST_BUDGET: Khi người dùng muốn Mimo gợi ý ngân sách phù hợp.
  Ví dụ: "tháng này tôi nên tiêu bao nhiêu", "gợi ý ngân sách ăn uống cho tôi".

- SET_USERNAME: Khi người dùng muốn đổi tên gọi.
  Ví dụ: "gọi tôi là Khang", "đổi tên thành Mai".
  BẮT BUỘC trích xuất query (tên mới).

[QUY TẮC TIME_RANGE — QUAN TRỌNG]
- Khi action_type là REPORT_GENERAL, REPORT_COMPARE hoặc SEARCH_RECORD:
  BẮT BUỘC trích xuất time_range nếu có đề cập.
  TUYỆT ĐỐI KHÔNG để null nếu câu có mốc thời gian.
  Ví dụ: "hôm nay", "tháng trước", "tuần này", "năm nay", "01/05–31/05".

[QUY TẮC CATEGORY — cho Action]
- BẮT BUỘC trích xuất nếu người dùng đề cập đến danh mục trong câu:
  "tiền ăn" → Food, "di chuyển" → Transport, "điện nước" → Housing, "mua sắm" → Shopping.
- Nếu câu hỏi tổng quát không nhắc danh mục cụ thể → category = null.
  KHÔNG trả về Others khi không có thông tin.

[MISSING SLOTS — TUYỆT ĐỐI KHÔNG TỰ BỊA]
- SET_LIMIT thiếu tiền → amount = null.
- SET_GOAL thiếu tên mục tiêu → goal_name = null.
- loan thiếu ngày → due_date = null, thiếu tên → contact_name = null.
- SET_TONE không rõ kiểu → verbal_style = null.

[QUY TẮC NLG response]
- Giọng nghiêm túc, súc tích; TUYỆT ĐỐI không bịa số liệu.
- 2-3 câu, TIẾNG VIỆT 100%, kèm emoji.
- Gọi người dùng bằng tên CONTEXT_META.username nếu có.
- TUYỆT ĐỐI không dùng tiếng nước ngoài.
```

### 4.3 CHITCHAT_RULE — đầy đủ kế thừa từ llm_prompts.py

```
[SCHEMA ĐẦU RA — CHITCHAT]
{
  "emotion": "<xem danh sách emotion>",
  "response": "<NLG tiếng Việt, đối đáp tự nhiên, tối đa 2-3 câu, kèm emoji>",
  "suggested_actions": ["<gợi ý 1>", "<gợi ý 2>", "<gợi ý 3>"]
}
KHÔNG sinh ra: record_type, action_type, category, slots, item, amount.

[QUY TẮC CHITCHAT]
- intent = Chitchat khi: chào hỏi, nói chuyện phiếm, than thở, khoe khoang.
- QUAN TRỌNG: Khi câu có nhắc đến từ khóa mua sắm/Shopee/tiền bạc/lương/tiết kiệm
  NHƯNG là nói phiếm (không phải ghi nhận mới) → vẫn là Chitchat. category = null.
- suggested_actions: 3 chức năng app phù hợp ngữ cảnh câu nói.
  Ví dụ: ["Thêm giao dịch", "Xem báo cáo", "Quét hóa đơn"]

[GUARDRAILS]
- Nội dung xúc phạm/nhạy cảm/chính trị/bạo lực/tình dục: từ chối lịch sự, emotion = "Error".
  Trả lời: "Xin lỗi, Mimo chỉ là trợ lý tài chính và không thể thảo luận về vấn đề này.
            Bạn có cần giúp gì về chi tiêu không?"
- Hỏi kiến thức chung/code: hướng về chi tiêu. Ví dụ: "Ui vấn đề này Mimo không rành lắm,
  Mimo chỉ rành đếm tiền thôi à! 💸 Hôm nay bạn có muốn ghi chép khoản nào không?"
- Hỏi "Ai tạo ra mày?": "Mimo là trợ lý tài chính thông minh được tạo ra để giúp bạn
  quản lý chi tiêu tốt hơn nha! 🌟"

[QUY TẮC NLG response]
- Đối đáp tự nhiên, TIẾNG VIỆT 100%, kèm emoji.
- TUYỆT ĐỐI không dùng tiếng Trung hoặc tiếng nước ngoài.
- Súc tích, không lặp từ vô nghĩa.
```

### 4.4 Persona Injection — chèn vào mọi rule

**Giải thích để tránh nhầm lẫn:**
- Các rule (4.1/4.2/4.3) quy định BASE NLG: ngôn ngữ Việt, 2-3 câu, emoji, không tiếng nước ngoài.
  Đây là **nền tảng tối thiểu** bắt buộc với mọi persona.
- Persona injection **bổ sung lên trên** base đó: quy định giọng điệu, cách dùng từ lóng,
  mức độ cảm xúc, cách xưng hô. Hai phần KHÔNG chồng nhau mà **lồng ghép theo thứ tự ưu tiên**:
  Base rules → Persona rules → Relationship rules (nếu có).
- **Mỗi persona PHẢI tạo ra câu phản hồi khác biệt rõ ràng:**

| Persona | Đặc điểm nhận biết | Ví dụ phản hồi cùng câu "ăn phở 50k" |
|---|---|---|
| dui_de | Vui vẻ, năng lượng cao, từ lóng Gen Z | "Vibe cực 🔥 Mai Khang vừa ăn phở 50k! Chốt đơn xịn xò luôn nha! Mimo ghi lại rồi đó bạn ơi~" |
| dan_doi | Dằn dỗi, cằn nhằn, lo lắng giả vờ | "Ét ô ét 😩 50k cho tô phở hả? Héo não quá bạn ơi, ví đang mỏng dần rồi nhé!" |
| kho_tinh | Nghiêm khắc, phân tích lạnh lùng | "Báo động đỏ 🚨 50,000₫ cho bữa ăn. Trong ngữ cảnh ngân sách hiện tại, tỷ lệ chi cho Food đang tăng. Cần kiểm soát ngay." |
| ngot_ngao | Ngọt ngào, chữa lành, an ủi | "Thương thương 💖 Mai Khang ăn phở buổi sáng ngon không nè? Mimo ghi lại cho bạn rồi, ấm lòng ghê đó nha~" |

Mỗi lần gọi LLM, thêm vào cuối system_prompt block sau:

```python
def _build_persona_addition(nlg_persona: str, prompts_config: dict) -> str:
    if not nlg_persona:
        return ""
    emotions = prompts_config.get("emotions", {})
    persona_key = nlg_persona.lower()
    if persona_key in emotions:
        cfg = emotions[persona_key]
        sys_msg = cfg.get("system", "")     # Mô tả tính cách đầy đủ
        user_guide = cfg.get("user", "")   # Hướng dẫn viết response
        slangs = ", ".join(cfg.get("slang_pool", []))
        return (
            f"\n\n[QUY TẮC PHONG CÁCH — Persona: {persona_key.upper()}]\n"
            f"{sys_msg}\n"
            f"Hướng dẫn viết response: {user_guide}\n"
            f"Từ lóng được phép dùng (linh hoạt, không lặp): {slangs}"
        )
    return f"\n\n[QUY TẮC PHONG CÁCH — Persona: {nlg_persona}]\nPhản hồi theo phong cách này."
```

**4 personas từ prompts.json:**

- dui_de: Trợ lý Gen Z vui vẻ, năng lượng cao. Gọi người dùng bằng tên ("Khánh ơi..."). Dùng từ lóng đa dạng, không bị rập khuôn. Kết hợp ≥2 yếu tố CONTEXT.
- dan_doi: Dằn dỗi, xéo xắt, hay cằn nhằn nhưng thực chất lo lắng. Chê bai nhẹ, không nói kiểu robot. Văn nói Gen Z đậm chất.
- kho_tinh: Premium, nghiêm khắc, kỷ luật thép, phê bình thẳng thắn, mang tính xây dựng. Không bao giờ an ủi nếu chi quá nhiều.
- ngot_ngao: Premium, siêu ngọt ngào, thấu cảm tối đa, chữa lành. Không bao giờ trách móc. An ủi khi ví vơi, khen ngợi khi có thu nhập.

### 4.5 Relationship Rule Injection — chèn khi phát hiện từ khóa quan hệ

Kế thừa từ `prompts.json → relationship_override`. Relationship rule có **độ ưu tiên cao nhất**,
ghi đè lên cả persona (ví dụ: dù persona là dan_doi, vẫn KHÔNG khịa khi nhắc đến cha mẹ).

**Nội dung rule từ prompts.json:**
- CHA_ME: Tuyệt đối KHÔNG khịa, KHÔNG dằn dỗi dù chi số tiền lớn.
  Chuyển sang văn phong ấm áp, tự hào, khen ngợi user là đứa con hiếu thảo.
- NGUOI_YEU (chi tiêu): Trêu đùa ngọt ngào theo kiểu vibe phát cẩu lương, chiều bồ số 2 không ai số 1.
- NGUOI_YEU (không chi tiêu): Khịa nhẹ ghen tị đáng yêu. Không dùng từ "chê".

```python
def _build_relationship_addition(text: str, prompts_config: dict) -> str:
    text_lower = text.lower()
    rel = prompts_config.get("relationship_override", {})

    # --- Cha mẹ, anh chị, ông bà, họ hàng ---
    cha_me_keywords = [
        "cha", "mẹ", "me", "ba", "má", "bố", "ông", "bà",
        "anh", "chị", "em",            # anh/chị ruột
        "anh hai", "chị hai", "anh ba", "chị ba",
        "ông bô", "bà bô", "ông nội", "bà nội",
        "ông ngoại", "bà ngoại",
        "mom", "mommy", "momy", "má mỳ",
        "dad", "daddy", "dady",
        "cậu", "mợ", "dì", "chú", "thím", "bác",
    ]
    if any(kw in text_lower for kw in cha_me_keywords):
        rule = rel.get("CHA_ME", {}).get("rule", "")
        if rule:
            return f"\n\n[ĐẶC BIỆT — QUAN HỆ NGƯỜI THÂN]: {rule}"

    # --- Người yêu, vợ chồng ---
    nguoi_yeu_keywords = [
        "người yêu", "bồ", "vợ", "chồng", "gấu", "crush",
        "ny", "cr",                    # viết tắt thông dụng
        "vk", "ck",                    # vợ/chồng viết tắt
        "bã xã", "bà xã",
        "ông xã",
        "iu", "babe", "baby",
        "người thương", "nửa kia",
    ]
    if any(kw in text_lower for kw in nguoi_yeu_keywords):
        nguoi_yeu = rel.get("NGUOI_YEU", {})
        is_expense = any(kw in text_lower for kw in
            ["mua", "tặng", "chuyển", "trả", "bao", "đãi", "đưa", "chi", "tiêu", "mời"])
        if is_expense and nguoi_yeu.get("rule_happy"):
            return f"\n\n[ĐẶC BIỆT — QUAN HỆ NGƯỜI YÊU]: {nguoi_yeu['rule_happy']}"
        elif nguoi_yeu.get("rule_sad"):
            return f"\n\n[ĐẶC BIỆT — QUAN HỆ NGƯỜI YÊU]: {nguoi_yeu['rule_sad']}"
    return ""
```

---

## 5. Template missing slots theo action_type — để BE check

Định nghĩa trong `action_slot_schema` của `llm_rules.json`:

```json
{
  "action_slot_schema": {
    "REPORT_GENERAL": {
      "required": [],
      "optional": ["category", "time_range"],
      "missing_check": []
    },
    "REPORT_COMPARE": {
      "required": ["time_range"],
      "optional": ["category"],
      "missing_check": ["time_range"]
    },
    "SET_LIMIT": {
      "required": ["amount"],
      "optional": ["category", "verb"],
      "missing_check": ["amount"]
    },
    "SET_GOAL": {
      "required": ["goal_name", "amount", "tool_type"],
      "optional": ["due_date", "contact_name", "loan_type"],
      "missing_check": ["goal_name", "amount", "tool_type"],
      "conditional": {
        "tool_type == loan": ["contact_name", "loan_type"]
      }
    },
    "ADD_GOAL": {
      "required": ["amount"],
      "optional": ["goal_name", "tool_type"],
      "missing_check": ["amount"]
    },
    "SET_TONE": {
      "required": ["verbal_style"],
      "optional": [],
      "missing_check": ["verbal_style"]
    },
    "SET_ALERT": {
      "required": ["enabled"],
      "optional": [],
      "missing_check": ["enabled"]
    },
    "SYSTEM_SETTING": {
      "required": ["theme"],
      "optional": [],
      "missing_check": ["theme"]
    },
    "SEARCH_RECORD": {
      "required": [],
      "optional": ["category", "time_range", "query", "amount"],
      "missing_check": []
    },
    "SUGGEST_BUDGET": {
      "required": [],
      "optional": ["category"],
      "missing_check": []
    },
    "SET_USERNAME": {
      "required": ["query"],
      "optional": [],
      "missing_check": ["query"]
    }
  }
}
```

**BE check missing slots** sau khi nhận NLU result:

```javascript
// action.service.js
function checkMissingSlots(actionType, slots, schema) {
  const definition = schema[actionType];
  if (!definition) return [];
  
  const missing = [];
  for (const field of definition.missing_check) {
    if (slots[field] === null || slots[field] === undefined) {
      missing.push(field);
    }
  }
  
  // Check điều kiện đặc biệt
  if (definition.conditional) {
    if (actionType === "SET_GOAL" && slots.tool_type === "loan") {
      for (const field of definition.conditional["tool_type == loan"]) {
        if (!slots[field]) missing.push(field);
      }
    }
  }
  return missing;
}
// Trả về missing_slots[] cho Mobile/App để hỏi người dùng bổ sung
```

---

## 6. Hai trường hợp đặc biệt với Record

### 6.1 Chat (`/nlu/infer` với `caller_context = "chat"`)

Stage 1 phân loại bình thường. Hai kịch bản:

| Câu nói | Kết quả đúng | Cách xử lý |
|---|---|---|
| "ăn sáng" (không có số) | Record, amount = null | LLM trả về amount=null, response hỏi thêm số tiền |
| "hôm nay trời đẹp quá" | Chitchat | LLM dùng CHITCHAT_RULE, trả suggested_actions |
| "mua cà phê 35k" | Record, amount = 35000 | LLM trả đủ slots |
| "tiền ăn hôm nay hết bao nhiêu?" | Action (REPORT_GENERAL) | LLM dùng ACTION_RULE |

**Phân biệt Record thiếu tiền vs Chitchat** — quy tắc trong RECORD_RULE:

```
[PHÂN BIỆT RECORD vs CHITCHAT — ÁP DỤNG CHO CHAT]
- Nếu câu CÓ động từ hành động rõ ràng (ăn, mua, đổ, trả, nhận, chi, tiêu...)
  → Record, dù không có số tiền. amount = null.
- Nếu câu KHÔNG CÓ hành động rõ ràng, chỉ là trạng thái/cảm xúc/câu hỏi phiếm
  → Chitchat (Stage 1 phải đã phân loại đúng).
- Ví dụ Record thiếu tiền: "ăn sáng nè", "vừa mua cái áo", "đổ xăng rồi".
- Ví dụ Chitchat: "hôm nay mệt quá", "ăn gì ngon không", "shopee sale rồi nhé".
```

**response khi amount = null trong chat:**
```
"Mimo ghi nhận {item} cho {tên} rồi nha! Bạn chi hết bao nhiêu vậy? 💰"
```

### 6.2 AddStory (`/nlu/infer` với `caller_context = "addstory"`)

Khi request đến từ màn hình AddStory của app:
- **Bỏ qua Stage 1 hoàn toàn**, đặt `intent = "Record"` trực tiếp.
- Chỉ dùng RECORD_RULE để trích xuất: category, record_type, amount, item.
- Chỉ cần check: amount có null không?
  - Nếu null → response yêu cầu nhập số tiền.
  - Nếu có → ghi nhận bình thường.

**Thêm field vào NLURequest:**

```python
class NLURequest(BaseModel):
    text: str
    caller_context: str | None = Field(default="chat",
        description="'chat' (mặc định) hoặc 'addstory' (bỏ qua Stage 1)")
    # ... các field cũ
```

**Trong pipeline.py:**

```python
if request.caller_context == "addstory":
    # Skip Stage 1, force Record
    result = run_llm_nlu_v2(text, context_metadata, nlg_persona, forced_intent="Record")
    return result
```

---

## 7. Model loading — workspace vs storage, lưu cả 2 nơi

### Logic load model khi startup

```python
def _load_intent_model_with_version_check():
    """So sánh model ở workspace và storage, lấy cái mới hơn."""
    workspace_path = TEXT_NLU_DIR / "models" / "intent_model.joblib"
    storage_path = Path("/storage/nlu_models/intent_model.joblib")

    workspace_mtime = workspace_path.stat().st_mtime if workspace_path.exists() else 0
    storage_mtime = storage_path.stat().st_mtime if storage_path.exists() else 0

    if storage_mtime > workspace_mtime:
        # Storage có model mới hơn → copy về workspace rồi load
        shutil.copy2(storage_path, workspace_path)
        logger.info("Loaded intent model from /storage (newer)")
    else:
        logger.info("Loaded intent model from workspace")

    return joblib.load(workspace_path)
```

Áp dụng cho: `intent_model.joblib`, `encoder_metrics.json`, `retrain_all_metrics.json`, `nlu_model_registry.json`.

### Logic lưu model sau khi train xong

```python
# Trong run_retraining() — sau khi retrain thành công
# Bước 1: Lưu vào workspace
local_models_dir = nlu_dir / "text_nlu" / "models"

# Bước 2: Đồng bộ lên storage
if Path("/storage").exists():
    storage_models_dir = Path("/storage/nlu_models")
    storage_models_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy intent model (và chỉ intent model với kiến trúc mới)
    for f in local_models_dir.glob("intent_*.joblib"):
        shutil.copy2(f, storage_models_dir / f.name)
    
    # Copy metrics và registry
    for f in local_models_dir.glob("*.json"):
        shutil.copy2(f, storage_models_dir / f.name)
    
    logger.info("Synced new intent model to /storage/nlu_models")
```

---

## 8. Dữ liệu fine-tune Qwen

### Cấu trúc file `train_llm_finetune_data_import.json`

Lấy ngẫu nhiên từ CSDL, đủ phân phối category/action_type. Quan trọng: bao gồm **response + emotion**:

```json
[
  {
    "instruction": "<RECORD_RULE system>",
    "input": "Ngữ cảnh hệ thống (CONTEXT_META): {\"user_name\": \"Mai Khang\", \"time_of_day\": \"buổi sáng\", \"weather\": \"nắng\"}\nCâu thoại của người dùng: ăn sáng 35k",
    "output": "{\"record_type\": \"Expense\", \"slots\": {\"item\": \"ăn sáng\", \"category\": \"Food\", \"amount\": 35000}, \"emotion\": \"Chill\", \"response\": \"Sáng sớm nắng ấm thế này Mai Khang đã ăn sáng 35k rồi hả! Mimo ghi lại cho bạn rồi nha. ☀️\", \"suggested_actions\": null}"
  },
  {
    "instruction": "<ACTION_RULE system>",
    "input": "Ngữ cảnh hệ thống (CONTEXT_META): {\"user_name\": \"An\", \"budget_remain\": 2500000}\nCâu thoại của người dùng: tháng này tôi tiêu bao nhiêu",
    "output": "{\"action_type\": \"REPORT_GENERAL\", \"slots\": {\"category\": null, \"time_range\": \"tháng này\", \"amount\": null}, \"emotion\": \"Thinking\", \"response\": \"Để Mimo tổng kết chi tiêu tháng này cho An xem nha! 📊\", \"suggested_actions\": null}"
  },
  {
    "instruction": "<CHITCHAT_RULE system>",
    "input": "Câu thoại của người dùng: hôm nay trời đẹp quá",
    "output": "{\"emotion\": \"Happy\", \"response\": \"Trời đẹp thật nha! ☀️ Ngày đẹp mà chi tiêu hợp lý thì càng vui hơn. Bạn có muốn ghi lại khoản gì hôm nay không?\", \"suggested_actions\": [\"Thêm giao dịch\", \"Xem báo cáo\", \"Quét hóa đơn\"]}"
  }
]
```

Số lượng đề xuất: 500-1000 mẫu (đủ cho LoRA fine-tune với Qwen2.5-3B). Tỷ lệ: 50% Record, 35% Action, 15% Chitchat.

---

## 9. Retrain NLU — chỉ intent model, chạy trên Modal

### Những gì cần train

| Model | Train ở đâu | Script |
|---|---|---|
| Intent TF-IDF (Record/Action/Chitchat) | Modal Cloud (GPU) | `text_nlu/train/retrain_all.py` (chỉ phần intent) |
| Intent PhoBERT encoder | Modal Cloud (GPU) | `text_nlu/train/retrain_encoders.py` |

Không còn train: category, record_type, action_type, action_slots, NER (LLM Qwen xử lý tất cả).

### Nguồn dữ liệu train

- Tầng 1 (`nlu_corrections`): mẫu sai category mà admin đã sửa thủ công → đổi nhãn thành intent + category.
- Tầng 2 aggregations: mẫu từ CSDL thực tế → loại bỏ mẫu sai, giữ mẫu đúng.
- Nếu tầng 2 chưa có → dùng dataset gốc: `intent_record.csv`, `intent_action.csv`, `intent_chitchat.csv`.

---

## 10. Áp dụng model mới — thủ công cho Stage 1 (intent classifier)

> "Apply" = chuyển từ model intent classifier cũ sang mới. Không phải thay đổi Stage 2 LLM (LLM không cần train lại, chỉ sửa rule).

### Quy trình

```
Retrain xong → Model lưu ở workspace + storage (pending)
→ NluOpsPage hiển thị badge "Có model mới: Intent F1 = 92.4%"
→ Admin so sánh với model cũ: F1 mới vs F1 cũ
→ Nhấn nút "Áp dụng model mới"
→ Hot-reload (không restart server): get_nlu_service().reload()
```

### Điều kiện tự động áp dụng (tùy chọn)

Chỉ auto-apply khi đủ 3 điều kiện:
1. Intent F1 macro mới ≥ 0.90
2. F1 mới tốt hơn model đang chạy ít nhất 0.5%
3. Số mẫu train ≥ 500 câu

---

## 11. Thanh tiến trình train WebAdmin

### NLU training stages

| Stage | Percent | Message hiển thị |
|---|---|---|
| PREPARING | 10% | Đang lấy dữ liệu từ CSDL... |
| CLEANING | 25% | Đang lọc mẫu sai, giữ mẫu đúng... |
| TRAINING | 50% | Đang huấn luyện intent model trên Modal... |
| EVALUATING | 75% | Đang tính Intent F1, Accuracy... |
| SYNCING | 90% | Đang lưu model vào workspace và storage... |
| SUCCESS | 100% | Hoàn tất! Intent F1: 92.4% |

Thanh tiến trình **hiển thị real-time** ở NluOpsPage → WebAdmin poll `/nlu/train/status` mỗi 3 giây khi `training_active = true`.

### OCR training stages — thêm mới

Tương tự NLU, thêm endpoint `GET /ocr/train/status` và cập nhật `BillRetrainPage.jsx`.

---

## 12. Test nhanh với `modal serve`

Để test Qwen2.5 với logic mới trước khi deploy:

```bash
# Terminal 1: chạy Modal serve
modal serve modal_app.py

# Terminal 2: test 10 câu mẫu
python -c "
import os
os.environ['USE_MODAL_PHOGPT'] = '1'
from src.nlu.llm_intent_handler import run_llm_nlu_v2

test_cases = [
    ('ăn sáng 35k', 'chat'),
    ('đổ xăng 100k', 'chat'),
    ('ăn sáng nè', 'chat'),                    # Record thiếu amount
    ('hôm nay trời đẹp quá', 'chat'),          # Chitchat
    ('tháng này tiêu bao nhiêu', 'chat'),      # Action REPORT_GENERAL
    ('đặt hạn mức ăn uống 3 triệu', 'chat'),   # Action SET_LIMIT
    ('tạo mục tiêu tiết kiệm 10 triệu', 'chat'), # Action SET_GOAL
    ('nhận lương 10 triệu', 'chat'),            # Record Income
    ('mua áo shopee', 'addstory'),             # AddStory luôn Record
    ('mua đồ cho người yêu 200k', 'chat'),     # Record với relationship rule
]
for text, ctx in test_cases:
    r = run_llm_nlu_v2(text, caller_context=ctx)
    print(f'[{ctx}] {text!r} → intent={r[\"intent\"]}, category={r.get(\"slots\",{}).get(\"category\")}, amount={r.get(\"slots\",{}).get(\"amount\")}')
"
```

---

## 13. Checklist thay đổi

### FastAPI AI

- [ ] Xóa `src/llm/gemini_keys.py`
- [ ] Sửa `src/llm/client.py` — xóa Gemini, chỉ giữ `call_qwen`
- [ ] Sửa `src/nlu/llm_intent_handler.py` — xóa Gemini block, thêm `run_llm_nlu_v2()` + `_build_persona_addition()` + `_build_relationship_addition()`
- [ ] Sửa `src/nlg/llm_runner.py` — xóa Gemini
- [ ] Sửa `src/nlu/disambiguation_generator.py` — xóa Gemini
- [ ] Tạo `src/prompts/llm_rules.json` với 3 rule block + `action_slot_schema`
- [ ] Sửa `src/nlu/pipeline.py` — thêm nhánh `llm_v2` + xử lý `caller_context == "addstory"`
- [ ] Sửa `src/api/app/schemas/nlu.py` — thêm `caller_context`, đổi `gemini_json` → `llm_json`
- [ ] Sửa `src/api/app/services/nlu_service.py` — xóa reference `gemini_json`
- [ ] Sửa `src/api/app/adapters/expense_ocr_nlu.py` — thêm version check workspace vs storage khi load
- [ ] Sửa `text_nlu/train/retrain_all.py` — chỉ train intent model
- [ ] Sửa `run_retraining()` trong `nlu.py` — lưu model vào cả workspace và storage
- [ ] Thêm endpoint `POST /nlu/benchmark/llm-rules` với golden set 50 câu
- [ ] Thêm endpoint `GET /ocr/train/status`
- [ ] Xóa `.env` keys Gemini

### Backend Node.js

- [ ] Kiểm tra xóa Gemini call trong `src/modules/` và `src/services/`
- [ ] Thêm `checkMissingSlots()` trong `action.service.js` dùng `action_slot_schema`
- [ ] Trả về `missing_slots[]` trong response khi có trường thiếu

### WebAdmin

- [ ] `NluOpsPage`: Bỏ Import CSV, bỏ auto-retrain tầng 2
- [ ] `NluOpsPage`: Cập nhật `COMPARISON_ROWS` chỉ giữ intent model rows
- [ ] `NluOpsPage`: Thêm tab/section "Benchmark LLM Rules" với 3 metric
- [ ] `NluOpsPage`: Thêm badge model mới + nút so sánh + nút Áp dụng
- [ ] `NluOpsPage`: Thanh tiến trình train với 6 stage
- [ ] `BotPromptsPage`: Sửa test prompt dùng `run_llm_nlu_v2`, thêm dropdown caller_context (chat/addstory)
- [ ] `BillRetrainPage`: Thêm thanh tiến trình OCR retrain
- [ ] Dashboard: Đổi nhãn "NLU Accuracy" → "Intent Accuracy"
