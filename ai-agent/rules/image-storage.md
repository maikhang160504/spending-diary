# Rule: image-storage

## Mục tiêu

Tat ca anh story/bill phai luu tren cloud storage, Không luu tren backend server.

## Storage providers

- Cloudinary
- AWS S3

## BẮT BUỘC

- Backend chi luu URL:
  - image_url (anh goc)
  - thumbnail_url (anh nho cho list)
- Không luu file binary image trong database
- Không luu file image local tren backend

## Phan biet nghiep vu

- Story image: chi luu va hien thi
- Bill image: duoc dung cho AI vision OCR

## Security note

- Neu anh nhay cam:
  - S3 private bucket
  - signed URL theo thoi han
