## 2026-05-08 - Fix CI Ruff failures

Issue:
- GitHub Actions CI had failing `python-quality` jobs on ubuntu/windows due to Ruff lint errors.

Fix:
- Removed unused imports in `frontend/__main__.py`.
- Removed unused imports in `frontend/utils/email_demo.py`.
- Removed unused import in `services/PDFService/main.py`.
- Removed unused variable assignment in config JSON validation path.

Validation:
- `uv run ruff check . --output-format concise` -> All checks passed.
