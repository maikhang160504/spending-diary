# Backend (Node.js + Express)

## Structure

- src/routes
- src/controllers
- src/models
- src/middleware
- src/services

## Implemented APIs

User:

- POST /api/user/expense
- GET /api/user/expenses
- POST /api/user/chat

Admin:

- GET /api/admin/users
- GET /api/admin/analytics
- GET /api/admin/ai-logs

## Input-Expense Flow Rules

Text:

- backend goi AI NLP (service: aiService.extractExpenseFromText)
- extract amount + category
- luu transaction

Story image:

- backend KHONG goi AI
- dung amount + category user nhap
- luu transaction voi image_url + thumbnail_url

Scan bill:

- backend goi AI vision (service: aiService.extractExpenseFromBill)
- tra suggestion va requiresConfirmation=true
- chi luu transaction sau khi confirm=true

## AI architecture in backend

1. Input Processing
2. Insight Engine (rule + light ML)
3. Comment AI (LLM fallback)
4. Emotion override -> tra emotion cho Flutter avatar

## User learning

- Neu text flow khong xac dinh duoc category: tra requiresCategorySelection
- Khi user chon category, backend luu user_category_mapping
- Lan sau uu tien mapping user truoc keyword rule

## Security + Storage Rules

- backend khong luu file image local
- backend chi nhan URL image da upload cloud
- GET /api/user/expenses bat buoc userId hop le truoc khi tra du lieu
- neu OCR confidence thap, backend yeu cau user nhap amount thay vi suy doan

## Run

1. npm install
2. npm run dev

Server mac dinh: http://localhost:4000
