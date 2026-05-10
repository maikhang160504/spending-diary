# Rule: image-processing (MANDATORY)

## Mục tiêu

Phan biet ro 2 loai anh trong he thong de tranh sai logic Xử lý.

## Loai 1: Story image

- Dinh nghia: Anh user chup kieu story de luu ky niem giao dịch
- Allowed:
  - Luu image_url tren cloud storage (Cloudinary/S3)
  - Luu thumbnail_url cho list
  - Gan anh vao transaction
  - Validate dinh dang/tai trong
- Forbidden:
  - OCR so tien
  - OCR tong tien
  - Tu doan danh muc tu anh

Ket luan:
- Story image Không duoc dung de nhan dang tien.
- Story image chi dung de luu va hien thi.

## Loai 2: Bill scan image

- Dinh nghia: Anh hoa don dung de trich xuat thong tin chi tieu
- Required:
  - OCR tong tien
  - Tinh confidence score
  - Goi y danh muc
  - Yeu cau user confirm

Ket luan:
- Bill scan BẮT BUỘC qua OCR + confirm.

## Xử lý confidence

- confidence >= 0.85: cho phep auto-fill de user xac nhan
- 0.60 <= confidence < 0.85: canh bao do tin cay trung binh, uu tien user sua tay
- confidence < 0.60: Không de xuat amount cuoi cung, yeu cau user nhap tay

## Dieu cam toan he thong

- Không su dung ket qua OCR tu story image
- Không save bill transaction khi chua user confirm
- Không luu file binary trong backend server/database
- Không load full image cho danh sach, phai dung thumbnail_url
