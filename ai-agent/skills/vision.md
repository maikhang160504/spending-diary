# Skill: vision

## Scope

Chi dung cho BILL_SCAN_FLOW.

## Input

- bill_image_url

## Output

- extracted_amount
- optional_store_name
- optional_bill_items
- confidence

## Capability

- OCR tong tien tren hoa don
- Trich xuat keyword de gợi ý category
- Danh gia do tin cay ket qua

## Hard limits

- Không duoc goi o STORY_FLOW
- Không doc amount tu story image

## Implementation note

- Neu confidence thap, tra ve de user nhap tay thay vi ket luan amount
