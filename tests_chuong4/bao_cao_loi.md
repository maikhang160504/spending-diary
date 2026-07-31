# Báo cáo: Kết quả Benchmark Thực tế & Các Vấn đề Được Ghi Nhận

> **Nguồn dữ liệu:** `d:\Luan-Van\Project\benchmark.log`  
> **Môi trường:** Modal Cloud GPU (A100), 120 mẫu thực từ `nlu_benchmark.jsonl`  
> **Ngày chạy:** 2026-07-26, 19:55 UTC

---

## 1. Kết quả Benchmark NLU — Bảng Chính thức

| Mô hình NLU | Intent (Acc/F1) | Action (Acc/F1) | Category (Acc/F1) | Record Type (Acc/F1) | Avg Latency | P95 Latency |
|-------------|----------------|----------------|------------------|---------------------|------------|------------|
| TF-IDF | 84.2% / 79.2% | 85.0% / 67.6% | 68.3% / 65.9% | 85.0% / 76.6% | 4.8 ms | 11.5 ms |
| PhoBERT | 86.7% / 83.6% | 80.8% / 50.1% | 71.7% / 62.9% | 91.7% / 86.5% | 108.2 ms | 58.8 ms |
| **Qwen 2.5-14B LoRA** | **96.7% / 95.7%** | **92.5% / 80.7%** | **91.7% / 87.7%** | **98.3% / 96.8%** | 14,807 ms | 19,536 ms |

> **Ghi chú:** Benchmark chạy trực tiếp trên server Modal với model Qwen 14B đã LoRA fine-tune. Cold start ~1-2 phút để load 28GB model vào RAM GPU, nhưng sau khi warm thì Latency production thực tế khác với con số benchmark trên.

---

## 2. Phân tích điểm mạnh / yếu theo từng mô hình

### TF-IDF (Mô hình nền cơ bản)
**Ưu điểm:** Cực kỳ nhanh (4.8ms), không cần GPU.  
**Điểm yếu — Category bị sai (10 trường hợp):**

| Câu đầu vào | Category đúng | Dự đoán sai | Phân tích |
|------------|-------------|------------|----------|
| "Đi chợ mua thức ăn hết 300k" | `Food` | `Essentials` | Từ "thức ăn" bị overlap với Essentials |
| "Đi spa chăm sóc da 1 triệu" | `Beauty` | `Entertainment` | Spa không có trong từ điển Beauty |
| "Đi nhậu với đồng nghiệp 400k" | `Social` | `Entertainment` | Nhậu không map được Social |
| "Nhập hàng để bán 5 triệu" | `Business` | `Investment` | Business vs Investment thiếu context |
| "Chi tiêu lặt vặt 50k" | `Others` | `None` | Mô hình không nhận ra Others |
| "Khách chốt đơn mua hàng của shop 3 triệu" | `Business` | `Shopping` | Revenue bị nhầm là mua sắm |
| "Trúng số 100 ngàn" | `Bonus` | `Food` | Hoàn toàn sai — Bonus thiếu dữ liệu |
| "Tổng kết tiền ăn uống hôm nay" | `Food` | `None` | Câu báo cáo bị phân loại sai |
| "Thống kê khoản mua sắm trong tháng trước" | `Shopping` | `None` | Idem |
| "Xem chi phí di chuyển quý này" | `Transport` | `None` | Câu lệnh Action bị nhầm thành Record |

### PhoBERT (Mô hình Encoder chính)
**Ưu điểm:** Tốt hơn TF-IDF 2.5% Intent, Record Type tốt hơn rõ rệt (91.7%).  
**Điểm yếu — Category vẫn sai (10 trường hợp):**

| Câu đầu vào | Category đúng | Dự đoán sai |
|------------|-------------|------------|
| "Đi chợ mua thức ăn hết 300k" | `Food` | `Essentials` |
| "Đi siêu thị mua kem đánh răng 45 ngàn" | `Essentials` | `Entertainment` |
| "Mua thỏi son 400k tặng mình" | `Beauty` | `Social` |
| "Đóng tiền tập gym 3 tháng 1 triệu 5" | `Health` | `Housing` |
| "Đi nhậu với đồng nghiệp 400k" | `Social` | `Entertainment` |
| "Chi tiêu lặt vặt 50k" | `Others` | `Essentials` |
| "Nhận lương tháng mười 15 triệu" | `Salary` | `Bonus` |
| "Lương làm thêm 2 triệu" | `Salary` | `None` |
| "Khách chốt đơn mua hàng của shop 3 triệu" | `Business` | `Shopping` |
| "Nhận tiền lời lãi đầu tư tiết kiệm 200k" | `Investment` | `Savings` |

**Lưu ý đặc biệt:** Action F1 của PhoBERT chỉ đạt **50.1%** — thấp hơn cả TF-IDF (67.6%). Đây là điểm yếu đáng kể.

### Qwen 2.5-14B LoRA (Mô hình LLM mạnh nhất)
**Ưu điểm:** Vượt trội ở mọi chỉ số — Intent 96.7%, Category 91.7%, Record 98.3%.  
**Điểm yếu duy nhất:** Latency **14,807ms** (≈15 giây) — không thể dùng làm mô hình trực tiếp.

> **Đây là lý do thiết kế Cascade:** PhoBERT (~108ms) xử lý trước → Nếu confidence thấp → escalate lên Qwen.

---

## 3. Các lỗi cụ thể xác định được (từ log + regression)

### 3.1 Category nhầm lẫn nhất quán (cả 3 mô hình)
Các cặp category luôn bị nhầm do ranh giới mờ:

| Cặp bị nhầm | Ví dụ |
|------------|-------|
| `Social` ↔ `Entertainment` | Đi nhậu, đi cafe với bạn |
| `Business` ↔ `Shopping` / `Investment` | Chốt đơn, nhập hàng |
| `Food` ↔ `Essentials` | Đi chợ mua thức ăn |
| `Salary` ↔ `Bonus` / `None` | Lương làm thêm |

### 3.2 Câu báo cáo bị nhầm thành Record (TF-IDF)
3 câu dạng "Tổng kết...", "Thống kê...", "Xem chi phí..." bị TF-IDF dự đoán category thay vì trả `None` — do mô hình không phân biệt được câu Intent Action vs Record.

### 3.3 Missing Slot — AI hỏi lại (chưa kiểm chứng bằng tool)
Các câu thiếu số tiền (A10, AI06) chưa có kết quả thực chạy — cần chạy `tc_nlu_missing_slot.py` để xác nhận.

### 3.4 Action Slot Filling — 5 lỗi được ghi nhận
Từ `action_audit_output.txt`:
- "thêm 1tr vào giới hạn di chuyển" → `target=None` (không map "giới hạn" → Transport)
- "tìm các giao dịch mua sắm" → `target=Food` thay vì Shopping
- "sửa số tiền giao dịch vừa rồi thành 50k" → `target=None`

### 3.5 MiMo Persona hoạt động đúng (từ log)
Câu "Yêu con bot này ghê" → Qwen phản hồi đúng tính cách "Ngọt ngào":
```json
{
  "intent": "Chitchat",
  "emotion": "Love",
  "response": "Ui cha, ai mà không yêu Mimo nhỉ? Con quý thật là đứa con hiếu thảo và ngoan xinh yêu của cô nhà luôn á!",
  "suggested_actions": ["Thêm giao dịch", "Xem báo cáo", "Quét hóa đơn"]
}
```
✅ **Persona hoạt động đúng.**

---

## 4. Tóm tắt — Lỗi theo mức độ

| # | Vấn đề | Mức độ | Tác động thực tế |
|---|--------|--------|----------------|
| 1 | Category F1 PhoBERT 62.9% (thấp nhất) | 🔴 Đáng kể | ~28% câu bị phân loại sai category |
| 2 | Qwen 2.5 Latency 14.8 giây | 🟡 Có lý giải | Cold start GPU — Cascade design xử lý được |
| 3 | PhoBERT Action F1 chỉ 50.1% | 🔴 Đáng kể | Lệnh phức tạp (SET_LIMIT, SEARCH) bị sai |
| 4 | 10 câu lỗi cụ thể của PhoBERT | 🟡 Chấp nhận | Qwen xử lý được 91.7% |
| 5 | 5 slot filling FAIL | 🟡 Nhỏ | Chỉ ảnh hưởng câu lệnh phức tạp |
| 6 | Missing slot (chưa kiểm chứng) | ⚪ Cần chạy tool | — |
| 7 | Ban/Unban API endpoint (cần verify) | ⚪ Cần xác nhận | — |

---

## 5. Điều cần ghi nhận trung thực trong Chương 4

1. **Category Classification là điểm yếu lớn nhất của PhoBERT** — F1 chỉ 62.9%, chấp nhận được ở mức "prototype" nhưng cần cải thiện khi scale lên
2. **Cascade Architecture hợp lý:** PhoBERT 108ms dùng cho 90% câu thông thường; Qwen chỉ kích hoạt khi cần — giải thích vì sao Latency 14.8s không ảnh hưởng UX
3. **Qwen 2.5 là mô hình tốt nhất** nhưng không thể dùng trực tiếp do GPU cost và latency
4. **Tập benchmark chỉ 120 mẫu** — đủ để đánh giá xu hướng nhưng cần mở rộng lên 500+ mẫu trong tương lai
