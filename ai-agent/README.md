# AI-Agent Layer

Day la layer mo ta hanh vi AI, Không phai runtime backend.

## Gom cac nhom

- agents/: persona va cach noi chuyen
- commands/: flow command va input/output contract
- rules/: policy BẮT BUỘC
- skills/: nang luc NLP/Vision/Finance
- settings/: routing + schema + confidence policy

## Mandatory rule set

- rules/image-storage.md
- rules/image-processing.md
- rules/database-postgresql.md
- rules/input-expense.md
- rules/flutter-cache.md
- rules/performance.md
- rules/security.md
- rules/data-flow.md
- rules/ai-integration.md
- rules/user-learning.md
- rules/insight-engine.md
- rules/emotion-avatar.md
- rules/multi-ai-fallback.md
- rules/ai-data-minimization.md
- rules/logging.md

## Command prompt templates

- commands/comment-ai.md (prompt mau cho 2 vibe: bro, bestie)

## Ket noi voi app

- App goi AI service dua tren tai lieu trong layer nay
- AI tra ket qua parse/goi y
- Backend app la noi quyet dinh luu du lieu

## Bien gioi quan trong

- Không dung tai lieu nay de thay the API/backend implementation
- Không dua deterministic DB logic vao rules
