# Database

Schema chuẩn của hệ thống MoneyStory / Expense AI. Tương thích **PostgreSQL 14+** và **CockroachDB**.

## Bảng chính

| Bảng | Mô tả |
|------|------|
| `users` | Tài khoản, role (user/admin), vibe Mascot, refresh-token-friendly |
| `refresh_tokens` | Refresh token hash (rotation) |
| `categories` | Danh mục hệ thống + tự định nghĩa, code khớp nhãn AI (`Food`, `Shopping`...) |
| `wallets` | Ví cá nhân / chung |
| `wallet_members` | Thành viên ví chung + role |
| `transactions` | Giao dịch, có `source = manual/text/story/bill`, ảnh url, AI metadata |
| `budgets` | Hạn mức theo category/period |
| `debts` | Công nợ trong ví chung |
| `ai_logs` | Log mỗi lần gọi NLU/OCR (request, response, backend, latency) |
| `user_category_mappings` | Map keyword → category học từ user (rule layer trước AI) |
| `user_corrections` | Câu sai → nhãn đúng (cho retrain `model_custom`) |
| `user_confirmed_actions` | Action đã confirm để không hỏi lại |
| `action_rejected_log` | Action bị reject → admin review |
| `user_settings` | Theme, tone Mascot, personality, locale |
| `stories` | Gom giao dịch theo "câu chuyện" / ngày (UI Home gallery) |
| `story_items` | Item raw (text/image/voice) của một story, kèm `ocr_status` |
| `ai_processing_logs` | Chi tiết OCR/NLU/Fusion per item — phục vụ labeling |
| `ai_comments` | Mascot bình luận story (mood + content) |
| `goals` | Mục tiêu tiết kiệm có deadline + emoji |
| `spending_limits` | Hạn mức nhanh theo category_code |
| `chat_sessions`, `chat_messages` | Lưu lịch sử chat (intent_action JSONB) |

## Chạy migration

```powershell
# 1) Postgres local (mặc định trong docker-compose.yml)
psql "postgresql://postgres:postgres@localhost:5432/expense_ai" -f schema.sql

# 2) CockroachDB cluster (.env: cluster_connect)
psql "$env:DATABASE_URL" -f schema.sql

# 3) Hoặc qua backend script (idempotent, runs each .sql file once)
cd ..\backend
node src/db/migrate.js
```

## Sơ đồ quan hệ (rút gọn)

```
users 1───n wallets ──n── wallet_members ─n── users
  │  │          │
  │  │          └── n transactions ── category_id ── categories
  │  │                  │
  │  │                  ├── story_item_id ── story_items ── n stories
  │  │                  └── ai_logs (flow=expense_*)
  │  │
  │  ├── 1 user_settings
  │  ├── n stories ── n story_items ── n ai_processing_logs
  │  ├── n ai_comments (gắn story)
  │  ├── n goals
  │  ├── n spending_limits
  │  ├── n budgets
  │  ├── n chat_sessions ── n chat_messages
  │  ├── n user_corrections
  │  └── n user_confirmed_actions
```

## Áp dụng extension CSDL.md

```powershell
# Migration mở rộng (idempotent)
cd app\backend
node src/db/migrate.js   # tự chạy schema.sql + tất cả file trong src/db/migrations/
# hoặc thủ công:
psql $env:DATABASE_URL -f src/db/migrations/002_extend_csdl.sql
```
