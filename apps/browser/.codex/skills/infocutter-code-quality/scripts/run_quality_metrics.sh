#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

python3 .codex/skills/infocutter-code-quality/scripts/audit_infocutter_quality.py .

DCL_EXIT_LEVEL="${DCL_EXIT_LEVEL:-alarm}"
DCL_REPORTER="${DCL_REPORTER:-console}"

if command -v fvm >/dev/null 2>&1; then
  fvm dart run dart_code_linter:metrics analyze lib \
    --reporter="$DCL_REPORTER" \
    --set-exit-on-violation-level="$DCL_EXIT_LEVEL"
elif command -v dart >/dev/null 2>&1; then
  dart run dart_code_linter:metrics analyze lib \
    --reporter="$DCL_REPORTER" \
    --set-exit-on-violation-level="$DCL_EXIT_LEVEL"
else
  echo "WARN: dart/fvm not found; skipped dart_code_linter metrics" >&2
fi
