Khi hệ thống scale lên hàng chục ngàn user hỏi đáp mỗi ngày, nếu không tối ưu Prompt, chi phí API (Token Consumption) sẽ tăng theo cấp số nhân, có thể ngốn sạch ngân sách dự án. Đối với một hệ thống FinTech, tối ưu chi phí vận hành (OpEx) của AI cũng quan trọng như tối ưu thuật toán.

Dưới đây là phân tích chi tiết về bản chất các vấn đề gây lãng phí token trong dự án của chúng ta và phương án tối ưu kiến trúc prompt để tiết kiệm chi phí lên tới 40% - 60%.
1. Hiện trạng & Bản chất các vấn đề gây tốn Token
Trong hệ thống "Ghi chép chi tiêu dạng Story", có 3 nguyên nhân chính đang âm thầm "đốt" token của hệ thống:

A. Gửi toàn bộ lịch sử chi tiêu thô (Raw Data Dumping)
Vấn đề: Khi user hỏi "Tháng này mình tiêu gì nhiều nhất?", lập trình viên thường có thói quen quét toàn bộ các dòng giao dịch trong DB của tháng đó (có thể lên tới 50 - 100 dòng) rồi ném thẳng chuỗi JSON thô đó vào Prompt cho LLM tự đọc và tính toán.

Hậu quả: Mỗi dòng giao dịch dạng JSON chứa rất nhiều ký tự thừa ({ "id": 123, "user_id": 456, "created_at": "2026-06-04..." }). Việc bắt LLM làm "máy tính cộng trừ" trên đống dữ liệu thô này cực kỳ lãng phí token ngữ cảnh (Input Tokens).

B. "Bức tường" System Prompt quá dài (Prompt Bloating)
Vấn đề: Để ép LLM trả về đúng định dạng JSON, đúng tone giọng của MiMo (thân thiện, dí dỏm) và không nói nhảm, chúng ta thường viết một System Prompt rất dài, nhồi nhét hàng tá quy tắc (Rules) và các ví dụ mẫu (Few-shot Examples).

Hậu quả: Nguyên lý của LLM là System Prompt sẽ bị tính tiền lại ở mỗi Request. Nếu System Prompt dài 1.000 tokens, chỉ cần user chat 10 câu qua lại là hệ thống đã mất đứt 10.000 tokens chỉ để đọc lại... chính cái luật đó.

C. Giữ lại toàn bộ lịch sử trò chuyện (Chat History Accumulation)
Vấn đề: Để Bot hiểu ngữ cảnh câu trước câu sau, hệ thống phải gửi kèm lịch sử các câu chat trước đó. Nếu không có cơ chế dọn dẹp, càng chat sâu, dung lượng lịch sử càng phình to.

2. Giải pháp Tối ưu hóa Prompt & Kiến trúc Dữ liệuĐể giải quyết bài toán này, chúng ta sẽ áp dụng bộ 3 nguyên tắc:Tính toán trước (Pre-compute)->  Tinh giản cấu trúc (Compacting)-> Kỹ thuật Prompt chuyên sâu.

Lớp 1: Tuyệt đối không gửi Dữ liệu thô - Hãy gửi Dữ liệu đã tổng hợp (Aggregated Data)
- Giải pháp: Trước khi đưa dữ liệu vào Prompt cho LLM, Backend (Python) phải dùng SQL thực hiện các lệnh toán học (SUM, COUNT, GROUP BY, ORDER BY) để cô đọng dữ liệu trước.
- So sánh cấu trúc dữ liệu truyền vào LLM:
  - Cách làm cũ (Tốn 1.500 tokens):
    "Gửi 50 dòng JSON chi tiết:[{""id"":1, ""cat"":""cafe"", ""amount"":50000, ""date"":""...""}, {""id"":2, ""cat"":""shopping"", ""amount"":500000, ...}]"
  - Cách tối ưu (Chỉ tốn 150 tokens):
    "Gửi chuỗi text đã nén gọn:Tổng chi: 5.4M. Top 3 danh mục: Shopping (2.1M), Cafe (1.2M), Ăn uống (900K)."
LLM chỉ cần nhận chuỗi text đã nén là đủ thông tin để viết ra một câu chuyện (Story) nhận xét cực hay, thay vì phải tốn token bắt nó tự cộng trừ.

Lớp 2: Kỹ thuật Prompt Nén và Rút gọn cấu trúc (Structural Minimization)
    - Bỏ Few-shot dài dòng, thay bằng Định dạng Nghiêm ngặt (Strict Schema): Sử dụng tính năng Structured Outputs (hoặc JSON Mode) của các API hiện đại. Thay vì viết văn bản hướng dẫn "Hãy trả về dạng JSON có trường status...", ta định nghĩa bằng một Schema ngắn gọn trong code. LLM sẽ tự động ép đầu ra theo chuẩn mà không cần tốn token mô tả trong prompt.
    - Rút gọn System Prompt theo từ khóa: Thay đổi cách viết từ văn xuôi sang dạng gạch đầu dòng ngắn gọn, cô đọng bằng các từ mang tính ra lệnh mạnh (Imperative keywords).

Lớp 3: Chiến lược Quản lý Lịch sử trò chuyện "Cửa sổ trượt" (Sliding Window & Summary)
- Hệ thống không gửi toàn bộ lịch sử cuộc trò chuyện từ đầu đến cuối. Chúng ta áp dụng cơ chế Sliding Window: Chỉ gửi tối đa 3-4 lượt chat gần nhất để giữ ngữ cảnh.
- Đối với các lượt chat cũ hơn, hệ thống sẽ chạy một tiến trình ngầm cực nhẹ để "tóm tắt" (Summarize) lại nội dung chính thành 1 dòng duy nhất (Ví dụ: "Bối cảnh: User đang muốn cắt giảm tiền đi cafe"), giúp tiết kiệm đến 80% token của các lượt chat dài.

3. Minh họa cấu trúc Prompt Trước và Sau khi Tối ưu (hãy tùy chỉnh theo đầu vào và ra theo hệ thống hiện tại)
Cấu trúc Prompt Cũ (Lãng phí tài nguyên):
System: Bạn là trợ lý tài chính MiMo của ứng dụng quản lý chi tiêu. Hãy nói giọng thân thiện, dùng emoji thích hợp. Luôn phân tích kỹ và đưa ra lời khuyên. Hãy trả về kết quả dưới dạng JSON có cấu trúc sau để hệ thống đọc được... [Viết thêm 500 chữ ví dụ JSON]
User: Cho mình xem báo cáo tháng này. Dữ liệu đây: [Ném 100 dòng JSON DB vào]

Cấu trúc Prompt Tối ưu (Năng suất cao, Siêu tiết kiệm):
System: Role: Friendly FinTech Advisor (MiMo). Output: JSON only (Follow API Schema). Tone: Concise & Witty.
Context: [Tháng: 06/2026]. [Nhóm: Sinh viên]. [Tổng chi: 3.2M (Vượt hạn mức 20%)]. [Top_Waste: Trà sữa (1.1M)].
User: Cho mình xem báo cáo tháng này.

4. Lưu ý dưới góc nhìn Sản phẩm & Vận hành (PO Takeaway)
📌 "Tối ưu này có làm giảm chất lượng câu trả lời của AI không?" $\rightarrow$ KHÔNG, THẬM CHÍ CÒN TĂNG ĐỘ CHÍNH XÁC.
Khi chúng ta bắt LLM xử lý một Prompt quá dài và nhiều số liệu thô, nó rất dễ bị hiện tượng "Hội chứng mất tập trung" (Lost in the Middle), dẫn đến việc tính toán sai số hoặc đưa ra lời khuyên lệch lạc. Khi dữ liệu đầu vào đã được Backend làm sạch và cô đọng, LLM sẽ tập trung 100% "trí tuệ" của nó vào việc sáng tạo câu từ, giúp Story sinh ra vừa chuẩn xác về số liệu tài chính, vừa mượt mà về văn phong.
Về mặt chi phí, việc áp dụng kiến trúc Prompt phân tầng và tính toán trước này sẽ giúp dự án của chúng ta giảm giá vốn hàng bán (COGS) trên mỗi user xuống mức tối thiểu, đảm bảo hệ thống có thể scale lên diện rộng một cách an toàn
