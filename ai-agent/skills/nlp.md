# Skill: nlp

## Scope

Dung cho TEXT_FLOW la chinh.

## Input

- text

## Output

- parsed_amount
- parsed_category
- parsed_note
- confidence

## Capability

- Nhan dien so tien tu cau noi tu nhien
- Mapping keyword sang danh muc
- Xử lý cach viet so tien pho bien (k, ngan, trieu)

## Category priority

1. User mapping (user_category_mappings)
2. Rule keyword mapping
3. AI suggestion
4. Ask user

## Hard limits

- Neu Không tim thay amount ro rang, Không duoc tu doan
- Neu confidence thap, yeu cau user xac nhan/bo sung
