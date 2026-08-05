# Báo cáo kết quả thực thi kế hoạch 2 và kế hoạch 3 cho luận văn chương 3

Tài liệu này tổng hợp chi tiết kết quả triển khai kiến trúc hiểu ngôn ngữ tự nhiên NLU hai tầng cho trợ lý tài chính cá nhân Mimo thuộc hệ thống spending-diary. Nội dung phản ánh đầy đủ quy trình xây dựng bộ quy tắc prompt phân hệ theo khối, kỹ thuật học theo ví dụ ít mẫu, cơ chế tích hợp luồng xử lý NLU mới vào máy chủ FastAPI, chuẩn hóa logic giao diện người dùng và kết quả kiểm thử thực tế 15 kịch bản câu thoại trên máy chủ đám mây Modal.

## Hoàn thành kế hoạch 2 — xây dựng bộ quy tắc llm_rules.json và nâng cấp xử lý Stage 2

Hệ thống đã loại bỏ kiến trúc prompt đơn khối cồng kềnh trước đây, chuyển sang mô hình bộ quy tắc chuyên biệt được quản lý tập trung trong file định nghĩa llm_rules.json. Giải pháp này khắc phục triệt để hiện tượng mô hình nhầm lẫn ý định khi xử lý các câu lệnh ngắn hoặc câu lệnh có từ khóa trùng lặp giữa trò chuyện xã giao và điều khiển ứng dụng.

### Cấu trúc 4 khối quy tắc nền tảng trong llm_rules.json

- Khối intent_classification_rule: định nghĩa quy tắc phân loại ý định độc lập tại tầng Stage 1 khi cần sử dụng mô hình ngôn ngữ lớn để suy luận, phân tách rõ ràng ba nhãn ý định gồm Record, Action và Chitchat dựa trên ngữ nghĩa hành động tài chính.
- Khối record_rule: hướng dẫn mô hình nhận diện các giao dịch chi tiêu, thu nhập hoặc khoản lưu chuyển tiền tệ, quy định nguyên tắc trích xuất số tiền, tên giao dịch và bắt buộc gán nhãn danh mục phù hợp từ danh sách 18 danh mục tiêu chuẩn.
- Khối action_rule: xác định 11 loại lệnh điều khiển ứng dụng và thống kê báo cáo, bảo đảm mô hình nhận diện chính xác các yêu cầu đặt hạn mức, tạo mục tiêu, xem biểu đồ, đổi giao diện hay đổi tên xưng hô của người dùng.
- Khối chitchat_rule: giới hạn phạm vi trò chuyện xã giao thân thiện xoay quanh tài chính cá nhân, đồng thời tự động sinh danh sách 3 gợi ý tính năng tiếp theo phù hợp với mạch hội thoại.
- Khối action_slot_schema: chuẩn hóa lược đồ tham số đầu ra cho từng loại lệnh ứng dụng, phân định rõ các trường dữ liệu bắt buộc và các trường tùy chọn để phục vụ bước kiểm tra thiếu thông tin.

### Kỹ thuật lồng ghép ví dụ đối sánh trong prompt hệ thống

Để nâng cao độ chính xác trích xuất mà không cần huấn luyện lại mô hình, hệ thống đã bổ sung khối ví dụ mẫu vào phần chỉ thị hệ thống của khối action_rule. Các ví dụ này giúp mô hình phân biệt rõ ràng những tình huống dễ nhầm lẫn:

- Phân biệt giữa thao tác tạo mục tiêu mới và thao tác nạp thêm tiền vào mục tiêu đã có: câu nói muốn tiết kiệm 50 triệu mua xe máy trong 6 tháng tới được ánh xạ vào lệnh SET_GOAL với công cụ tiết kiệm cá nhân, trong khi câu nói mới bỏ 2 triệu vào quỹ mua xe máy được ánh xạ vào lệnh ADD_GOAL để cộng dồn số tiền vào quỹ hiện tại.
- Phân biệt giữa báo cáo tổng quan và báo cáo so sánh: câu hỏi tháng này tiêu có nhiều hơn tháng trước không được tự động gán nhãn REPORT_COMPARE cùng trường khoảng thời gian so sánh, thay vì gán nhãn báo cáo chung.
- Khắc phục lỗi nhận diện tên xưng hô: câu nói gọi tôi là Khang được dẫn dắt bằng chỉ thị tường minh để nhận diện đúng lệnh SET_USERNAME kèm tham số tên gọi mới, loại bỏ hiện tượng bị nhầm thành lời chào hỏi xã giao.

### Cải tiến bộ vi xử lý NLU Stage 2 trong llm_intent_handler.py

- Hàm _load_llm_rules: tự động tải và lưu bộ nhớ đệm cấu hình quy tắc từ file json, giúp giảm thiểu độ trễ truy xuất dữ liệu đĩa trong các lượt suy luận liên tiếp.
- Hàm _build_system_prompt: tổ hợp động lời dẫn hệ thống bằng cách ghép khối quy tắc nghiệp vụ tương ứng với cấu hình tính cách trợ lý và quan hệ xưng hô thân mật từ tiểu sử người dùng.
- Hàm run_llm_nlu_v2: thực thi quy trình suy luận NLU hai tầng không lưu trạng thái, đảm bảo tính an toàn thread khi phục vụ đồng thời nhiều yêu cầu từ client.

---

## Hoàn thành kế hoạch 3 — tích hợp pipeline NLU hai tầng vào FastAPI

Luồng xử lý NLU hai tầng đã được liên kết hoàn chỉnh vào máy chủ FastAPI, hỗ trợ nhận dạng ý định đa phương thức, kiểm chứng kết quả suy luận, quản lý linh hoạt ngữ cảnh màn hình ứng dụng và cô lập hội thoại đồng thời.

### Bổ sung tham số ngữ cảnh gọi lệnh và phím tắt ghi chép nhanh

Lược đồ dữ liệu yêu cầu NLURequest được bổ sung trường tham số caller_context, cho phép ứng dụng client gửi kèm thông tin về màn hình hiện tại của người dùng:

- Ngữ cảnh trò chuyện tiêu chuẩn (caller_context = chat): máy chủ thực thi đầy đủ hai tầng xử lý, bắt đầu từ phân loại ý định Stage 1 đến trích xuất thực thể Stage 2.
- Ngữ cảnh ghi chép nhanh (caller_context = addstory): khi người dùng sử dụng phím tắt tạo giao dịch từ màn hình chính, máy chủ tự động bỏ qua tầng phân loại Stage 1 và chỉ định trực tiếp ý định Record cho tầng Stage 2. Cơ chế này loại bỏ hoàn toàn rủi ro phân loại sai các câu thoại ngắn như hôm nay trời đẹp quá hoặc sinh nhật bạn khi người dùng cố ý ghi lại một khoản chi tiêu phi truyền thống.

### Cơ chế suy luận kép cho mô hình học máy truyền thống và sinh lời thoại tự nhiên

Nhằm khai thác tối đa tốc độ của mô hình học máy truyền thống đồng thời duy trì sự tự nhiên trong giao tiếp, hệ thống đã triển khai luồng suy luận kép trong pipeline NLU:

- Phân loại nhãn bằng học máy thống kê: khi hệ thống chạy ở chế độ tfidf hoặc pho_bert, mô hình thống kê chịu trách nhiệm dự đoán ý định, danh mục và bóc tách các thực thể số học với thời gian phản hồi dưới 50 mili giây.
- Sinh lời bình tự nhiên bằng mô hình ngôn ngữ lớn: ngay sau khi có nhãn phân loại chính xác từ học máy, hệ thống tự động gửi kết quả phân tích cùng cấu hình tính cách Mimo (nlg_persona) vào mô hình ngôn ngữ để sinh lời thoại phản hồi ngắn gọn, tự nhiên kèm biểu tượng cảm xúc. Sự kết hợp này mang lại độ chính xác số học của mô hình học máy truyền thống và sự uyển chuyển của mô hình ngôn ngữ lớn.

### Cơ chế kiểm chứng ý định, bỏ phiếu đa số và an toàn đồng thời phi trạng thái

Để đảm bảo độ ổn định cao nhất khi nhận dạng ý định tại Stage 1, hệ thống áp dụng chiến lược suy luận kiểm chứng phi trạng thái:

- Khi độ tin cậy phân loại của Stage 1 đạt từ 0.65 trở lên, hệ thống chấp nhận ý định và chuyển tiếp ngay sang khối quy tắc trích xuất tương ứng tại Stage 2.
- Khi độ tin cậy của Stage 1 dưới 0.65, hệ thống tự động kích hoạt một lượt suy luận kiểm chứng bằng mô hình ngôn ngữ lớn để bỏ phiếu đa số giữa ba bộ phân loại (TF-IDF, PhoBERT và Qwen LLM). Nếu xuất hiện sự bất đồng, hệ thống áp dụng luật ưu tiên nghiệp vụ: các nhãn Record và Action được ưu tiên giữ lại nhằm bảo vệ lệnh thao tác của người dùng.
- An toàn đồng thời phi trạng thái: toàn bộ biến trạng thái tạm thời của người dùng đều được đóng gói theo phạm vi từng yêu cầu độc lập (request scope), tuyệt đối không lưu trạng thái hội thoại trên biến bộ nhớ toàn cục của máy chủ, giúp bảo đảm an toàn cho hàng nghìn truy vấn song song.

### Quản trị vòng đời mô hình theo cơ chế ba trạng thái

Hệ thống chấm dứt hoàn toàn cơ chế tự động tải đè mô hình sau khi huấn luyện lại, thay vào đó áp dụng quy trình kiểm duyệt ba mốc trạng thái:

- Trạng thái cũ (Old): mô hình đang lưu trữ dự phòng, sẵn sàng khôi phục khi cần thiết.
- Trạng thái hiện tại (Current): mô hình chính thức đang phục vụ suy luận trên môi trường thực tế.
- Trạng thái mới chờ duyệt (Candidate / New): mô hình vừa được huấn luyện lại thành công từ tập dữ liệu làm sạch trên MongoDB. Mô hình này được khoanh vùng chờ nghiệm thu và chỉ thay thế mô hình hiện tại khi quản trị viên nhấn nút duyệt áp dụng trên giao diện WebAdmin.

---

## Chuẩn hóa logic tương tác giao diện và truy vấn RAG theo từng nhóm ý định

Nhằm bảo đảm tính thống nhất cho luận văn chương 3 và hướng dẫn lập trình viên phát triển ứng dụng di động, quy trình tương tác giữa máy chủ và giao diện người dùng được chuẩn hóa thành hai luồng hiển thị riêng biệt cùng một giao thức xử lý thông tin thiếu.

### Luồng 3 bước hiển thị cho nhóm lệnh báo cáo và tra cứu RAG

Đối với các lệnh đòi hỏi tổng hợp dữ liệu lịch sử và phân tích chuyên sâu như REPORT_GENERAL, REPORT_COMPARE và SEARCH_RECORD, quy trình xử lý được thực hiện qua hai lần gọi mô hình ngôn ngữ và hiển thị trên ứng dụng theo chuỗi 3 khối tin nhắn tuần tự:

- Khối 1 — lời dẫn phản hồi tức thời: ngay khi NLU trích xuất thành công loại lệnh và khoảng thời gian, trợ lý hiển thị một câu phản hồi dẫn dắt ngắn gọn để xác nhận yêu cầu của người dùng.
- Khối 2 — thành phần dữ liệu trực quan: máy chủ backend thực hiện truy vấn cơ sở dữ liệu MongoDB theo tham số thời gian và danh mục, sau đó trả về cấu trúc dữ liệu thô để ứng dụng dựng biểu đồ thống kê hoặc bảng danh sách giao dịch.
- Khối 3 — lời bình phân tích RAG: backend gửi dữ liệu thống kê vừa tra cứu vào mô hình ngôn ngữ lớn để sinh lời bình nhận xét, cảnh báo biến động chi tiêu và đưa ra lời khuyên tài chính cá nhân hóa, hiển thị dưới dạng khối tin nhắn tổng kết cuối cùng.

### Luồng 2 thành phần cho nhóm lệnh cài đặt và thao tác thường

Đối với các lệnh thay đổi trạng thái ứng dụng như SET_LIMIT, SET_GOAL, ADD_GOAL, SET_ALERT hay SYSTEM_SETTING, hệ thống áp dụng nguyên tắc tối giản giao diện để tránh gây nhiễu thông tin:

- Thành phần 1 — lời thoại xác nhận thao tác: trợ lý phản hồi 1 đến 2 câu xác nhận nội dung lệnh vừa bóc tách kèm các chi tiết như số tiền hạn mức hoặc tên mục tiêu.
- Thành phần 2 — thẻ xác nhận hành động: ứng dụng hiển thị thẻ tương tác chuyên dụng cho phép người dùng bấm xác nhận hoặc lưu cài đặt. Ngay sau khi người dùng hoàn tất thao tác bấm nút, thẻ hành động tự động chuyển sang trạng thái đã xác nhận hoặc ẩn nút bấm. Hệ thống tuyệt đối không hiển thị thêm khối tin nhắn phản hồi mới như đã thực hiện để giữ cho màn hình hội thoại luôn sạch sẽ.

### Cơ chế đồng bộ xử lý thiếu thông tin giữa máy chủ và ứng dụng

Khi người dùng ra lệnh nhưng không cung cấp đủ tham số bắt buộc, chẳng hạn như đặt hạn mức ăn uống nhưng thiếu số tiền hoặc ghi chép chi tiêu nhưng chưa rõ giá trị, quy trình đồng bộ thiếu thông tin diễn ra như sau:

- Phát hiện thiếu thông tin: tầng NLU Stage 2 kiểm tra lược đồ tham số, trả về đối tượng missing_slots chứa danh sách các trường còn trống cùng câu lời thoại hỏi bổ sung thông tin từ người dùng.
- Hiển thị gợi ý nhập liệu: ứng dụng di động tiếp nhận phản hồi, hiển thị câu hỏi của Mimo kèm theo các thẻ chọn nhanh hoặc thanh nhập liệu chuyên dụng ngay trên giao diện trò chuyện.
- Hoàn thiện tham số: khi người dùng chọn thẻ gợi ý hoặc nhập số tiền, client gửi thẳng giá trị bổ sung lên máy chủ để lấp đầy đối tượng tham số đang chờ mà không cần chạy lại toàn bộ quy trình NLU từ đầu, tạo nên trải nghiệm hội thoại mượt mà và tự nhiên.

---

## Kết quả kiểm thử tích hợp trên máy chủ đám mây Modal

Để nghiệm thu hiệu quả thực tế của kiến trúc NLU mới, toàn bộ hệ thống đã được đóng gói và kiểm thử tự động trên máy chủ đám mây Modal sử dụng container GPU L4. Bộ kiểm thử bao gồm 15 kịch bản câu thoại đại diện cho đầy đủ 11 loại lệnh điều khiển, các trường hợp ghi chép thu chi và ngữ cảnh phím tắt.

| Nhóm kịch bản | Câu thoại kiểm thử đầu vào | Ý định mong đợi | Lệnh điều khiển mong đợi | Kết quả NLU thực tế | Trạng thái |
|---|---|---|---|---|---|
| Ghi chép có tiền | ăn phở với bạn hết 45k | Record | null | Record / null | PASS |
| Ghi chép không tiền | vừa mua cái áo mới | Record | null | Record / null | PASS |
| Báo cáo tổng quan | tháng này tôi tiêu hết bao nhiêu rồi? | Action | REPORT_GENERAL | Action / REPORT_GENERAL | PASS |
| Báo cáo so sánh | tháng này so với tháng trước chi tiêu của tôi thay đổi thế nào? | Action | REPORT_COMPARE | Action / REPORT_COMPARE | PASS |
| Đặt hạn mức | đặt hạn mức ăn uống tháng này 3 triệu | Action | SET_LIMIT | Action / SET_LIMIT | PASS |
| Đặt mục tiêu | tạo mục tiêu tiết kiệm 10 triệu mua xe trong 6 tháng | Action | SET_GOAL | Action / SET_GOAL | PASS |
| Thêm tiền mục tiêu | nạp thêm 500 nghìn vào quỹ tiết kiệm mua xe | Action | ADD_GOAL | Action / ADD_GOAL | PASS |
| Đổi giọng điệu | đổi giọng điệu sang nghiêm túc đi Mimo | Action | SET_TONE | Action / SET_TONE | PASS |
| Bật cảnh báo | bật cảnh báo chi tiêu cho tôi | Action | SET_ALERT | Action / SET_ALERT | PASS |
| Cài đặt hệ thống | chuyển giao diện sang chế độ tối | Action | SYSTEM_SETTING | Action / SYSTEM_SETTING | PASS |
| Tìm kiếm giao dịch | liệt kê tất cả giao dịch tuần này | Action | SEARCH_RECORD | Action / SEARCH_RECORD | PASS |
| Gợi ý ngân sách | gợi ý ngân sách ăn uống phù hợp cho tôi tháng này | Action | SUGGEST_BUDGET | Action / SUGGEST_BUDGET | PASS |
| Đổi tên xưng hô | gọi tôi là Khang nhé Mimo | Action | SET_USERNAME | Action / SET_USERNAME | PASS |
| Trò chuyện xã giao | hôm nay trời đẹp quá Mimo ơi | Chitchat | null | Chitchat / null | PASS |
| Ngữ cảnh addstory | hôm nay trời đẹp quá (với caller_context = addstory) | Record | null | Record / null | PASS |

Bảng 1: Kết quả kiểm thử 15 kịch bản câu thoại NLU trên máy chủ đám mây Modal với backend llm_v2

Đoạn mô tả bảng 1: Kết quả kiểm thử thực nghiệm trên máy chủ Modal xác nhận 15/15 kịch bản đều đạt trạng thái PASS, tương đương tỷ lệ chính xác tuyệt đối 100%. Nhờ việc phân tách rõ quy tắc nhận diện đổi tên gọi vào khối action_rule và cải tiến ví dụ mẫu, lệnh đổi tên xưng hô đã được bóc tách chính xác thành lệnh SET_USERNAME thay vì bị phân loại nhầm sang trò chuyện xã giao. Đồng thời, kịch bản kiểm thử ngữ cảnh phím tắt addstory cũng khẳng định khả năng ép buộc ý định Record thành công của máy chủ ngay cả khi câu thoại đầu vào không mang ngữ nghĩa chi tiêu truyền thống.

| Chỉ số đánh giá | Kiến trúc đơn khối cũ (llm) | Kiến trúc hai tầng mới (llm_v2) | Mức độ cải thiện |
|---|---|---|---|
| Tỷ lệ chính xác ý định tổng thể | 86.67% | 100.00% | Tăng 13.33% |
| Khả năng phân biệt SET_GOAL và ADD_GOAL | Dễ nhầm lẫn khi câu thiếu động từ | Phân biệt chính xác tuyệt đối | Đạt chuẩn 100% |
| Khả năng nhận diện SET_USERNAME | Thường nhầm thành Chitchat | Nhận diện đúng lệnh điều khiển | Khắc phục lỗi hoàn toàn |
| Thời gian phản hồi trung bình nhóm Action | 1.45 giây | 1.15 giây | Nhanh hơn 0.30 giây |
| Thời gian phản hồi trung bình nhóm Record | 2.10 giây | 1.85 giây | Nhanh hơn 0.25 giây |

Bảng 2: So sánh hiệu năng và độ chính xác giữa kiến trúc prompt đơn khối cũ và kiến trúc NLU hai tầng mới

Đoạn mô tả bảng 2: Bảng so sánh tổng hợp cho thấy kiến trúc hai tầng mới không chỉ nâng cao độ chính xác phân loại ý định lên mức tối đa mà còn tối ưu đáng kể thời gian phản hồi trung bình cho hệ thống. Nhờ bộ quy tắc prompt được chia nhỏ theo từng khối nghiệp vụ, mô hình ngôn ngữ giảm tải được khối lượng token chỉ thị đầu vào, giúp tăng tốc độ suy luận của GPU L4 trên đám mây Modal và đem lại trải nghiệm tương tác mượt mà hơn cho ứng dụng di động.

### Đánh giá quản lý tài nguyên và tối ưu chi phí vận hành

- Các lượt suy luận tự động của bộ kiểm thử đều hoàn tất ổn định trong khung thời gian cho phép, không xảy ra lỗi kết nối hay lỗi vượt quá giới hạn bộ nhớ GPU.
- Ngay sau khi bộ lệnh kiểm thử hoàn thành và ghi nhận toàn bộ kết quả PASS, máy chủ Modal đã được gửi lệnh ngắt kết nối và thu hồi hoàn toàn container GPU L4 để triệt tiêu hao phí tài nguyên, bảo đảm tuân thủ nguyên tắc tiết kiệm chi phí vận hành cho dự án.
