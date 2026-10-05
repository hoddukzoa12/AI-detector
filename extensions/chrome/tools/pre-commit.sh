#!/usr/bin/env bash
set -euo pipefail

FAIL=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|mts|cts)$' || true)

echo "=== TypeScript 타입 검사 ==="
if [[ -f tsconfig.json ]]; then
    if npx tsc --noEmit 2>&1; then
        ok "타입 OK"
    else
        ng "타입 오류 발생"
    fi
else
    printf '  \033[33m⚠\033[0m tsconfig.json 없음 — skip\n'
fi

echo ""
echo "=== ESLint (staged) ==="
if [[ -z "$STAGED" ]]; then
    printf '  \033[33m⚠\033[0m staged TS/JS 없음 — skip\n'
elif command -v npx &>/dev/null && npx eslint --version &>/dev/null 2>&1; then
    if echo "$STAGED" | xargs npx eslint --max-warnings=0 2>&1; then
        ok "eslint OK"
    else
        ng "eslint 위반 발생"
    fi
else
    printf '  \033[33m⚠\033[0m eslint 없음 — skip\n'
fi

echo ""
echo "=== jscpd 중복 코드 감지 ==="
if ! command -v npx &>/dev/null; then
    printf '  \033[33m⚠\033[0m npx 없음 — skip\n'
else
    MAX_CLONES=0
    [[ -f .jscpd-max-clones ]] && MAX_CLONES=$(tr -d '[:space:]' < .jscpd-max-clones)
    SCAN_DIR="src"
    [[ ! -d src ]] && SCAN_DIR="."
    JSCPD_OUT=$(npx jscpd "$SCAN_DIR" \
        --min-lines 4 \
        --min-tokens 50 \
        --ignore "node_modules/**,dist/**,build/**,.next/**" \
        --reporters "console" 2>/dev/null)
    CLONES=$(echo "$JSCPD_OUT" | grep -oE 'Found [0-9]+ clones' | grep -oE '[0-9]+' || echo "0")
    if [[ "${CLONES}" -gt "${MAX_CLONES}" ]]; then
        echo "$JSCPD_OUT" | grep -A2 "Clone found" || true
        ng "jscpd: ${CLONES}개 클론 감지 (허용 최대: ${MAX_CLONES})"
    else
        ok "jscpd: ${CLONES}개 클론 (기준 통과)"
    fi
fi

echo ""
echo "=== 주석 금지 ==="
if [[ -f tools/scripts/no-comments-gate.sh ]]; then
    bash tools/scripts/no-comments-gate.sh || FAIL=1
else
    printf '  \033[33m⚠\033[0m no-comments-gate.sh 없음 — skip\n'
fi

echo ""
if [[ "$FAIL" != "0" ]]; then
    echo -e "\033[31m=== ✗ pre-commit 실패 ===\033[0m"
    exit 1
fi
echo -e "\033[32m=== ✓ 전체 통과 ===\033[0m"
