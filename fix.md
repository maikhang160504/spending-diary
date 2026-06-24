### 1. Web Admin
1. xóa CHỨC NĂNG "Ưu tiên ghi chú người dùng nhập" = "Luôn ghi đè dự đoán của AI bằng text rõ ràng do user tự gõ." ở bill. 
2. Phương án dự phòng chập ngày (Date Convergence) ĐANG KHÔNG HOẠT ĐỘNG
### 2. ai-service
1. khi nào admin gửi yêu cầu retrain mới cần theo dỗi {"ts": "2026-06-22T15:57:41.112Z", "level": "INFO", "logger": "http", "message": "request", "path": "/api/v1/bill-retrain/kaggle/jobs", "method": "GET", "status": 200, "latency_ms": 28, "request_id": "f81583564aee"}
2. triển khai D:\Luan-Van\Project\asynchronous_pipeline_feasibility.md và thực hiện test với hệ thống local

### 3.datasets
1. hãy xem lại file intent_action.csv: có các text giống nhau, loại action muốn làm là giống nhau nhưng action_type lại khác nhau (Report và REPORT_GENERAL, ...), cùng như là có nhiều nhãn không có được mô tả ở action.md , hãy thống nhất lại xem nên cần giữ lại nhãn nào và loại bỏ nhãn nào ở file intent_action.csv. sau đó chỉnh sửa lại action.md và file intent_action.csv cho thống nhất.
2. phân tích luôn cả các logic action trong mobile để biết cách hoạt động đúng nhất của từng loại action_type trong intent_action.csv
3. dựa vào action.md đã chỉnh sửa, hãy tạo 20k mẫu dữ liệu cho ner_dataset.jsonl và 20k mẫu dữ liệu cho intent_action.csv với thời gian đa dạng(ngày, tháng, năm, ngày thường, cuối tuần, dd-mm-yyyy,thứ,...) câu viết tắt, genz or văn phong bình thường


### 4. docs
1. bàn luận về vấn đề retrain cho iintent_action_type trong file intent_action.csv, NER, ... CÁCh triển khai logic, làm sau thu thập mẫu, ....

