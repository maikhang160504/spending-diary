1. kiểm tra các action ở app, kiểm tra luồn của accept ảnh hóa đơn ở retrain, và ở các phần modal, các luồn retrain cần kiểm tra và sửa chưa
12. tạo tool để sử dụng 1 tài khoản để thử autoban bằng request
15. miss thông tin từ input người dùng ở chat, ràng buộc cho các trường của action type, viết thành 1 file khác để LLM đọc và làm theo prompt hiện tại khác là khó
17. thanh tiến trình của quá trình train ở webadmin
20/ kiểm thử retrain đối với 3 mô hình
21. kiểm tra đầu ra của AI trước khi đưa ra cho người dùng
22. mô hình mới train được áp dụng thủ công hay tự động(điều kiện của tự độngh) có cần kiểm tra trước khi áp dụng không 
25. reponsive cho webadmin
13. lấy dữ liệu ở đâu ra chạy fine tune (lấy ngẫu nhiên dữ liệu trong csdl để tạo thành file train_llm_finetune_data_import.json), retrain nlu lấy từ csdl nhưng loại bỏ những mẫu sai để thay thế bằng những mẫu đúng ở tầng 2 (nếu chưa có)
14. Nạp tập dữ liệu huấn luyện bổ sung (Import CCSV) nên loại bỏ chức năng này. và bỏ Tự động huấn luyện lại ở tầng 2 
15. So sánh chỉ số chất lượng mô hình (F1/Accuracy) không lấy những lần lỗi
16. Lựa chọn Bộ suy luận NLU vận hành là chọn mô hình nhận dạng intent classifier (record, action,chitchat)
17. tìm và xóa luồng dùng gemini không cần nữa chỉ dùng LLM qwen2.5

#### Sửa luận #####
- thiếu hình 3.4 thành nhập liệu ở camera
- thêm ảnh đợi quét hóa đơn 3.5, 
- thiếu ảnh so sánh 
- nhắc đến phụ lục ở trong đoạn văn và không dùng footnote
- sửa bố cục luận văn chương số 4: test case mới đúng
- in đậm mục lục
- chưa thấy chức năng nào nhắc nói tới RAG
- sơ đồ tổng usecase tổng quát, chưa liên kết với nhau và chưa chi tiết, sửa luôn ERD
- sửa từ ngữ (Bổ trợ tri thức	RAG	Kiến trúc giúp AI trả lời dựa trên thông tin được truy xuất từ cơ sở dữ liệu.)
- giải thích cho kết quả đã đánh giá

#### viết kịch bản demo
