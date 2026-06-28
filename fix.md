### 1. dataset
1. cải thiện cả 3 dataset (action, chitchat, record) đã có sẵn (trùng, không có đầy đủ,...). ngoài ra xem yêu cầu 2.1 bên dưới và phân tích daatset hiện tại cần chỉnh sửa gì để đáp ứng nhu cầu rồi từ đó chỉnh sửa, bổ sung dataset (dữ liệu đã có sẵn và dữ liệu tự gen) hoặc xóa dữ liệu
2. dựa vào 3 dataset đã được chỉnh sửa ở trên hãy tạo ra 1 dataset mới có thể dùng để fine-tune 1 LLM nhận dạng record, action và phản hồi chitchat

### 2. AI-service (chú ý AI service được đưa lên docker nếu chứa model fine-tune LLM)
1. các logic của intent_action trong action.md có nhiều phần bị sai và không thể thực hiện:
- tìm kiếm record (tìm kiếm record nào, 1 or nhiều?)
- báo cáo / thông kê chỉ theo thời gian chứ không theo category(1 danh mục cụ thể)
- so sánh trong template chưa được thể hiện rõ, không có logic, không có trong dataset. ví dụ so sánh hai tháng, hai ngày, mình với nhóm người dùng khác
- đã xóa updata_record, delete_record (xem ở action.md)
2. thêm code để xử lí bằng mô hình LLM local bằng cách dùng prompt, nhưng hãy đảm bảo logic phải đúng với action.md sau khi đã sửa. 


3. xóa luồng train và retrain OCR trên kaggle:
- ảnh sau khi export sẽ được lưu lại sau đó sẽ chuyển vào tới thư mục dataset cũ ở trên để train lại 

4. phân tích lại tại sao ai-service lại tách riêng expense-ocr-nu dùng là 1, tại khi khởi động ai-service thì nó sẽ lấy code ở folder r expense-ocr-nu, hãy gộp lại mà không làm lỗi hoặc mất các logic cũ

5. nếu gộp OCR và MC_OCR làm 1 ( OCR nằm trong AI service) thì sao?
- chỉ cần bổ sung flow gán lại nhãn tự động và nhận dạng category cho bill (dùng LLM prompt riêng để gán nhãn và nhận dạng category, khác với prompt của action và record) bằng cách dùng bộ lọc cũ để đưa danh sách sản phẩm vào cho cho gán nhãn của hóa đơn vào MC_OCR
- đổi tên cho phù hợp, gộp thư mục và xóa các file không cần thiết (clean) mà không làm mất logic và không ảnh hưởng tới việc train và chạy demo trích xuất (còn cách chức năng khác ở OCR nằm trong AI service )


