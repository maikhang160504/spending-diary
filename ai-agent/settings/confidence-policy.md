# Confidence Policy

## Mục tiêu

Thong nhat cach ung xu theo confidence cua NLP/Vision.

## NLP threshold

- >= 0.80: cho phep auto-fill va hoi xac nhan nhanh
- 0.60 - 0.79: auto-fill + canh bao co the sai
- < 0.60: Không ket luan amount/category, hoi lai user

## Vision threshold (bill scan)

- >= 0.85: de xuat amount/category de user xac nhan
- 0.60 - 0.84: de xuat voi canh bao, uu tien user sua tay
- < 0.60: Không de xuat amount cuoi, BẮT BUỘC user nhap tay

## Golden rules

- Confidence cao Không thay the buoc confirm bill scan
- Story flow Không dung confidence vision vi Không OCR
