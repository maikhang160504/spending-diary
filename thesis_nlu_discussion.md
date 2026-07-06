# Báo cáo Bàn luận & Định hướng Kỹ thuật Luận văn (Bản cập nhật)

Báo cáo này tập hợp các thảo luận chi tiết dựa trên định hướng phát triển luận văn, tập trung vào mô hình **PhoGPT-7B**, kiến trúc sinh phản hồi kèm cảm xúc, tối ưu hóa token và các thuật toán tài chính khoa học.

---

## 1. Triển khai và Tích hợp PhoGPT-7B (VinAI)

### Kiến trúc Triển khai:
- **Quantization:** Do PhoGPT-7B (7 tỷ tham số) chạy nguyên bản cần cấu hình phần cứng rất lớn, chúng ta sẽ sử dụng phiên bản **4-bit Quantized (GGUF)** để giảm tải dung lượng mô hình xuống còn khoảng ~4.3 GB.
- **Môi trường chạy:** Chạy thông qua **llama.cpp**, **Ollama**, hoặc **LM Studio** dưới dạng một container Docker độc lập (`ai-service-llm`). Container này sẽ mở một cổng API tương thích với OpenAI API (`http://localhost:1234/v1`).
- **Phần cứng yêu cầu:** Khoảng 8GB VRAM (nếu dùng GPU RTX 3060/4060) hoặc 16GB RAM (nếu chạy hoàn toàn trên CPU của VPS).

---

## 2. Luồng Sinh Phản Hồi kèm Cảm Xúc (Emotion & Response Generation)

LLM không chỉ trích xuất thông tin cấu trúc mà còn kiêm nhiệm việc tạo câu phản hồi và gắn thẻ cảm xúc cho mascot Mimo.

### Cấu trúc Output của LLM (JSON format):
Mô hình PhoGPT-7B sẽ được huấn luyện (fine-tune) để luôn trả ra định dạng JSON sau:
```json
{
  "intent": "Record",
  "action_type": null,
  "slots": {
    "category": "Food",
    "amount": 50000,
    "note": "ăn bún bò"
  },
  "emotion": "happy",
  "response": "Đã ghi nhận 50.000đ cho tô bún bò ngon lành rồi nha! Ăn uống đầy đủ sức khỏe nhé."
}
```

### Quản lý Emotion trên Giao diện:
- Mô hình phân loại cảm xúc thành 5 nhóm chính: `happy` (vui vẻ), `sad` (buồn bã - khi chi tiêu quá nhiều), `neutral` (bình thường), `strict` (nghiêm khắc - khi vượt hạn mức), `alarmed` (cảnh báo).
- Mascot Mimo trên ứng dụng client (Flutter/Web) sẽ thay đổi sprite/animation tương ứng với trường `emotion` nhận được từ API.

---

## 3. Nhận dạng Danh mục (Category) cho Hóa đơn bằng LLM

Hệ thống giữ nguyên luồng xử lý ảnh hóa đơn (OCR pipeline) hiện tại và chỉ thay thế tầng phân loại bằng LLM:

```
[Ảnh Hóa đơn] ──> [OCR Engine] ──> [Trích xuất Văn bản/Sản phẩm] ──> [LLM Classifier Prompt] ──> [Mapped Category]
```

- **Quy trình hoạt động:** OCR sẽ trích xuất tên sản phẩm hoặc ghi chú hóa đơn (ví dụ: *"Cơm sườn 45k"*, *"Trà sữa Koi 60k"*).
- Thay vì truyền chuỗi này vào TF-IDF hoặc Encoder cục bộ, backend sẽ gửi một Prompt ngắn tới PhoGPT-7B yêu cầu trả ra mã danh mục:
  - *Prompt:* `"Phân loại danh mục chi tiêu cho sản phẩm: 'Trà sữa Koi'. Các nhãn hợp lệ: Food, Transport, Shopping, Entertainment, Housing, Education, Health, Beauty, Essentials, Others. Chỉ trả ra mã nhãn."`
  - *LLM Output:* `Food`

---

## 4. Triển khai Tính năng Chuyển đổi Mô hình (Switch Backend) trên Webadmin

Để so sánh độ chính xác trực quan giữa các mô hình phục vụ đánh giá trong luận văn, bạn có thể thiết kế tính năng switch mô hình trên Webadmin như sau:

### Cơ chế hoạt động:
1. **Lưu trữ Cấu hình:** Lưu cấu hình mô hình hiện tại (`NLU_BACKEND = 'tfidf' | 'encoder' | 'llm'`) vào bảng `system_settings` trong cơ sở dữ liệu.
2. **Giao diện Webadmin (UI):** Thiết lập một trang quản trị cấu hình AI có dropdown cho phép admin chọn 1 trong 3 mô hình và nhấn "Lưu". API endpoint tương ứng sẽ là `PUT /api/admin/settings/nlu-backend`.
3. **Định tuyến NLU trên Backend (API):**
   Trong file xử lý NLU trung tâm (ví dụ `ai.service.js`):
   ```javascript
   const currentBackend = await settingsService.getNluBackend();
   
   if (currentBackend === 'llm') {
     return callPhoGPTService(text);
   } else if (currentBackend === 'encoder') {
     return callEncoderService(text);
   } else {
     return callTfidfService(text);
   }
   ```

---

## 5. Thu thập mẫu, Retrain & Cá nhân hóa NLU với LLM

### Vấn đề tốn Token khi dùng Few-shot Prompting kèm Context:
Nếu chúng ta đưa toàn bộ lịch sử chi tiêu và danh sách quy tắc của người dùng vào prompt, số lượng token sẽ bùng nổ, gây tăng chi phí và chậm thời gian phản hồi (latency).

#### Giải pháp khắc phục tối ưu (Cách đang triển khai):
1. **Lọc ngữ cảnh thông minh (Vector / Keyword Search):** Không gửi toàn bộ quy tắc cá nhân hóa. Backend sẽ phân tích từ khóa trong câu của user, chỉ truy vấn tối đa **3 quy tắc liên quan nhất** từ DB để đính kèm vào Prompt.
2. **Hậu xử lý cục bộ (Local Post-processing - Khuyến nghị):**
   - Hãy để LLM phân loại ra nhãn danh mục chung (General Category).
   - Backend sau khi nhận kết quả từ LLM sẽ đối chiếu với **từ điển cá nhân hóa lưu cục bộ trong DB** của user đó. Nếu có quy tắc ghi đè (ví dụ: *"sách"* luôn đổi thành *Education*), backend sẽ tự động sửa lại nhãn trước khi lưu vào DB.
   - **Ưu điểm:** Tiết kiệm 100% chi phí token cho phần cá nhân hóa, xử lý tức thì, tránh lỗi ảo tưởng của LLM.

### Luồng Retrain QLoRA:
Hiện tại, hệ thống xuất dữ liệu ra file CSV (`intent_record.csv`, `intent_action.csv`...). Chúng ta sẽ bổ sung một worker xuất bản tập dữ liệu định dạng JSONL chuyên biệt cho huấn luyện LLM:
```json
{"instruction": "Phân tích ý định và trích xuất thực thể tài chính cá nhân.", "input": "thêm 200k vào ăn uống", "output": "{\"intent\": \"Action\", \"action_type\": \"SET_LIMIT\", \"slots\": {\"category\": \"Food\", \"amount\": 200000, \"verb\": \"ADD\"}}"}
```
Tệp JSONL này sẽ được tự động tải lên thư mục train của PhoGPT để chạy script fine-tune định kỳ thông qua Docker container.

---

## 6. Các thông số so sánh phục vụ đánh giá trong Luận văn

Hệ thống sẽ chạy thử nghiệm kiểm thử (Batch Testing) trên tập dữ liệu benchmark gồm 1000 câu mẫu để ghi nhận các thông số khoa học:
1. **Độ chính xác (Accuracy, Precision, Recall, F1-Score):** Tính độc lập cho cả 3 tác vụ: nhận dạng Intent, nhận dạng Category, và nhận dạng Slot (NER).
2. **Thời gian phản hồi trung bình (Average Latency - ms):** Đo thời gian từ lúc gửi text đến lúc nhận được JSON kết quả.
3. **Độ nhận dạng phức tạp (Semantic Complexity):** Đánh giá khả năng hiểu các câu đa ý định, câu phủ định, từ viết tắt, tiếng lóng, và chitchat tự nhiên.
4. **Tài nguyên tiêu thụ (Resource Footprint):** Dung lượng ổ đĩa lưu mô hình (MB), lượng RAM/VRAM sử dụng lúc chạy.

---

## 7. Giải quyết các vấn đề nghiệp vụ trong `fix.md` cho NLU & LLM

### 1. `REPORT_GENERAL` & `REPORT_COMPARE`
- **REPORT_GENERAL:** LLM trích xuất rõ ràng slot `time_range` (hôm nay, tuần này, tháng này, năm nay, từ ngày A đến ngày B) và `categoryCode` (nếu có, hoặc mặc định là tất cả).
- **REPORT_COMPARE:**
  - Nhận diện 2 dạng so sánh chính:
    1. *So sánh thời gian:* So sánh tổng chi tiêu kỳ này với kỳ trước (ví dụ: tháng này so với tháng trước cho tất cả danh mục).
    2. *So sánh danh mục:* So sánh chi tiêu giữa hai danh mục trong cùng một chu kỳ thời gian (ví dụ: ăn uống với đi lại tháng này).
  - Backend đã tích hợp hàm `resolveMultipleCategoryCodes` để tách biệt hai danh mục và thực hiện tính toán hiệu số trực tiếp từ Dashboard API của statsService.

### 2. `SET_GOAL` / `ADD_GOAL`
- **Vấn đề:** Tránh việc người dùng tạo mục tiêu tiết kiệm mới trong khi mục tiêu đó đã tồn tại (ví dụ: đã có *"Mua xe máy"*, người dùng lại yêu cầu *"đặt mục tiêu mua xe máy 20tr"*).
- **Giải pháp khả thi nhất:**
  - Khi nhận yêu cầu tạo/cập nhật mục tiêu, Backend sẽ thực hiện tìm kiếm mờ (Fuzzy matching dùng độ đo **Levenshtein Distance** hoặc **Cosine Similarity** dựa trên embeddings) của tên mục tiêu người dùng gửi lên với các mục tiêu hiện có trong DB của họ.
  - Nếu độ tương đồng **> 75%**, Backend sẽ xác định đây là mục tiêu cũ và cập nhật số tiền thay vì tạo mới, đồng thời gửi tin nhắn phản hồi làm rõ: *"Mimo đã cập nhật hạn mức cho mục tiêu 'Mua xe máy' hiện có của bạn rồi nhé!"*.

### 3. `SUGGEST_BUDGET`
- **Vấn đề:** Hệ thống chỉ tính toán gợi ý ngân sách dựa trên hạn mức chi tiêu thực tế của người dùng (những danh mục đã được đặt giới hạn - `SET_LIMIT`).
- **Giải pháp:**
  - Backend truy vấn danh sách hạn mức hiện tại từ bảng `budgets` của người dùng.
  - Chỉ tính toán đề xuất tăng/giảm hạn mức trên các danh mục đang được theo dõi hoạt động này để tránh làm xáo trộn các danh mục tự do khác.

---

## 8. Các vấn đề bàn luận bổ sung cho Luận văn

### 1. Luồng tự động hiển thị gợi ý đặt giới hạn cho danh mục mới
- **Kịch bản:** Người dùng chi tiêu cho một danh mục (ví dụ: *Beauty* - Làm đẹp) lần đầu tiên hoặc chi tiêu vượt trội mà danh mục đó chưa được đặt hạn mức chi tiêu (`spending limit`).
- **Flow xử lý:**
  - Khi ghi nhận giao dịch mới hoặc khi chạy báo cáo thống kê tuần, Backend kiểm tra nếu tổng chi tiêu của danh mục này chiếm trên **15% tổng thu nhập** của người dùng và danh mục này chưa có bản ghi hạn mức (`budget` limit).
  - Mascot Mimo sẽ đưa ra lời khuyên kèm theo một **Action Preview**: *"Mimo thấy bạn chi tiêu cho Làm đẹp khá nhiều trong tuần này nhưng chưa đặt hạn mức. Bạn có muốn đặt giới hạn chi tiêu cho danh mục này là 500k/tháng không?"*. Đi kèm là nút xác nhận nhanh trên giao diện để người dùng nhấn và kích hoạt lập tức.

### 2. Thuật toán tính toán hạn mức tiết kiệm khoa học
Để đưa ra con số tiết kiệm khoa học và thực tế cho người dùng, hệ thống áp dụng các công thức kinh tế học tài chính hành vi:

#### a. Quy tắc 50/30/20 (Quy tắc cơ bản của Elizabeth Warren):
- **50% thu nhập:** Chi tiêu thiết yếu (`Needs` - Housing, Transport, Food, Essentials).
- **30% thu nhập:** Chi tiêu cá nhân (`Wants` - Entertainment, Shopping, Beauty).
- **20% thu nhập:** Tích lũy & Đầu tư (`Savings` - Saving, Investment, Debt repayment).
- **Thuật toán gợi ý:**
  $$\text{Ngân sách tiết kiệm tối ưu} = \text{Tổng thu nhập cố định} \times 20\%$$

#### b. Thuật toán điều chỉnh động theo lịch sử chi tiêu (Dynamic Adjustments):
Nếu chi tiêu thiết yếu thực tế của người dùng vượt quá 50% (ví dụ ở các thành phố lớn hoặc sinh viên nghèo), hệ thống sẽ tính toán lại biên an toàn:
$$\text{Tiết kiệm tối thiểu} = \text{Tổng thu nhập} - \text{Chi tiêu thiết yếu tối thiểu} - (\text{Chi tiêu cá nhân} \times 50\%)$$
Công thức này đảm bảo tính khả thi thực tế của mục tiêu tiết kiệm, tránh việc ép người dùng đặt mục tiêu quá cao dẫn đến bỏ cuộc giữa chừng.

---

## 9. Thiết lập Cơ sở dữ liệu Giả lập (Mock Database) phục vụ Thực nghiệm

Để so sánh hiệu năng các mô hình một cách khách quan trong luận văn, chúng ta xây dựng một kịch bản giả lập cơ sở dữ liệu như sau:

### 1. Quy mô người dùng (Users Profile):
Xây dựng hồ sơ giả lập cho **150 người dùng** thuộc 3 nhóm đối tượng điển hình có hành vi tiêu dùng khác nhau:
- **Nhóm 1: Sinh viên (18-22 tuổi) - 50 người dùng:** Thu nhập thấp (~3 triệu - 5 triệu/tháng từ gia đình trợ cấp hoặc làm thêm). Chi tiêu tập trung vào: Ăn uống (Food), Giải trí (Entertainment), Giáo dục (Education). Hạn mức chi tiêu thấp.
- **Nhóm 2: Nhân viên văn phòng (23-35 tuổi) - 70 người dùng:** Thu nhập trung bình - cao (12 triệu - 30 triệu/tháng). Chi tiêu đa dạng: Mua sắm (Shopping), Làm đẹp (Beauty), Nhà ở (Housing), Di chuyển (Transportation). Hạn mức chi tiêu trung bình.
- **Nhóm 3: Người làm việc tự do / Kinh doanh (Freelancers) - 30 người dùng:** Thu nhập biến động thất thường. Lịch sử chi tiêu có nhiều khoản đầu tư, mua sắm lớn.

### 2. Dữ liệu giao dịch giả lập (Transactions History):
- Sinh ngẫu nhiên khoảng **15.000 giao dịch** phân bổ trong vòng **3 tháng gần nhất**.
- Thiết lập các thói quen chi tiêu thực tế (ví dụ: tiền nhà trừ vào ngày 1 hàng tháng, hóa đơn điện nước vào ngày 5, đi cà phê/xem phim tăng mạnh vào cuối tuần, nhận lương vào ngày 30).

### 3. Tập dữ liệu kiểm thử NLU (NLU Benchmark Dataset):
- Tạo bộ dữ liệu gồm **500 câu tiếng Việt** được gán nhãn thủ công chính xác đại diện cho tất cả các tình huống sử dụng thực tế.
- Bộ dữ liệu này sẽ được chạy hàng loạt qua cả 3 backend (TF-IDF, PhoBERT, PhoGPT-7B) trên cùng một máy chủ để thu thập các thông số độ chính xác (F1) và thời gian xử lý (Latency) làm số liệu biểu đồ cho Luận văn.
