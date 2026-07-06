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
4. thiếu đa dạng trong câu reponse của LLM chỉ có 1 câu tới 