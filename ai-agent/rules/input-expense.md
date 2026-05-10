# Rule: input-expense (CORE LOGIC)

## Flow 1: TEXT

- Input: text
- Xử lý: AI NLP extract amount + category
- Output: transaction
- type = 'text'
- ai_extracted = true

## Flow 2: STORY IMAGE

- Input: image + amount + category (user nhap)
- Xử lý: Không goi AI
- Output: transaction
- type = 'story'
- ai_extracted = false

## Flow 3: SCAN BILL

- Input: bill image
- Xử lý: AI vision extract amount + suggest category + user confirm
- Output: transaction
- type = 'bill'
- ai_extracted = true

## Dieu cam

- Story image Không duoc OCR tien
- Neu AI Không chac, BẮT BUỘC hoi user nhap lai
- Không tu suy doan amount khi confidence thap
