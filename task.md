# Detailed Task Checklist

## 1. Web-Admin Panel (`webadmin`)
- [ ] Redesign `BotPromptsPage.jsx` with glassmorphism design and micro-animations
- [ ] Add active model backend selection dropdown (TF-IDF vs Encoder vs LLM)
- [ ] Connect selection dropdown to `PUT /api/admin/settings/nlu-backend`
- [ ] Remove legacy debug buttons and obsolete OCR/Kaggle triggers

## 2. NLU & OCR Services (`expense-ocr-nlu`)
- [ ] Implement `modal_llm_train.py` / task function in `modal_app.py` for PhoGPT fine-tuning on H100 GPU
- [ ] Implement container setup for PhoGPT-7B (base/quantized) inference testing on A10 GPU
- [ ] Clean up redundant script references and verify pipeline integration
- [ ] Ensure Gemini commentary generation works inside Modal container

## 3. Mobile Client (`mobile`)
- [ ] Debug and fix reset password flow
- [ ] Update Google Sign-In sign-out/login flow to enforce account chooser
- [ ] Verify actions rendering and Mascot sprite changes based on emotion tags

## 4. Backend Service (`back end`)
- [ ] Implement dynamic NLU backend routing based on settings table
- [ ] Implement local personalization key mapping (caching/dictionary lookup)
- [ ] Upgrade `REPORT_COMPARE` to handle dual categories and time ranges
- [ ] Upgrade `SET_GOAL` using Levenshtein distance similarity matching (>75%)
- [ ] Restrict `SUGGEST_BUDGET` adjustments to existing budgets

# Detailed Tasks for PaddleOCR+VietOCR + LayoutLMv3 Billing Pipeline

## 1. OCR Pipeline (`expense-ocr-nlu`)
- [x] Implement LayoutLMv3 KIE Engine in `pick_kie.py` (replacing PICK)
- [x] Update `expense_ocr_nlu.py` adapter to dynamically load and serve LayoutLMv3 instead of PICK
- [x] Integrate KIE extraction using fine-tuned LayoutLMv3 weights
- [x] Add `/bill-retrain/modal/trigger` endpoint to trigger LayoutLMv3 training on Modal
- [x] Support PA1 (OCR-matched training with background O labels)
- [x] Support PA2 (Rule-based post-processing heuristics for robust entity detection)

## 2. Backend integration (`back end`)
- [x] Support seamless LayoutLMv3 routing across `/ocr/image` and `/ocr/review` requests

## 3. Web-Admin Panel (`webadmin`)
- [x] Add active OCR backend selection label and status display (LayoutLMv3)
- [x] Implement training trigger button to call LayoutLMv3 on Modal
- [x] Enable bounding box visualization and label adjustments on WebAdmin UI using LayoutLMv3 predictions
