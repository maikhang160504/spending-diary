# Command: suggest-saving

## Mục tiêu

Phân tích hành vi chi tiêu và đưa ra gợi ý tiết kiệm dễ thực hiện.

## Input

- transactions (khoang thời gian)
- optional_budget
- optional_goal (vd: tiet kiem du lich)

## Xử lý

1. Group chi tieu theo danh muc
2. Tim danh muc vuot nguong hoac tang bat thuong
3. Sinh 2-3 de xuat tiet kiem cu the, dễ thực hiện
4. Giu giong dieu than thien, Không phan xet

## Output

- saving_suggestions[]
- estimated_monthly_saving
- encouragement_message

## Rule

- Goi y phai dua tren du lieu that, Không tuong tuong.
- Không dua Mục tiêu phi thuc te.
