#!/usr/bin/env bash
set -euo pipefail

SKILL_MD="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/update-app/SKILL.md"
CACHE_MD="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/shared-references/seamos-context-cache.md"
FIXTURE="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/update-app/scripts/test/fixtures/get_app_status_no_feutype.json"

PASS_COUNT=0
FAIL_LIST=()

assert_grep() {
  local name="$1" pattern="$2" file="$3" min_count="${4:-1}"
  local count
  count=$(grep -cE "$pattern" "$file" 2>/dev/null) || count=0
  if [[ "$count" -ge "$min_count" ]]; then
    echo "  ✓ $name (${count} matches)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ $name — expected ≥${min_count}, got ${count}"
    FAIL_LIST+=("$name")
  fi
}

assert_no_grep() {
  local name="$1" pattern="$2" file="$3"
  local count
  count=$(grep -cE "$pattern" "$file" 2>/dev/null) || count=0
  if [[ "$count" -eq 0 ]]; then
    echo "  ✓ $name (0 matches)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ $name — expected 0, got ${count}"
    FAIL_LIST+=("$name")
  fi
}

echo "Checking update-app/SKILL.md..."

# (a) argument-hint 에 --feu-type 등장
assert_grep "(a) argument-hint includes --feu-type" '^argument-hint:.*--feu-type' "$SKILL_MD"

# (b) fallback 영역에 ARCH 와 feuType 모두 등장
assert_grep "(b) fallback mentions ARCH" 'ARCH' "$SKILL_MD" 1
assert_grep "(b) fallback mentions feuType" 'feuType' "$SKILL_MD" 1

# (c) 금지어 부재 — 휴리스틱/heuristic/추정/infer/auto-select/auto-apply 가 fallback/캐시 절차 영역에 없음
# (전체 파일 검사 — 본문에 어디든 등장하면 fail)
assert_no_grep "(c) no '휴리스틱' (heuristic in Korean)" '휴리스틱' "$SKILL_MD"
assert_no_grep "(c) no 'heuristic'" 'heuristic' "$SKILL_MD"
assert_no_grep "(c) no 'auto-select'" 'auto-select' "$SKILL_MD"
assert_no_grep "(c) no 'auto-apply'" 'auto-apply' "$SKILL_MD"

# (d) last_app_register.feuType 토큰 존재
assert_grep "(d) last_app_register.feuType referenced" 'last_app_register\.feuType' "$SKILL_MD"

# (e) 단일 feuType 정책
assert_grep "(e) one-feuType-per-invocation policy" '한 번에 하나의 feuType|one feuType per invocation' "$SKILL_MD"

# (f) 다중 ARCH 분기 단락
assert_grep "(f) multiple ARCH branch present" '다중 ARCH|multiple .fif' "$SKILL_MD"

echo ""
echo "Checking shared-references/seamos-context-cache.md..."

# (g) last_app_register 토큰 ≥ 4 회 (헤더 + 4 필드)
assert_grep "(g) last_app_register tokens (cache doc)" 'last_app_register' "$CACHE_MD" 4

echo ""
echo "Checking fixture..."

command -v jq >/dev/null || { echo "jq not installed"; exit 1; }

# Fixture 검증 — valid JSON 이고 feuType 키 없음
if jq . "$FIXTURE" >/dev/null 2>&1; then
  echo "  ✓ fixture is valid JSON"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ fixture is not valid JSON"
  FAIL_LIST+=("fixture-json")
fi

if jq -e '.feuType' "$FIXTURE" >/dev/null 2>&1; then
  echo "  ✗ fixture should NOT contain feuType key"
  FAIL_LIST+=("fixture-feutype-absent")
else
  echo "  ✓ fixture lacks feuType (fallback trigger)"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

echo ""
if [[ ${#FAIL_LIST[@]} -eq 0 ]]; then
  echo "PASS ($PASS_COUNT assertions)"
  exit 0
else
  echo "FAIL"
  for f in "${FAIL_LIST[@]}"; do echo "  - $f"; done
  exit 1
fi
