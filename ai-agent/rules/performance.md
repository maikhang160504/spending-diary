# Rule: performance

## Mục tiêu

Dam bao upload/hien thi anh nhe va phu hop production scale.

## BẮT BUỘC

- Anh phai duoc nen truoc khi upload (<= 300KB)
- Co 2 version:
  - image_url: anh goc cho detail
  - thumbnail_url: anh nho cho list
- Không load anh full trong danh sach

## Backend validation

- Neu metadata image_size_kb > 300, backend tra validation error
