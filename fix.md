# Fix lỗi và làm lại phần
1. COMPARE 
- chưa hiển thị được là so sánh gì với gì, chart hiển thị kém(xem logic BE, và cách AI trả dữ liệu sau đó chỉnh sửa ChatScreen)

2. REPORT_genaral
- phản hồi text bị khó hiểu : user ("thống kê mục ăn uống tháng này") MObile("So sánh chi tiêu: tháng này *Time bại chi cho đi lại *tiền nhiều hơn cho di chuyển *0đ) nha.") và biểu đồ thống kê cả tháng. 
- không báo cáo được 1 loại riêng lẻ (như chỉ ăn uống)

3. không SET_GOAL và ADD GOAL được
- hành động không được thực hiện dù đã nhận dạng đúng và hiển thị ở chat chính xác nhưng lại không thực hiện được
- 

4. SEARCH
Câu thoại của người dùng: Tìm các giao dịch trên 1 triệu<|im_end|>
<|im_start|>assistant

---------------------------
--- DEBUG QWEN GENERATED ---
{
  "intent": "Action",
  "record_type": null,
  "action_type": "SEARCH_RECORD",
  "slots": {
    "item": null,
    "category": null,
    "amount": null,
    "verb": null,
    "goal_name": null,
    "enabled": null,
    "theme": null,
    "verbal_style": null,
    "time_range": null,
    "query": "phiếm > 1000000"
  },
  "emotion": "Working",
  "response": ""
}
- vậy thì có tìm được các giao dịch không, và nếu thêm loại giao dịch thì có tìm được, tìm được nhiều thì hiển thị như nào, nếu có thời gian thì vẫn tìm được chứ
. intent_action
- thêm prompt để mô tả cho các cho các intent_action để tránh bị nhầm lẫn giữa các action_type (có sự nhầm lẫn giữa các), sau đó tối ưu token, muitle request


thắc mắc và muốn thay đổi:
- tại sao luôn phải load "[transformers] The following generation flags are not valid and may be ignored: ['temperature']. Set `TRANSFORMERS_VERBOSITY=info` for more details.
/usr/local/lib/python3.10/site-packages/bitsandbytes/backends/cuda/ops.py:468: FutureWarning: _check_is_size will be removed in a future PyTorch release along with guard_size_oblivious.     Use _check(i >= 0) instead.
  torch._check_is_size(blocksize)" làm thời gian start up lên tới 30-50s, có cách nào giảm thiểu không
- tại sao khi gửi yêu câu infer/action thì có request k gửi cho LLM (LLM k có chạy) có request lại gửi đến LLM là sao, vấn đề gì, yêu câu không gửi đề chạy model nào để ra kết quả (kết quả sai)
- nếu đang chạy infer, mà người dùng thoát ra khỏi chat thì dùng được chấp nhận nhưng vẫn không thực hiện logic