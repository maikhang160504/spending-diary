### fix
- [test] chat record thiếu tiền 
- [code] sai emotion đã liệt kê ở action stage 2
- [code] sửa quy tắc là khi nào csdl có 10k record và quét được 1k ảnh hóa đơn [ở dashboard]
- [test] 2 giao dịch trong 1 tin
- [test] train và retrain, đổi stage 1 -> stage 2, test, 
- [code] không hiển thị được dữ liệu ở test prompt webadmin dù đã trả kết quả (bên dưới)(test như người dùng gửi tin nhắn ấy)
[
    GET /health -> 200 OK  (duration: 92.1 ms, execution: 36.8 ms)
--- DEBUG QWEN PROMPT ---
<|im_start|>system
Bạn là trợ lý tài chính Gen Z, nhóm DUI_DE. Giọng vui vẻ, năng lượng cao, linh hoạt dùng các từ lóng khác nhau từ slang_pool để câu thoại đa dạng, không bị rập khuôn hay lặp lại cùng một câu phản hồi giữa các lượt chat.<|im_end|>     
<|im_start|>user
Ngữ cảnh hệ thống (CONTEXT_META): {"user_id": "test_admin", "budget_total": 5000000, "budget_remain": 2500000, "verbal_style": "dui_de"}
Câu thoại của người dùng: chi tiêu ăn sáng hết 45k<|im_end|>
<|im_start|>assistant
--------------------------
--- DEBUG QWEN GENERATED ---
Ờ zai, sáng nay ăn gì mà phong phú vậy? Chi tiêu 45k cũng ổn chứ, miễn là no bụng và có sức chiến đấu cho cả ngày nhé. Còn lại trong ngân quỹ là 2,495,500 thôi, nhớ tiết kiệm tí nữa nha.
---------------------------
{"ts": "2026-08-09T10:47:12.675Z", "level": "WARNING", "logger": "src.nlu.llm_intent_handler", "message": "Failed to parse LLM JSON response (even after repair/regex): Ờ zai, sáng nay ăn gì mà phong phú vậy? Chi tiêu 45k cũng ổn chứ, miễn là no bụng và có sức chiến đấu cho cả ngày nhé. Còn lại trong ngân quỹ là 2,495,500 thôi, nhớ tiết kiệm tí nữa nha."}
]

- [code] ở chuyển hướng khi nhấn thông báo, tìm và điều chỉnh cho đúng trang cần đến
- [x] lỗi chuyển đổi mô hình ở 2 stage
- [code] không hiển thị hết mà phải đợi kết quả RAG sau đó mới hiện
-  [code] sai emotion đã liệt kê ở action stage 2
- [code] mất lưu cache điện thoại 
#### chưa làm #####
- [ask] với cách quản trị mô hình hiện tại cho NLU và OCR, là có thể duyệt mô hình mới nhưng không có từ chối, vậy khi tôi không áp dụng và train thêm lần nữa thì mô hình mới sẽ đè lên mô hình đó đúng không
- [ask-code]
### [yêu cầu] Demo
- lập kịch bản demo: bao gồm luồng chạy, do có 2 app nên phải đặt là app A,B đăng nhập trước,kiểm chức năng chính, bước chạy, giải thích (công nghệ, logic, cách làm, đầu vào, đầu ra, kết quả, lí do) 
[gợi ý: đăng ký tài khoản, đăng nhập, điền onboaring, ghi chép chi tiêu bằng camere, quét bill, tạo ví mới tham gia ví chung, sau đó ghi chép chi tiêu bằng chat, ra lệnh cho hệ thống(xem báo cáo, tạo mục tiêu, thêm tiền cho mục tiêu vừa tạo, đổi giọng,). xem báo cáo, xem mục tiêu, thêm tiền mục tiêu, xem recap, gợi ý chi tiêu, điều chỉnh hạn mức, giao dịch tự động, đổi tone. thanh toán premium
- xem báo cáo, thực hiện gán nhãn bill, xem mẫu cá nhận vừa sửa. xem quản lí người dùng, ban và unban( gửi khiếu nại),train model(hiển thị tiến trình train), thay đổi mô hình chạy intent và category, model mới phải được admin duyệt mới thay thế model cũ(vậy tồn tại 3 model(cũ, hiện tại và mới) khi ap dụng thi hiện tại thành cũ, mới thành hiện tại và mới biến mất), xem prompt và test thử với prompt]
- vừa làm vừa giải thích 
- [văn] để rút ngắn thời gian thì em đã tạo trước tài khoản, và đăng nhập 2 thiết bị trên 2 app
- [yêu cầu] chỉ demo những chức năng chính 

### Kịch bản
1. giới thiệu sơ lược các giao diện chức năng chức năng của app và giao diện web
2. do thời gian có hạn nên em đã tạo tài khoản và đăng nhập trên 2 app (A và B)
3. chức năng cốt lõi mà mục tiêu đề ra  
4. ghi chép chi tiêu bằng văn bản
4.1. ghi chép bằng ghi chú ảnh


## đặt câu hỏi cho hệ tthống và cách mà hệ thống thực hiện
- làm sao để tính được lũy kế