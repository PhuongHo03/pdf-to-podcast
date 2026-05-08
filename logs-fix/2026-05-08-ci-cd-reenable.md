# 2026-05-08 - Re-enable CI/CD for slim runtime repository

## Issue
After slimming the repository to runtime essentials, workflow files under `.github/workflows/` were removed. This disabled automated CI/CD checks on push/PR.

## Fix
- Added `.github/workflows/ci.yml`:
  - Runs on push/pull_request to `main`.
  - Installs Python dependencies.
  - Runs `ruff check` on `frontend`, `services`, `shared`.
  - Runs `compileall` syntax verification.
  - Validates `setup.sh` shell syntax on Linux.
  - Validates docker compose configuration.
- Added `.github/workflows/cd.yml`:
  - Triggers after successful CI on `main` or via manual dispatch.
  - Creates runtime tarball artifact.
  - Uploads artifact for delivery/release handling.

## Validation evidence
- Workflow files created and tracked in repository.
- Local Python syntax checks already pass for frontend module.

## Expected impact
- CI quality gates are active again.
- CD artifact generation is available for runtime distribution.
