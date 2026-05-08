# 2026-05-08 - Setup/runtime and frontend stability updates

## Context
- Goal: make the project reliably boot from `setup.sh` and reduce runtime/UI failures in local usage.
- Scope includes setup automation, frontend resilience, and repository push hygiene.

## Changes
- Added `setup.sh` flags:
  - `--up`: bootstrap and start stack.
  - `--down`: stop stack.
  - `--clean`: full local reset.
- Improved `setup.sh` behavior:
  - Reuse existing `.venv` to avoid interactive replacement prompts.
  - Skip dependency reinstall when `requirements.txt` and `shared/setup.py` are unchanged (hash-based).
  - Auto-select free ports and generate compose override files.
- Frontend reliability fixes:
  - Made Agent Configurations toolbar buttons visible with text labels.
  - Prevented Gradio crash when transcript/audio files are missing by returning safe file updates.
  - Added defensive handling for transcript/history fetch errors and file existence checks.
- Documentation updates:
  - Updated operation guide to cover Windows/Linux startup and logs.
  - Clarified `.env` vs `variables.env` usage in current setup flow.
- Repo hygiene:
  - Added/updated `.gitignore` rules for local runtime artifacts and non-push content.
  - Added `.env.example` for secret-free environment bootstrapping.

## Validation evidence
- Frontend syntax check completed:
  - `python -m py_compile frontend/__main__.py`
- Setup flow command used in local validation cycle:
  - `setup.sh --clean`
  - `setup.sh --up`

## Expected impact
- Faster repeated local starts.
- Fewer frontend runtime crashes due to missing artifacts.
- Cleaner push process with reduced risk of leaking local files or secrets.