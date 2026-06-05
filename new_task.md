# Tasks

- [x] 1. Update `fix_disambiguation_labels.py` to relax regex constraints for cafe & go-out activities.
- [x] 2. Update `improve_datasets.py` to augment datasets with Cafe Food/Entertainment context and Action/Record edge cases.
- [x] 3. Update `train_category_model.py` and `train_intent_model.py` to use `ngram_range=(1, 3)`.
- [x] 4. Update NLU pipeline parsing (`pipeline.py`) to support rule-based boost for Entertainment category and standard action operators (`SET`, `ADD`, `SUB`).
- [x] 5. Update backend execution (`action.service.js`) to support math operations (`ADD`, `SUB`, `SET`) when setting budget limits.
- [x] 6. Regenerate datasets and train models.
- [x] 7. Add automated test script and verify fixes.
- [x] 8. Update `peer-comparison.md` documentation to specify the correct demographics (ages, jobs) and table schema (`age_group`, `job_type`).
- [x] 9. Add unit tests for peer comparison in `action.service.test.js`.
- [x] 10. Run tests and verify the changes.

## Smart Budgeting Recommendation

- [ ] 11. Create DB migration `011_budget_suggestions.sql`.
- [ ] 12. Create `suggestion.service.js` with core algorithm (denoising, weighted MA, income factor, saving rate, holiday factor, peer fallback).
- [ ] 13. Add API routes to `budgets.routes.js` (GET suggestions, POST apply, POST dismiss).
- [ ] 14. Integrate `SUGGEST_BUDGET` action type in `action.service.js`.
- [ ] 15. Create unit tests `suggestion.service.test.js`.
- [ ] 16. Update `action.service.test.js` with suggestion story tests.
- [ ] 17. Run all tests and verify.
