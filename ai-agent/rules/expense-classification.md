# Rule: expense-classification

## Mục tiêu

Phan loai danh muc chi tieu nhat quan giua text flow va bill flow.

## Nguon phan loai

1. User input category (uu tien cao nhat)
2. NLP parse category (text flow)
3. Vision + keyword mapping (bill flow)

## Uu tien override

- Neu user da chon danh muc: Không override
- Neu AI goi y danh muc: phai cho user doi

## Mapping co ban

- an sang, bua trua, cafe -> Ăn uống
- grab, xe om, xang -> Di chuyen
- sieu thi, tap hoa -> Mua sam
- tien dien, tien nuoc, internet -> Hoa don sinh hoat

## Rule chat luong

- Không gan category neu do tin cay qua thap
- Neu xung dot nhan dien, hoi user thay vi tu sua
