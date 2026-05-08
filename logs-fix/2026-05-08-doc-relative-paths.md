## 2026-05-08 - Normalize docs to relative paths

Issue:
- Setup instructions in `pdf-to-podcast-explanation.md` still included absolute path examples, which caused confusion when users already `cd` into repo root.

Fix:
- Updated startup commands to use relative-path workflow consistently.
- Replaced Windows absolute Git Bash invocation with `bash ./setup.sh ...` examples.
- Replaced Linux placeholder absolute path example with repo-relative guidance.

Validation:
- Reviewed updated document sections to ensure no absolute path usage remains in run instructions.
