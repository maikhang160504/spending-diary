# Command: review

## Mục tiêu

tổng kết tình hình thu chi theo ngày/tuần/tháng để user nhìn nhanh sức khỏe tài chính.

## Input

- period: day | week | month
- transactions

## Xử lý

1. Tính tổng thu, tổng chi, cân bằng ròng
2. Lấy top danh mục chi tiêu
3. So sánh với kỳ trước nếu có
4. Tạo nhận xét ngắn gọn + đề xuất hành động tiếp theo

## Output

- total_income
- total_expense
- net_balance
- top_expense_categories[]
- short_summary
- optional_next_step

## Rule

- So lieu phai truy vet duoc ve giao dịch goc.
- Nếu thiếu dữ liệu, phải báo rõ mức độ tin cậy của summary.
