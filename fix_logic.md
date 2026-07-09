1. hay bị văng khỏi tài khoản khi vào app
2. các intent action reponse đề bị để trống Bỏ quy tắc "8. Nếu intent là 'Action', 'response' bắt buộc là chuỗi rỗng ""."
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "record_type": null,
  "action_type": "SET_LIMIT",
  "slots": {
    "item": null,
    "category": "Transport",
    "amount": 2000000,
    "verb": "SET",
    "goal_name": null,
    "enabled": true,
    "theme": null,
    "verbal_style": null,
    "time_range": null,
    "query": null
  },
  "emotion": "Approved",
  "response": ""
}
3. có các transactions bị lỗi vẫn hiển thị, mà xóa lại không được (thông báo "không thể xóa giao dịch"). 
4. thiếu đa dạng trong câu reponse của LLM, hầu như câu câu phản hồi đều giống nhau. thiéu contextdtata gửi đi kèm theo prompt, các phản hồi bị không nghĩa mất đầu đuôi  "response": "Chỉ 100k à, cũng được mà mascot.", phải linh động đa dạng, đúng chính tả tiếng việt, hay ho, theo phong cách mà người dùng chọn(ở app mobile)
5. ở intent_action: bị đè text từ câu reponse của LLM:
- câu hiển thị đầu tiên là câu mặc định, sau đó bị đè lên bởi câu reponse của LLM
- kiểm tra lại action report, compare : gửi đi 2 lần LLM 1 lần nhận dạng 1 lần nhận phản hồi đúng không, nếu đúng tối ưu và thiết kế lại cách hiển thị hai tin nhắn reponse cho action này
6. nếu người dùng gửi text trước khi AI phản hồi thì sao, xử lí vấn đề này
7. nếu AI đang đợi server trả dữ liệu. thì ng dùng thoát chat hoặc thoát app thì như nào
8. gợi ý thêm giới hạn limitspending cho Category mới được nhận dạng (không có trong litmitspending) tại chat không còn hoạt động mà chỉ có thông báo. chỉnh sửa và chỉ app dụng đối với record 
9. thêm prompt cho chit chat, nếu người dùng gửi các câu hỏi, các câu chitchat mà kông phải record or action thì phản hồi người dùng 1 cách chuẩn mục theo chế độ phản hồi mà ng dùng chọn (dui_de, dan_doi) và mục đích cuối cùng là hướng ng dùng về app (nhập record,....)
10. REPORT_genaral: chưa báo cáo được 1 loại riêng lẻ (như chỉ ăn uống), phần text trước khi bị đè thì đúng, nhưng sau khi bị đè thì sai, biểu đồ hiển thi tất cả các category chứ k phải 1 loại được chỉ định bởi người dùng
11. SET_TONE: logic thực thi thất bại
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "record_type": null,
  "action_type": "SET_VERBAL_STYLE",
  "slots": {
    "item": null,
    "category": null,
    "amount": null,
    "verb": "SET",
    "goal_name": null,
    "enabled": null,
    "theme": null,
    "verbal_style": "sassy",
    "time_range": null,
    "query": null
  },
  "emotion": "Sassy",
  "response": ""
}
- không thực hiện được hành động, sai action_type,
- đầu tiên phải khi đc trả về dữ liệu, phải kiểm tra tone hiện tại của app, nếu nếu trùng với yêu cầu của người dùng thì không đổi và đưa ra thông báo, nếu không thì đổi và đưa ra thông báo xác nhận
- thiếu card xác nhận

12. nếu action ADD_GOAL, thì không phải là story nên không cần thêm story
13. sửa lại logic của GOAL như sau:
- GOAL sẽ không liên kết với Ví, hoàn toàn không liên quan gì tới ví
- GOAL được phép mời bạn bè vào tiết kiệm cùng, bằng link hoặc nhập mã
- thêm hiệu ứng nếu như thêm tiền vào mục tiêu thành công
14. SEARCH_RECORD
-  không thực hiện được hành động dù LLM đã trả kết quả đúng 
- tìm giao dịch thì hiện thì như thế nào, thiết kế , 1 giao dịch thì sao, nhiều giao dịch thì sao
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "action_type": "SEARCH_RECORD",
  "slots": {
    "item": null,
    "category": "Food",
    "amount": null,
    "verb": null,
    "goal_name": null,
    "enabled": null,
    "theme": null,
    "verbal_style": null,
    "time_range": "30 days" 
  },
  "emotion": "Search",
  "response": ""
}
15. reponse LLM bị sai chính tả tiếng việt
16. không nhận dạng được SUGGEST_BUDGET, nhẫn lẫn giữa SUGGEST_BUDGET và REPORT_GENERAL, thiết kế logic gợi ý chi tiêu cho cách danh mục ở spendinglimit bằng thuật toán kinh tế đúng nhất (Dù dùng thuật toán nào, bạn cũng nên chia các danh mục chi tiêu thành 2 nhóm để áp dụng logic khác nhau:
Danh mục cố định (Fixed Costs): Tiền nhà, tiền điện nước, mạng internet... Với nhóm này, hạn mức tháng sau nên bằng chính xác chi tiêu thực tế của tháng trước.
Danh mục biến đổi (Variable Costs): Ăn uống, mua sắm, giải trí... Đây mới là nơi các thuật toán (như Weighted Moving Average) phát huy tác dụng để điều chỉnh hành vi người dùng.). 
- thiết kế cách hiển thị gợi ý chi tiêu cho các category ở spendinglimit của user, cách xác nhận áp dụng cho từng category hoặc tất cả, hoặc chỉnh sửa tuỳ chỉnh
- thêm luồng và hiển thị tại limitSpending để gợi ý chi tiêu tự động và hiển thị
17. không thể thực hiện hành động đặt chế độ tối 
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "record_type": null,
  "action_type": "SET_SYSTEM_SETTING",
  "slots": {
    "item": null,
    "category": null,
    "amount": null,
    "verb": "SET",
    "goal_name": null,
    "enabled": null,
    "theme": "dark",
    "verbal_style": null,
    "time_range": null,
    "query": null
  },
  "emotion": "Chill",
  "response": ""
}
16. kiểm tra xử lí bật tắt thông báo của app (ở mục cài đặt), và bật tắt cảnh báo với từng category (đến hạn mực hoặc vượt hạn mức)
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "action_type": "SET_ALERT",
  "slots": {
    "enabled": false,
    "theme": null,
    "verbal_style": null,
    "time_range": null,
    "query": null
  },
  "emotion": "Chill",
  "response": ""
}

17. câu gợi ý tại chat
- hãy lập danh sách các câu gợi ý có thể xử dụng và test thử với LLM coi kết quả đúng không rồi mới cho hiển thị ở CHAT screen (20 câu)

18. prompt phản hồi chitChat bị lỗi, dựa vào ngữ cảnh và tên người dùng
---------------------------
--- DEBUG QWEN GENERATED ---
{
  "intent": "Chitchat",
  "record_type": null,
  "action_type": null,
  "slots": {},
  "emotion": "Sad",
  "response": "Ui chao, mascot mascot thân thân lên đây an ủi mascot mascot nhé. Cuộc sống có lúc lên lúc xuống đó mascot mascot, cố gắng vui vẻ lên nha."
}

19. phản hồi đang không áp dụng điều kiện:
- là ba mẹ, người yêu, bạn bè,...
--- DEBUG QWEN GENERATED ---
{
  "intent": "Record",
  "record_type": "Expense",
  "action_type": null,
  "slots": {
    "item": "Máy massage",
    "category": "Shopping",
    "amount": 1000000,
    "verb": null,
    "goal_name": null,
    "enabled": null,
    "theme": null,
    "verbal_style": null,
    "time_range": null,
    "query": null
  },
  "emotion": "Approved",
  "response": "Et ô ét, mua máy massage cho Ba Mẹ rồi đấy, câu này câu quan trọng quá!"
}

20. Report mới dùng lại ở bước show số liệu chứ chưa có phân tích
- thêm prompt phân tích bằng logic , thuật toán và nhận xét bằng AI: Ví dụ: Nếu AI phân tích: "Với tốc độ tiêu xài hiện tại, bạn sẽ bị hụt quỹ Tiết kiệm mua IP17 khoảng 1.500.000đ vào cuối tháng." * UI Giải pháp: Ngay dưới câu thoại đó, xuất hiện một nút bấm phụ: [Thắt chặt hạn mức Ăn uống ngay] hoặc [Gợi ý cắt giảm chi tiêu]. Khi người dùng bấm vào, ứng dụng sẽ tự động kích hoạt luồng cài đặt hạn mức (như màn hình SET_LIMIT trước đó). 
- Gợi ý thiết kế "Phòng phân tích chuyên sâu" (Mimo's Deep Dive)
Nếu người dùng muốn xem phân tích dài hạn (theo tháng hoặc quý), bạn có thể thiết kế một nút bấm chuyển tab dạng [Xem phân tích từ chuyên gia Mimo]. Khi bấm vào, màn hình sẽ mở ra một giao diện dạng "Story tổng kết tháng" giống như Spotify Wrapped hay Grab Thống kê năm:

Trang 1: "Tháng này bạn thuộc nhóm 'Chi tiêu lý trí' hay 'Vung tay quá trán'?"

Trang 2: "Đây là khung giờ bạn hay tiêu tiền nhất: 21:00 - 23:00 (Hội săn sale đêm muộn)!"

Trang 3: "Món ăn yêu thích nhất của ví tiền bạn tháng này: Trà sữa (Tổng cộng 12 ly)."


21. luồng nếu người dùng nhầm lẫn giữa việc đăng ảnh bình thường và bill thì sẽ xử lí như nào, 
21. luồng bill hiện tại lưu ảnh lên cloudflare cùng lúc với nhận dạng, thì xảy ra tường hợp ảnh sai không nhận dạng đươc thì ảnh cũng đã được lưu làm không xóa đc, bill lỗi. hãy tối ưu lại luòng này
22. GIAO DỊCH ĐỊNH KÌ
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 85 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///D:/Luan-Van/Project/app/frontend/mobile/lib/screens/settings/recurring_rul
  es_screen.dart:274:35
- Thêm giờ : tới đúng giờ thì tự thêm 