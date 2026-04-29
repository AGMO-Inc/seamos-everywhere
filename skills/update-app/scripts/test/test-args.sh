#!/usr/bin/env bash
#
# test-args.sh — Argument parsing tests for update-app/scripts/update.sh
#
# Validates the new convenience flags introduced alongside the SKILL.md
# argument-hint contract:
#   --feu-type FEU   — multipart part name (required when using convenience flags)
#   --fif PATH       — explicit .fif path
#   --arch ARCH      — resolve .fif by '<ARCH>-*.fif' in --build-dir
#   --build-dir DIR  — search root for --arch resolution
#
# Driven via --dry-run so no HTTP traffic. The dry-run output prints the
# fully-assembled curl arg vector, which we grep for the synthesized
# -F "feuType=@path" pair.
#
# Sandbox: all mock workspaces under mktemp -d /tmp/seamos-test-args-XXXXXX
# and removed via trap on EXIT. No network. No user-home writes.
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/seamos-test-args-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

UPDATE_SH="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/update-app/scripts/update.sh"
BASE_URL="http://localhost:8088"
API_KEY="testkey123"
APP_ID="10000"
REQUEST_JSON='{"variants":[]}'

PASS_COUNT=0
FAIL_LIST=()

assert() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL_LIST+=("$name")
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ $name"
    echo "    expected to contain: $needle"
    echo "    actual:              $haystack"
    FAIL_LIST+=("$name")
  fi
}

# ─── (a) --feu-type + --fif synthesizes a single -F pair ────────────────────
mkdir -p "$TMPDIR/builds"
echo 'fakefif' > "$TMPDIR/builds/RCU4-3Q-20.fif"

OUT_A=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --fif "$TMPDIR/builds/RCU4-3Q-20.fif" \
  --dry-run)

assert_contains "(a) --feu-type + --fif synthesizes -F pair" "$OUT_A" \
  "AUTO-IT_RV-C1000=@$TMPDIR/builds/RCU4-3Q-20.fif"

# ─── (b) --feu-type + --arch resolves .fif from --build-dir ─────────────────
OUT_B=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --arch "RCU4-3Q" \
  --build-dir "$TMPDIR/builds" \
  --dry-run)

assert_contains "(b) --arch resolves single match" "$OUT_B" \
  "AUTO-IT_RV-C1000=@$TMPDIR/builds/RCU4-3Q-20.fif"

# ─── (c) --arch with multiple matches errors out ────────────────────────────
echo 'fakefif2' > "$TMPDIR/builds/RCU4-3Q-21.fif"

set +e
OUT_C=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --arch "RCU4-3Q" \
  --build-dir "$TMPDIR/builds" \
  --dry-run 2>&1)
RC_C=$?
set -e

assert "(c) --arch multi-match exit code" "$RC_C" "1"
assert_contains "(c) --arch multi-match error message" "$OUT_C" \
  "multiple .fif matched"

# ─── (d) --arch with zero matches errors out ────────────────────────────────
set +e
OUT_D=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --arch "NONEXISTENT" \
  --build-dir "$TMPDIR/builds" \
  --dry-run 2>&1)
RC_D=$?
set -e

assert "(d) --arch no-match exit code" "$RC_D" "1"
assert_contains "(d) --arch no-match error message" "$OUT_D" \
  "no .fif matched"

# ─── (e) convenience + --app-file mutual exclusion ──────────────────────────
set +e
OUT_E=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --fif "$TMPDIR/builds/RCU4-3Q-20.fif" \
  --app-file "Other" "$TMPDIR/builds/RCU4-3Q-20.fif" \
  --dry-run 2>&1)
RC_E=$?
set -e

assert "(e) convenience + --app-file exit code" "$RC_E" "1"
assert_contains "(e) convenience + --app-file mutual exclusion message" "$OUT_E" \
  "cannot be combined with --app-file"

# ─── (f) --feu-type without --fif/--arch errors out ─────────────────────────
set +e
OUT_F=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --feu-type "AUTO-IT_RV-C1000" \
  --dry-run 2>&1)
RC_F=$?
set -e

assert "(f) --feu-type alone exit code" "$RC_F" "1"
assert_contains "(f) --feu-type alone error message" "$OUT_F" \
  "provide --fif PATH or --arch ARCH"

# ─── (g) --fif/--arch without --feu-type errors out ─────────────────────────
set +e
OUT_G=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --fif "$TMPDIR/builds/RCU4-3Q-20.fif" \
  --dry-run 2>&1)
RC_G=$?
set -e

assert "(g) --fif without --feu-type exit code" "$RC_G" "1"
assert_contains "(g) --fif without --feu-type error message" "$OUT_G" \
  "--feu-type is required"

# ─── (h) legacy --app-file path still works ─────────────────────────────────
OUT_H=$(bash "$UPDATE_SH" \
  --base-url "$BASE_URL" \
  --api-key "$API_KEY" \
  --app-id "$APP_ID" \
  --request "$REQUEST_JSON" \
  --app-file "AUTO-IT_RV-C1000" "$TMPDIR/builds/RCU4-3Q-20.fif" \
  --dry-run)

assert_contains "(h) legacy --app-file path" "$OUT_H" \
  "AUTO-IT_RV-C1000=@$TMPDIR/builds/RCU4-3Q-20.fif"

# ─── (i) API key masking in dry-run ─────────────────────────────────────────
assert_contains "(i) API key masked in dry-run output" "$OUT_A" \
  "${API_KEY:0:6}***"

# Negative: full API key should NOT appear after the masking marker.
if echo "$OUT_A" | grep -q "X-API-Key: ${API_KEY}\b"; then
  FAIL_LIST+=("(i) API key NOT masked")
else
  echo "  ✓ (i) raw API key absent from dry-run output"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

# ─── Summary ────────────────────────────────────────────────────────────────
if [[ ${#FAIL_LIST[@]} -eq 0 ]]; then
  echo ""
  echo "PASS ($PASS_COUNT assertions)"
  exit 0
else
  echo ""
  echo "FAIL"
  for f in "${FAIL_LIST[@]}"; do echo "  - $f"; done
  exit 1
fi
