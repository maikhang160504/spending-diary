# Master Implementation Plan: NLU & OCR Enhancements, Web-Admin, Mobile, and Backend Fixes

This plan outlines the design, architecture, and step-by-step tasks to implement the remaining requirements outlined in `fix.md` across all four layers of the application. **No execution will take place until this plan is approved.**

---

## 1. Web-Admin Panel (`webadmin`)

### Objectives:
- Redesign and streamline the administrative interface.
- Optimize the model switching settings and the Bot Prompts management page.
- Remove deprecated features (e.g., legacy training triggers and Kaggle gold tests).

### Proposed Changes:

#### [MODIFY] [BotPromptsPage.jsx](file:///d:/Luan-Van/Project/app/frontend/web-admin/src/pages/BotPromptsPage.jsx)
- Redesign the layout with modern glassmorphism aesthetic and smooth micro-animations.
- Add system NLU settings: a dropdown component to toggle the active NLU backend (`tfidf`, `encoder`, `llm`).
- Connect saving setting to backend endpoint `PUT /api/admin/settings/nlu-backend`.
- Remove legacy options like triggering raw Kaggle OCR trainings and obsolete debug reports.

#### Clean-up & Streamlining:
- De-clutter administrative dashboards from legacy testing scripts and pages.
- Ensure training configurations for Modal are clean and easily readable.

---

## 2. NLU & OCR Serverless Services (`expense-ocr-nlu`)

### Objectives:
- Implement rapid LLM fine-tuning flow on Modal using Nvidia H100.
- Set up a testing flow for PhoGPT-7B (base/quantized) on an Nvidia A10 GPU.
- Finalize and integrate OCR retraining and validation pipelines on Modal.
- Restore the standard local/Kaggle NLU retrain flows to verify backward compatibility.

### Proposed Changes:

#### [NEW] `modal_llm_train.py` (or integrated in [modal_app.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/modal_app.py))
- Implement a serverless training task to fine-tune PhoGPT (4B or 7B) using `unsloth` or standard Hugging Face SFTTrainer on H100.
- Load the newly optimized `phogpt_finetune.jsonl` from `/storage` volume.
- Output checkpoint weights directly back to the Modal storage volume.

#### [NEW] `modal_llm_serve.py`
- Set up a Modal container utilizing an Nvidia A10 GPU to load and run the un-fine-tuned (and later fine-tuned) PhoGPT-7B model using Ollama/vLLM/llama.cpp for inference latency benchmarking.

#### [MODIFY] [modal_app.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/modal_app.py)
- Consolidate layoutlmv3 and PICK KIE retraining pipelines.
- Verify that the Gemini financial advice/commentary generation function works flawlessly in the serverless Modal environment.
- Clean up any unused files, dead code, or redundant dependencies.

---

## 3. Mobile Client (`mobile`)

### Objectives:
- Fix Authentication lifecycle bugs.
- Verify Action display and execution flows.

### Proposed Tasks:
1. **Forgot Password Verification**:
   - Inspect and trace the authentication flow of the reset password process on mobile.
   - Fix API request and token handling if there are any mismatches.
2. **Google Sign-In Lifecycle Fix**:
   - Update Google Sign-in to enforce account selection: when logging out and logging back in, the user must be prompted with the "Choose an account" dialog rather than automatically logging back into the previous session.
3. **Action Display Validation**:
   - Verify UI representation of complex action payloads (`SET_LIMIT`, `SET_GOAL`, `REPORT_GENERAL`).
   - Ensure the Mimo mascot changes its sprite state based on the backend emotion metadata (`happy`, `sad`, `neutral`, `strict`, `alarmed`).

---

## 4. Backend Service (`back end`)

### Objectives:
- Align NLU execution logic with the thesis guidelines outlined in `thesis_nlu_discussion.md`.
- Implement local post-processing for personalization.
- Refine action intents handling.

### Proposed Changes:

#### [MODIFY] Central NLU Service (e.g., `nlu.service.js` or `ai.service.js`)
- **Backend Router Toggling**:
  - Dynamically route user input parsing depending on the `NLU_BACKEND` database setting:
    - `llm`: Call the PhoGPT container/Modal service.
    - `encoder`: Call the local PyTorch encoder server.
    - `tfidf`: Call the legacy TF-IDF service.
- **Local Personalization Post-Processing**:
  - Pass general classification outputs from the LLM through a local database check of the user's custom keywords/aliases before writing to the database (saving token usage).

#### [MODIFY] Intent Action Handlers (e.g., `intentAction.controller.js` or equivalent)
- **`REPORT_GENERAL` & `REPORT_COMPARE`**:
  - Map `time_range` inputs dynamically.
  - Implement double category parsing (`resolveMultipleCategoryCodes`) to enable direct comparative calculations.
- **`SET_GOAL` / `ADD_GOAL`**:
  - Implement Levenshtein Distance fuzzy comparison matching (>75% similarity) on target goal names.
  - If a matching goal is found, update the target amount rather than duplicating the record.
- **`SUGGEST_BUDGET`**:
  - Constrain budget modification suggestions strictly to categories that already have explicit limits defined in the `budgets` table.

---

## Verification Plan

### NLU & OCR
- Run a benchmark test of PhoGPT-7B inference speed and verify the JSON extraction parser.
- Execute a dry-run of the LayoutLMv3 training script to verify that paths resolve to the centralized root `data` folder.

### Mobile & Authentication
- Manually run forgot password flow.
- Manually verify Google Sign-In account prompt selection on logout/login.
- Run NLU parser and ensure mascot matches the emotion tags correctly.
# Implementation Plan: PaddleOCR/VietOCR + LayoutLMv3 Billing Pipeline

This plan outlines the design, architecture, and tasks to implement a complete LayoutLMv3 billing pipeline (inference, retraining, pre-labeling, and verified label exporting) alongside the existing PICK KIE pipeline, enabling full deployment and toggling between the two.

---

## 1. Pipeline Overview & Architecture

To achieve feature-parity with PICK KIE, we will introduce a new pipeline class `LayoutLMv3ReceiptPipeline` that wraps PaddleOCR, VietOCR, and the fine-tuned LayoutLMv3 Token Classification model.

```
[Raw Receipt Image]
        │
        ▼ (PaddleOCR Detector + VietOCR Recognizer)
[Text Words & Bounding Boxes]
        │
        ▼ (LayoutLMv3 Token Classifier)
[Labeled Tokens (SELLER, TOTAL_COST, etc.)]
        │
        ▼ (Heuristics / Post-Processing)
[Unified Transaction Schema (amount, merchant, category)]
```

---

## 2. Proposed Changes

### NLU & OCR Service (`expense-ocr-nlu`)

#### [NEW] `layoutlmv3_pipeline.py` (under `bill_ocr/receipt_ocr/`)
- Implement `LayoutLMv3ReceiptPipeline` extending `ReceiptOCRPipeline`.
- Dynamically run PaddleOCR text detector to localize bounding boxes.
- Run VietOCR to extract Vietnamese text from each box.
- Format extracted text and normalized coordinate boxes into LayoutLMv3 features.
- Load the fine-tuned LayoutLMv3 weights (`/storage/layoutlmv3/model_best.pth`).
- Run classification to extract KIE fields: `SELLER` (merchant name), `TIMESTAMP` (transaction date), `TOTAL_COST` (transaction amount).
- Implement `prelabel_for_admin` returning boxes, text lines, KIE fields, and suggested amount/category.

#### [MODIFY] [ocr_service.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/api/app/services/ocr_service.py) & [expense_ocr_nlu.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/api/app/adapters/expense_ocr_nlu.py)
- Support hot-switching between PICK and LayoutLMv3 backends using a configuration parameter or settings table (`OCR_BACKEND = "pick" | "layoutlmv3"`).
- Initialize `LayoutLMv3ReceiptPipeline` if `layoutlmv3` is active.

#### [MODIFY] [bill_retrain_service.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/api/app/services/bill_retrain_service.py) & [bill_retrain.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/api/app/routers/bill_retrain.py)
- Expose training execution endpoint for LayoutLMv3: `/bill-retrain/train-layoutlmv3` which triggers the Modal `train_layoutlmv3_model` function in the background.
- Support exporting verified annotations in both PICK format (polygons, boxes) and LayoutLMv3-compatible CSV formats.

---

### Backend Service (`back end`)

#### [MODIFY] Central AI settings controller
- Add `ocrBackend` setting to system settings (`pick` or `layoutlmv3`).
- Route receipt processing calls (`POST /api/ocr/image` and `POST /api/ocr/review`) depending on the selected active OCR backend.

---

### Web-Admin Panel (`webadmin`)

#### [MODIFY] Redesigned Administration Panel
- Add an OCR settings section to select between **PICK KIE** and **LayoutLMv3**.
- Display training metrics (F1-score, precision, recall) for LayoutLMv3.
- Allow triggering LayoutLMv3 retraining directly on Modal.
- Render the annotated image (SELLER, TOTAL_COST, etc.) returned by the selected backend and allow admins to re-assign labels or adjust bounding boxes.

---

## 3. Verification Plan

### Automated Tests
- Run `visualize_layoutlmv3_test_predictions` to verify that the LayoutLMv3 model correctly predicts the entities on test images.
- Verify API endpoint `/ocr/image` returns correct output under both `pick` and `layoutlmv3` mode.

### Manual Verification
- Deploy `expense-ocr-nlu` API on Modal.
- Toggle backends from WebAdmin and verify successful transaction extraction.
