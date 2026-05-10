# Command: chat

## Mục tiêu

Xử lý hỏi đáp chung về chi tiêu, giải đáp nhanh, va điều hướng sang command đúng.

## Input

- message_text
- optional_context (thời gian, giao dịch gần đây)

## Xử lý

1. Detect intent:
- ghi giao dịch moi
- xem lại tổng quan
- xin gợi ý tiết kiệm
- hỏi đáp khác
2. Route command:
- ghi giao dịch -> input-expense
- gợi ý tiết kiệm -> suggest-saving
- tổng kết -> review
3. Tạo reply đúng tone money-friend

## Output

- response_text
- next_action (neu can)
- routed_command (neu co)

## Rule

- Không tu tao giao dịch neu user chua cung cap thong tin toi thieu.
- Nếu message mơ hồ, hỏi rõ thêm thay vì đoán.
