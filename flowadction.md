# action, chitchat (action, chitchat -> stage 2 luôn dùng LLM)

## REPORT, COMPARE, SEARCH 
1. Người dùng gửi text -> BE gọi API.
2. AI Service Stage 1: Nhận dạng ý định (Qwen, TF-IDF, Encoder). (Lưu ý: Qwen đã có prompt `INTENT_CLASSIFICATION_PROMPT`).
3. AI Service Stage 2: Trích xuất thông tin (Luôn dùng LLM Qwen do là Action) -> Trả về slots, emotion, response.
4. BE gọi Service để lọc dữ liệu thực tế (Áp dụng bộ lọc `walletId` chính xác).
5. BE trả về App LUÔN (Bao gồm Response của LLM Stage 2 + Dữ liệu đã lọc theo ví) -> App hiển thị lập tức để không bị block (non-blocking).
6. Ở background, BE tiến hành chạy LLM RAG (sử dụng thông tin vừa lọc) để sinh câu nhận xét (JSON RAG).
7. Khi JSON RAG tạo xong, BE đẩy (push) qua WebSocket (`chat_llm_update` với cờ `isRag = true`) về App. App tự chèn thêm câu nhận xét này vào giao diện.

## actiontype khác
- stage 1: nhận dạng ý định (qwen mặc định, tfidf, encoder)
- stage 2: trích xuất thông tin bằng LLM (do là action) -> trả về slots và emotion, response
- BE -> App (hiển thị Response LLM stage2 và card xác nhận) người dùng tự xác nhận mới hành động (ngoại trừ SET_TONE, SET_USERNAME đã được tự động thực thi).

# record (có thể đổi stage 1 và stage 2)
- stage 1: nhận dạng ý định (qwen mặc định, tfidf, encoder)
- stage 2: trích xuất thông tin (qwen, tfidf, encoder). 
- Nếu là qwen -> BE -> App (hiển thị Response LLM stage2 và card xác nhận).
- Nếu là tfidf, encoder -> hiển thị câu xác nhận ngắn gọn và card xác nhận giao dịch.
