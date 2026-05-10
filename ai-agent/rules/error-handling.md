# Rule: error-handling

## Mục tiêu

Xử lý loi ro rang, Không mat du lieu, Không tao giao dịch sai.

## Nhom loi va cach Xử lý

1. Validation error
- Ví dụ: thieu amount, amount <= 0, category Không hop le
- Xử lý: thong bao field loi + huong dan nhap lai

2. NLP parse uncertainty
- Ví dụ: "an sang" nhung Không co so tien
- Xử lý: hoi user bo sung amount

3. Vision OCR failure (bill)
- Ví dụ: anh mo, cat mat tong tien
- Xử lý: yeu cau chup lai hoac cho nhap tay

4. Storage failure
- Xử lý: bao user giao dịch chua luu, de nghi thu lai

## Rule bao toan du lieu

- Không save transaction neu mandatory fields thieu
- Log du context de debug
- Luon tra response co huong dan buoc tiep theo
