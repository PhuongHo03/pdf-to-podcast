## 2026-05-08 - Fix false-success flow and preserve 404 for transcript/history

Issue:
- UI flow could return `job_id` even when background processing failed or timed out because `test_api` returned in a `finally` block.
- API endpoints `/saved_podcast/{job_id}/transcript` and `/saved_podcast/{job_id}/history` could transform intended 404 errors into 500 responses.

Fix:
- Updated `frontend/utils/email_demo.py` to:
  - wait for TTS completion with periodic checks,
  - fail fast when monitor stops before TTS completion,
  - return `job_id` only on successful completion path.
- Updated `services/APIService/main.py` to re-raise `HTTPException` in transcript/history handlers, preserving original status codes.

Validation:
- `uv run ruff check frontend/utils/email_demo.py services/APIService/main.py --output-format concise` -> All checks passed.
