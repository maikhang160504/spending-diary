# Rule: database-postgresql

## Mục tiêu

Su dung PostgreSQL lam database chinh cho he thong.

## Core table

Bang core la transactions.

## BẮT BUỘC fields

- amount
- category_id
- image_url
- thumbnail_url
- type VARCHAR(10) CHECK (type IN ('text','story','bill'))
- ai_extracted BOOLEAN DEFAULT false

## Rule du lieu anh

- Không luu binary image trong database
- Chi luu URL cloud

## Rule toan ven

- Moi transaction phai co type ro rang
- ai_extracted phai phu hop flow:
  - text: true
  - story: false
  - bill: true
