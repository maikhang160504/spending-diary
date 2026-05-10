# Rule: flutter-cache (MANDATORY)

## Mục tiêu

Toi uu load anh tren mobile Flutter va giam re-download.

## BẮT BUỘC

- Khi hien thi anh tu image_url hoac thumbnail_url, phai dung cached_network_image.

## Behavior

- Lan dau: load tu cloud
- Cac lan sau: load tu cache local cua package

## Dieu cam

- Không tu xay local image storage rieng
- Không reload anh Không can thiet
- Trong danh sach, Không duoc load anh full; phai dung thumbnail_url
