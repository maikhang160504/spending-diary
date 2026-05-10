# Command: input-expense (CORE)

## Mục tiêu

Xử lý tác vụ nhập thu chi từ 3 nguồn input khác nhau mà không chồng chéo logic.

## Input contract

Payload có thể thuộc 1 trong 3 nhóm:

1. Text payload
- text
- user_id
- timestamp

2. Story payload
- story_image_url
- user_amount
- user_category
- user_id
- timestamp

3. Bill payload
- bill_image_url
- user_id
- timestamp

## Output contract chung

- transaction_id
- amount
- category
- type: text | story | bill
- ai_extracted: true/false
- note
- image_url (anh goc tren cloud)
- thumbnail_url (anh nho cho list)
- ai_confidence (neu co AI parse)
- requires_confirmation: true/false
- status: draft | confirmed | saved

## FLOW 1: TEXT

### Input
- text

### Xử lý
1. NLP parsing để extract amount, direction (thu/chi), category, note
2. Chuẩn hóa amount về số nguyên (VND)
3. Nếu category chưa rõ, gợi ý category và hỏi user
4. Tạo transaction draft hoặc saved tùy theo độ đầy đủ thông tin

### Guardrails
- Không suy đoán amount nếu text mơ hồ
- Nếu parser confidence thấp: hỏi lại user

### Output
- transaction (có thể ở trạng thái draft nếu thiếu dữ liệu)

### Ví dụ
Input: "ăn sáng 30k"
Output dự kiến:
- amount: 30000
- category: Ăn uống
- type: text
- ai_extracted: true
- status: saved

## FLOW 2: STORY IMAGE

### Input
- story_image_url
- user_amount
- user_category

### Xử lý
1. Validate image URL tồn tại
2. Validate user_amount > 0
3. Validate user_category nằm trong danh mục hợp lệ
4. Tạo transaction và attach image

### Guardrails (BẮT BUỘC)
- Không OCR story image
- Không dùng AI đoán amount từ story
- Không ghi đè amount/category user đã nhập

### Output
- transaction + attachment image

### Ví dụ
Input:
- story_image_url: ...
- user_amount: 45000
- user_category: Cà phê
Output:
- amount: 45000
- category: Cà phê
- type: story
- ai_extracted: false
- image_url: story_image_url
- thumbnail_url: story_thumbnail_url
- status: saved

## FLOW 3: SCAN BILL

### Input
- bill_image_url

### Xử lý
1. Vision OCR trích xuất tổng tiền và item text nếu có
2. Expense classifier gợi ý category
3. Trả về kết quả ở trạng thái cần xác nhận
4. User confirm hoặc chỉnh sửa
5. Chỉ sau confirm mới lưu transaction

### Guardrails (BẮT BUỘC)
- Nếu OCR confidence thấp: không tự động lưu
- Luôn yêu cầu user xác nhận
- Không được bỏ qua bước confirm

### Output
- transaction draft + suggested fields + requires_confirmation=true

### Ví dụ
Input:
- bill_image_url: ...
Output lan 1:
- amount: 152000 (suggested)
- category: Ăn uống (suggested)
- type: bill
- ai_extracted: true
- requires_confirmation: true
- status: draft
Output sau confirm user:
- status: saved

## Decision table

- Có bill_image_url -> FLOW 3
- Không bill_image, có story_image_url + user_amount + user_category -> FLOW 2
- Còn lại -> FLOW 1

## Error cases

- Missing amount ở text: hỏi user bổ sung
- Story payload thiếu user_amount: báo lỗi validation
- Bill OCR thất bại: yêu cầu chụp lại hóa đơn rõ hơn và cho user nhập tay nếu cần
