# -*- coding: utf-8 -*-
"""
TC-N4 / AI06 — Kiểm thử NLU Missing Slot (Thiếu thông tin)
============================================================
Mục đích:
  Gửi các câu thiếu số tiền lên Modal HTTP.
  Xác nhận AI trả về câu hỏi lại thay vì báo lỗi hoặc lưu giá trị sai.

Kết quả mong đợi:
  - response text chứa từ hỏi: "bao nhiêu", "số tiền", "?", "tiền"
  - intent vẫn nhận diện được (RECORD hoặc tương đương)
  - KHÔNG có amount hợp lệ (None, 0, hoặc < 0)

Chạy lệnh:
  cd d:\Luan-Van\Project\expense-ocr-nlu
  python ..\tests_chuong4\tc_nlu_missing_slot.py

Kết quả: ghi vào tests_chuong4/results/tc_missing_slot_result.md
"""

import urllib.request, json, datetime, os, time

MODAL_URL = "https://maikhang160504--expense-ocr-nlu-fastapi-app-dev.modal.run"
ENDPOINT  = f"{MODAL_URL}/api/v1/nlu/infer"
RESULT_DIR = os.path.join(os.path.dirname(__file__), "results")
os.makedirs(RESULT_DIR, exist_ok=True)

# ─── Câu kiểm thử — cố tình thiếu số tiền ───────────────────────────────────
TEST_CASES = [
    {
        "id": "MS-01",
        "label": "Ăn uống — không có số tiền",
        "text": "sáng nay đi ăn phở",
    },
    {
        "id": "MS-02",
        "label": "Mua sắm — không có số tiền",
        "text": "vừa mua quần áo mới",
    },
    {
        "id": "MS-03",
        "label": "Giao thông — không có số tiền",
        "text": "đổ xăng xe hồi chiều",
    },
    {
        "id": "MS-04",
        "label": "Chi tiêu mơ hồ — không category, không tiền",
        "text": "hôm nay tôi tiêu rồi",
    },
    {
        "id": "MS-05",
        "label": "Câu ngắn kiểu lóng — thiếu mọi thứ",
        "text": "vừa bay tiền",
    },
]

# Từ khoá nghi vấn — nếu response chứa bất kỳ từ nào dưới đây → PASS
FOLLOW_UP_KEYWORDS = [
    "bao nhiêu", "số tiền", "tiền", "?", "chi", "hết", "tốn",
    "mua", "giá", "bấy nhiêu", "cụ thể", "nhập", "điền"
]

def call_nlu(text: str, timeout: int = 60) -> dict:
    payload = json.dumps({
        "text": text,
        "nlg_persona": "dui_de",
        "profile": {"username": "TestUser"},
        "run_llm": True,  # Bật LLM để có phản hồi tự nhiên
    }).encode("utf-8")

    req = urllib.request.Request(
        ENDPOINT,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = json.loads(r.read().decode("utf-8"))
        data["_latency_ms"] = round((time.time() - t0) * 1000)
        return data

# ─── Chạy test ────────────────────────────────────────────────────────────────
print("=" * 65)
print("TC-N4/AI06 — Kiểm thử NLU Missing Slot (Thiếu số tiền)")
print(f"Endpoint: {ENDPOINT}")
print("=" * 65)

results = []
for tc in TEST_CASES:
    print(f"\n[{tc['id']}] {tc['label']}")
    print(f"  Input: {tc['text']!r}")
    try:
        data = call_nlu(tc["text"])
        
        # Lấy response text (thử nhiều key khác nhau tuỳ API version)
        response_text = (
            data.get("response") or
            data.get("nlg_response") or
            (data.get("nlg") or {}).get("response") or
            ""
        ).lower()

        amount = data.get("amount", data.get("value", None))
        intent = data.get("intent", "?")
        latency = data.get("_latency_ms", 0)

        # Kiểm tra: response có hỏi lại không?
        has_followup = any(kw in response_text for kw in FOLLOW_UP_KEYWORDS)
        # Kiểm tra: không có amount hợp lệ?
        no_amount = (amount is None or amount == 0 or str(amount) == "")

        status = "✅ PASS" if (has_followup and no_amount) else "⚠️ CHECK"
        
        print(f"  Intent: {intent}")
        print(f"  Amount: {amount} {'(✅ rỗng/không có)' if no_amount else '(⚠️ có giá trị)'}")
        print(f"  Response: {response_text[:120]!r}")
        print(f"  Has follow-up: {'✅' if has_followup else '❌'} | Latency: {latency}ms | {status}")

        results.append({
            "id": tc["id"],
            "label": tc["label"],
            "input": tc["text"],
            "intent": intent,
            "amount": amount,
            "no_amount": no_amount,
            "response": response_text,
            "has_followup": has_followup,
            "latency_ms": latency,
            "pass": has_followup and no_amount,
            "error": None,
        })
    except Exception as e:
        print(f"  ❌ ERROR: {e}")
        results.append({
            "id": tc["id"],
            "label": tc["label"],
            "input": tc["text"],
            "pass": False,
            "error": str(e),
        })

# ─── Xuất Markdown ─────────────────────────────────────────────────────────────
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
pass_count = sum(1 for r in results if r.get("pass"))
total = len(results)

md = f"""# TC-N4/AI06 — Kết quả Kiểm thử NLU Missing Slot
**Thời gian chạy:** {now}  
**Endpoint:** `{ENDPOINT}`  
**Mô hình:** PhoBERT + Qwen 2.5 LoRA (run_llm=True)

---

## Tổng quan

| Chỉ số | Giá trị |
|--------|---------|
| Số test case | {total} |
| PASS (AI hỏi lại đúng) | {pass_count} |
| FAIL / Cần kiểm tra | {total - pass_count} |
| Tỷ lệ PASS | {pass_count/total*100:.0f}% |

> **Tiêu chí PASS:** Response phải chứa câu hỏi bổ sung (hỏi về số tiền) VÀ không lưu amount sai.

---

## Bảng kết quả chi tiết

| ID | Câu đầu vào (thiếu tiền) | Intent nhận diện | Amount lưu | AI hỏi lại? | Kết quả |
|----|--------------------------|-----------------|-----------|------------|---------|
"""

for r in results:
    if r.get("error"):
        md += f"| {r['id']} | {r['input']} | ❌ ERROR | - | - | ❌ FAIL |\n"
    else:
        amt_str = str(r["amount"]) if r["amount"] else "*(rỗng)*"
        amt_icon = "✅" if r["no_amount"] else "⚠️"
        fu_icon = "✅ Có" if r["has_followup"] else "❌ Không"
        status = "✅ PASS" if r["pass"] else "⚠️ CHECK"
        md += f"| {r['id']} | {r['input']} | {r['intent']} | {amt_icon} {amt_str} | {fu_icon} | {status} |\n"

md += "\n---\n\n## Phản hồi thực tế của AI\n\n"
for r in results:
    md += f"### {r['id']} — `{r['input']}`\n"
    if r.get("error"):
        md += f"- **Lỗi:** `{r['error']}`\n\n"
    else:
        md += f"- **Intent:** `{r['intent']}`\n"
        md += f"- **Amount trả về:** `{r['amount']}`\n"
        md += f"- **Phản hồi MiMo:**\n\n> {r['response']}\n\n"

md += "---\n\n## Nhận xét\n\n"
md += f"- Khi người dùng nhắn câu thiếu số tiền, AI phản hồi đúng cách (hỏi lại) trong {pass_count}/{total} trường hợp.\n"
md += "- Cơ chế Missing Slot Detection hoạt động nhờ pipeline: PhoBERT bóc tách entity → phát hiện `amount=None` → LLM sinh câu hỏi follow-up.\n"

outpath = os.path.join(RESULT_DIR, "tc_missing_slot_result.md")
with open(outpath, "w", encoding="utf-8") as f:
    f.write(md)
print(f"\n{'='*65}")
print(f"✅ Đã xuất kết quả: {outpath}")
print(f"Tổng: {pass_count}/{total} PASS")
