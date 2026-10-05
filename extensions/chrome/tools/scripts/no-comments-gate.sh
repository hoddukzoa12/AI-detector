#!/usr/bin/env bash
set -euo pipefail

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { printf '  \033[31m✗\033[0m %s\n' "$1"; }

FAIL=0

while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    ext="${file##*.}"

    case "$ext" in
        rs|ts|tsx|js|jsx|mts|cts|mjs|cjs)
            pattern='^\s*//' ;;
        php)
            pattern='^\s*(//|/\*|\* )' ;;
        sh|bash|tf|hcl|py)
            pattern='^\s*#' ;;
        *)
            continue ;;
    esac

    hits=$(grep -nE "$pattern" "$file" \
        | grep -v '^\s*#!' \
        | grep -v '^\s*#\[' \
        || true)

    if [[ -n "$hits" ]]; then
        ng "주석 발견: $file"
        echo "$hits" | head -3 | sed 's/^/    /'
        FAIL=1
    fi
done < <(git ls-files)

if [[ "$FAIL" != "0" ]]; then
    exit 1
fi
ok "주석 없음"
