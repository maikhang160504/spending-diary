# Mobile App (Flutter)

## Screens

- Nhap thu chi (text -> goi backend NLP flow)
- Chup anh story (khong goi AI, luu amount/category user nhap)
- Scan hoa don (goi backend vision flow, can confirm)
- Chat AI

## API Service

- lib/services/backend_api_service.dart
- Base URL mac dinh: http://10.0.2.2:4000 (Android emulator)

## Image Rule

- Flutter upload anh len cloud (Cloudinary/S3), nhan image_url + thumbnail_url
- Khi hien thi anh, app dung cached_network_image
- List view uu tien thumbnail_url, detail view dung image_url

## Run

1. flutter pub get
2. flutter run
