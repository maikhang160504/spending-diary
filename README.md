# Fullstack Expense Management + AI Agent

## Project Goal

Base project fullstack cho ung dung quan ly chi tieu co AI, tach ro hai layer:

- app: code that (frontend, backend, database)
- ai-agent: rules + commands + skills cho hanh vi AI

Project nay da scaffold de co the chay ngay va phat trien tiep.

## Folder Tree

root/
- app/
	- frontend/
		- mobile/ (Flutter)
		- web-admin/ (React + Vite)
	- backend/ (Node.js + Express)
	- database/ (PostgreSQL schema)
- ai-agent/
	- commands/
	- rules/
	- skills/
	- agents/
	- settings/
- README.md

## How App Connects to AI

App khong chay rules markdown truc tiep.
App goi AI qua API, AI tra ket qua parse/goi y, backend app moi la noi validate va luu DB.

Flow thuc te:

1. User thao tac tren mobile/web-admin
2. Frontend goi backend API
3. Backend quyet dinh co goi AI hay khong
4. Neu can, backend goi AI service (NLP/Vision)
5. Backend xu ly ket qua, yeu cau confirm neu bill scan, sau do luu DB

## AI 4-layer architecture

1. Input Processing
2. Insight Engine
3. Comment AI
4. Emotion + Avatar

Flow:
User -> Backend -> (NLP / Vision / Manual) -> Database -> Insight Engine -> Comment AI -> message + emotion -> Flutter render avatar

Prompt mau Comment AI (2 vibe) nam tai ai-agent/commands/comment-ai.md.

## Image Storage + Cache Rules

- Anh story/bill phai duoc upload len cloud storage (Cloudinary hoac AWS S3)
- Backend khong luu file image local
- Database khong luu binary image, chi luu URL:
	- image_url (detail)
	- thumbnail_url (list)
- Flutter phai dung cached_network_image de cache anh
- Trong list view chi load thumbnail_url

## Input-Expense Flows

### 1) Text

- Backend goi AI NLP de extract amount + category
- Neu parse hop le, backend luu transaction

### 2) Story image

- Backend KHONG goi AI
- Dung amount + category user nhap
- Luu transaction URL anh

### 3) Scan bill

- Backend goi AI Vision de OCR amount + goi y category
- Tra ve requiresConfirmation
- User confirm/chinh sua xong moi luu transaction
- Neu confidence thap: khong duoc doan, yeu cau user nhap amount

## Backend APIs

User APIs:

- POST /api/user/expense
- GET /api/user/expenses
- POST /api/user/chat

Admin APIs:

- GET /api/admin/users
- GET /api/admin/analytics
- GET /api/admin/ai-logs

## API Request/Response Examples

### POST /api/user/expense (text)

Request:

```json
{
	"userId": 1,
	"flow": "text",
	"text": "an sang 30k"
}
```

Response:

```json
{
	"flow": "text",
	"expense": {
		"id": 1,
		"amount": 30000,
		"categoryName": "Food",
		"type": "text",
		"aiExtracted": true,
		"status": "saved"
	},
	"ai": {
		"amount": 30000,
		"category": "Food",
		"confidence": 0.95
	}
}
```

### POST /api/user/expense (story)

Request:

```json
{
	"userId": 1,
	"flow": "story",
	"storyImageUrl": "https://example.com/story.jpg",
	"storyThumbnailUrl": "https://example.com/story-thumb.jpg",
	"amount": 55000,
	"categoryName": "Food"
}
```

Response:

```json
{
	"flow": "story",
	"expense": {
		"amount": 55000,
		"categoryName": "Food",
		"type": "story",
		"aiExtracted": false,
		"imageUrl": "https://example.com/story.jpg",
		"thumbnailUrl": "https://example.com/story-thumb.jpg",
		"status": "saved"
	},
	"ai": null
}
```

### POST /api/user/expense (bill suggest)

Request:

```json
{
	"userId": 1,
	"flow": "bill",
	"billImageUrl": "https://example.com/bill-152000.jpg",
	"billThumbnailUrl": "https://example.com/bill-152000-thumb.jpg",
	"confirm": false
}
```

Response:

```json
{
	"flow": "bill",
	"requiresConfirmation": true,
	"suggestion": {
		"amount": 152000,
		"category": "Food",
		"confidence": 0.9
	}
}
```

## Database Recommendation

Nen dung PostgreSQL cho case quan ly chi tieu + AI vi:

- Du lieu giao dich co cau truc ro, can ACID
- Ho tro query phan tich (analytics) tot
- De quan ly quan he users-expenses-categories-ai_logs
- Scale on-prem/cloud de dang

Schema SQL nam o app/database/schema.sql.
Bang core la transactions voi cac field type, ai_extracted, image_url, thumbnail_url.

## Run Base Project

Backend:

1. cd app/backend
2. npm install
3. npm run dev

Web admin:

1. cd app/frontend/web-admin
2. npm install
3. npm run dev

Mobile:

1. cd app/frontend/mobile
2. flutter pub get
3. flutter run

## L? trình phát tri?n (14 Tu?n)
1. **Tu?n 1-2**: Thi?t k? UI/UX & Database (PostgreSQL & SQLite).
2. **Tu?n 3-6**: Xây d?ng Backend (FastAPI, Node.js), OCR, và NLP (Server-side).
3. **Tu?n 7-10**: Phát tri?n App Mobile (Flutter), Thu?t toán tài chính (Z-score, Linear Regression) & Tích h?p Mascot.
4. **Tu?n 11-14**: Ki?m th? h? th?ng, vi?t báo cáo tài li?u và làm Slide thuy?t trình d? án t?t nghi?p.
*(Th?i bi?u m?i ngày: Sáng/Chi?u code d? án – T?i 20h-22h h?c Ti?ng Anh).*
