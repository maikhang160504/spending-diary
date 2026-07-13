# 1. REPORT_GENERAL 
## a. kiết quả kiểm thử 
ảnh : ![alt text](<images_screen/report (2).jpg>) ![alt text](images_screen/report.jpg) ![alt text](<images_screen/report (3).jpg>)
## b. gợi ý cải thiện
- Biểu đồ cột ở phần Report_general chưa hợp lý, thiết kế lại
- reponse của app khi phải hồi người dùng khi báo cáo có danh mục cụ thể không đúng ngữ nghĩa, khó hiểu
- reponse của app khi phản hồi với 2 mục thời gian cụ thể (từ ngày..đến ngày..) đang bị sai, và hình như cũng chưa có logic cho phần này
- kiểm tra lại reponse của từng loại report_general xem đã đúng ngữ nghia chưa, dễ hiểu,.... điều chỉnh cho phù hợp nhất
# 2. REPORT_COMPARE
## a. kiết quả kiểm thử 
link ảnh: ![alt text](<images_screen/compare (2).jpg>) ![alt text](images_screen/compare.jpg)
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "action_type": "REPORT_COMPARE",
  "slots": {
    "category": "Food",
    "time_range": "tháng trước"
  },
  "emotion": "Chill",
  "response": "Momo sẽ so sánh mức ăn uống của bạn với tháng trước đây, vừa tầm mà không làm ví bạn bị xẹp nhé 😊",
  "suggested_actions": null
}
4. [ ] So sánh tổng thu nhập vs tổng chi tiêu trong 1 khoảng thời gian.
- link ảnh: 
## b. gợi ý cải thiện
1. sửa time_range thành {time1, time2, ...}, có giá trị null, nếu 2 giá thị và tùy action nào thì sẽ là from-to, hoặc compare,...
2. hiện không thực hiện được hành động so sánh
3. xem xét reponse của compare có hợp lí không, đúng ngữ nghĩa, và có trả lời đúng câu của người dùng không

# 3. SET_LIMIT
- link ảnh: ![alt text](images_screen/setlimit.jpg)
## b. gợi ý cải thiện
- vẫn còn trường hợp đè tin nhắn ở phần set_limit, AI đã phản hồi bằng 1 tin nhắn, sau khi mà người dùng xác nhận, thì 1 tin nhắn mới sẽ đè lên phần tin nhắn cũ, làm thay đổi nội dụng của tin nhắn cũ, chứ không phải xuất hiện bên dưới
# 4. SET_GOAL, ADD_GOAL
## a. kiết quả kiểm thử
- ảnh: ![alt text](images_screen/setgoal.jpg) ![alt text](images_screen/addgoal.jpg)

## b. gợi ý cải thiện
- vẫn còn trường hợp đè tin nhắn ở phần set_goal, AI đã phản hồi bằng 1 tin nhắn, sau khi mà người dùng xác nhận, thì 1 tin nhắn mới sẽ đè lên phần tin nhắn cũ, làm thay đổi nội dụng của tin nhắn cũ, chứ không phải xuất hiện bên dưới. 
- lỗi ui hiển thị, khi ra vào lại chat thì hiển thị nhiều tin nhắn xác nhận (ảnh: )
# 5. SET_TONE
- do có hai verbal style là preminum nên phải kiểm tra trước khi đổi.
- dùng phản hồi từ LLM để hiển thị
# 6. SEARCH_RECORD
- đã tìm thấy nhưng không hiển thị
(ảnh:![alt text](<images_screen/search (2).jpg>) ![alt text](images_screen/search.jpg) ![alt text](<images_screen/search (3).jpg>) )
- nhận dạng nhầm thành compare 
Câu thoại của người dùng: liệt kê các khoản chi trên 30k trong tháng 7<|im_end|>
<|im_start|>assistant

---------------------------
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "action_type": "REPORT_COMPARE",
  "slots": {
    "query": "liệt kê các khoản chi trên 30k trong tháng 7"
  },
  "emotion": "Chill",
  "response": "Để Mimo xem lại nhé, bạn muốn coi những khoản chi nào trên 30k trong tháng 7 đúng không? 📊",
  "suggested_actions": null
}
# 7. SUGGEST_BUDGET
- logic và cách hiển thị đang bị sai (ảnh:![alt text](images_screen/suggest.jpg) )
# 9. SYSTEM_SETTING
- dùng phản hồi từ LLM để hiển thị
# 10. SET_USERNAME
- dùng phản hồi từ LLM để hiển thị
# 11. SET_ALERT
- dùng phản hồi từ LLM để hiển thị

# 12. ChitChat
- ảnh ![alt text](images_screen/chitchat.png) ![alt text](images_screen/chitchat2.png)
- có nhiều trường hợp có tiếng trung
- khung gợi ý hành động đang không có ở chat
--- DEBUG QWEN GENERATED ---
{
  "intent": "Chitchat",
  "action_type": null,
  "slots": {},
  "emotion": "Hello",
  "response": "Chào Mai Khang nè, sáng sớm mà trời hơi oi bức đó, bạn đã ngủ đủ chưa?",  
  "suggested_actions": ["Thêm giao dịch", "Xem báo cáo", "Quét hóa đơn"]
}