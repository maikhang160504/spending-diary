1. kiểm tra các action ở app, kiểm tra luồn của accept ảnh hóa đơn ở retrain, và ở các phần modal, các luồn retrain cần kiểm tra và sửa chưa
17. modal run --detach modal_app.py::run_nlu_benchmark  
12. tại sao encoder lại thấp trong benchmark như vậy dùng model là mới nhất và quá trình train cũng rất thành công
1. tôi dùng addstory mà banner lại hiển thị là bbill
2. mascot lại không lấy đúng câu phản hồi của LLM do gửi dư prompt xem và chỉnh lại addstory stage 2
3. story được lưu cũng không lấy đúng câu mà LLM reponse (lấy câu mặc đinh) 
5. ví cá nhân ban đầu luôn đứng đầu, và đang ở ví A thì chuyển sang mmàn hình khác thì quay lại vẫn là ví A chứ không phải là ví đâu tiên (ví dụ đang ở ví riêng Cá nhân cchuyển sang ví chung xong quay lại vẫn là ví Cá Nhân) 
6. nếu người dùng đổi category của bill thì lấy item đã nhận dạng + số tiền để tạo mẫu sai
7 . giữ chuổi đang bị sai, chuổi hiển thị là số 0, không chúc mừng khi hoàn thành lửa mơi
8. nạp vào ví 1tr -> BONUS(income), thêm rule để biết phân rõ income và enpense
9. phân biệt rõ ràng giữa yêu cầu action nhắc nợ và record dept vào prompt
10. test thiếu thông tin
#### Sửa luận #####
- thêm ảnh đợi quét hóa đơn 3.5, 
- chưa thấy chức năng nào nhắc nói tới RAG, viết lại lý thuyết RAG và cách ứng dụng nó vào hệ thống (NLU)
- sửa luôn ERD, sơ đồ usecase,chuyển sơ đồ flow -> sơ đồ activity ở chương 3
- thay đổi luồn ở NLU và cách đánh giá
- tóm tắt : lí do, chức năng, kết quả, đánh giá (2 đoạn)
- có 1,2 câu mô tả trước khi vào mục nhỏ (từ mục lớn vào mục nhỏ)
- thêm bảng tóm tắt usecase,
- giải thích kí hiệu f1, accuracy
- xem các biểu đồ
- viết phụ lục
- vẽ lại hình kiến trúc 4 tầng tổng quát cho cả hệ thống và sơ đồ chi tiết cho từng tầng(tầng 1,2,3) tầng 4 không cần thiết
#### viết kịch bản demo
- đăng ký tài khoản, đăng nhập, điền onboaring, ghi chép chi tiêu bằng camere, quét bill, tạo ví mới tham gia ví chung, sau đó ghi chép chi tiêu bằng chat, ra lệnh cho hệ thống(xem báo cáo, tạo mục tiêu, thêm tiền cho mục tiêu vừa tạo, đổi giọng,). xem báo cáo, xem mục tiêu, thêm tiền mục tiêu, xem recap, gợi ý chi tiêu, điều chỉnh hạn mức, giao dịch tự động, đổi tone. thanh toán premium
- xem báo cáo, thực hiện gán nhãn bill, xem mẫu cá nhận vừa sửa. xem quản lí người dùng, ban và unban( gửi khiếu nại),train model(hiển thị tiến trình train), thay đổi mô hình chạy intent và category, model mới phải được admin duyệt mới thay thế model cũ(vậy tồn tại 3 model(cũ, hiện tại và mới) khi ap dụng thi hiện tại thành cũ, mới thành hiện tại và mới biến mất), xem prompt và test thử với prompt

