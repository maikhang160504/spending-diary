# Rule: data-flow

## Upload flow

1. Flutter upload anh len cloud storage
2. Flutter nhan image_url va thumbnail_url
3. Flutter gui URL ve backend
4. Backend validate va luu PostgreSQL

## Display flow

1. Flutter doc image_url/thumbnail_url tu backend
2. Flutter hien thi bang cached_network_image
3. List dung thumbnail_url, detail dung image_url

## Không cho phep

- Backend luu file image
- Database chua binary image
