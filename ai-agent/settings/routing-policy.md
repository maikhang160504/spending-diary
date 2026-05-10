# Input Routing Policy

## Mục tiêu

Route dung pipeline theo loai input de tranh chong cheo logic.

## Input detector

1. Neu payload co truong text va Không co bill_image -> route TEXT_FLOW
2. Neu payload co story_image + user_amount + user_category -> route STORY_FLOW
3. Neu payload co bill_image -> route BILL_SCAN_FLOW

## Priority khi du lieu bi trung

1. bill_image co uu tien cao nhat
2. story_image co uu tien tiep theo
3. text la fallback

## Rule an toan

- STORY_FLOW: disable vision OCR module
- BILL_SCAN_FLOW: enable vision OCR module
- Neu Không xac dinh duoc flow: tra ve yeu cau user chon cach nhap

## Output BẮT BUỘC

Sau route phai sinh:
- selected_flow
- required_fields
- validation_checklist
