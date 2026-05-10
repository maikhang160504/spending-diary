# Database (PostgreSQL)

Khuyen dung PostgreSQL cho he thong nay.

## Tables

- users
- categories
- transactions (core)
- ai_logs
- user_category_mappings
- ai_comment_logs

## Files

- schema.sql: DDL tao bang, quan he, index

## Notes

- Khong luu binary image trong database
- Chi luu image_url va thumbnail_url
- transactions bat buoc co:
	- type: text | story | bill
	- ai_extracted: true/false
- Bill scan nen luu suggestion vao ai_logs truoc, chi luu transaction sau confirm
