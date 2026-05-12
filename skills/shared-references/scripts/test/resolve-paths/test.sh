#!/usr/bin/env bash
# test.sh — Stand-alone unit test for resolve-paths.sh.
# Covers 6 fixtures: nested+context, flat+context, no-context+nested-disk,
# no-context+flat-disk, mismatched-ssot, partial-context.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HELPER="$SCRIPT_DIR/../../resolve-paths.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0

# --- helpers ---------------------------------------------------------------

# Materialize __USER_ROOT__ tokens in *.json under a fixture dir into the
# fixture's actual absolute path. Idempotent — backup-and-restore via .bak.
materialize_tokens() {
  local fixture_root="$1"
  local abs_root
  abs_root="$(cd "$fixture_root" && pwd -P)"
  local f
  for f in "$fixture_root"/.seamos-context.json "$fixture_root"/.seamos-workspace.json; do
    if [[ -f "$f" ]]; then
      cp "$f" "$f.bak"
      sed "s|__USER_ROOT__|$abs_root|g" "$f.bak" > "$f"
    fi
  done
}

restore_tokens() {
  local fixture_root="$1"
  local f
  for f in "$fixture_root"/.seamos-context.json "$fixture_root"/.seamos-workspace.json; do
    if [[ -f "$f.bak" ]]; then
      mv "$f.bak" "$f"
    fi
  done
}

assert_kv_eq() {
  local name="$1" key="$2" expected="$3" out="$4"
  local actual
  actual="$(printf '%s\n' "$out" | grep "^${key}=" | head -1 | cut -d= -f2-)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  OK  [$name] $key == '$expected'"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] $key expected '$expected' got '$actual'"
    FAIL=$((FAIL+1))
  fi
}

assert_stderr_contains() {
  local name="$1" expected="$2" stderr_content="$3"
  if printf '%s' "$stderr_content" | grep -q "$expected"; then
    echo "  OK  [$name] stderr contains '$expected'"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] stderr should contain '$expected', got: $stderr_content"
    FAIL=$((FAIL+1))
  fi
}

assert_no_write() {
  local name="$1" file="$2" mtime_before="$3"
  local mtime_after
  mtime_after="$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)"
  if [[ "$mtime_before" == "$mtime_after" ]]; then
    echo "  OK  [$name] $file mtime unchanged (read-only)"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] $file mtime changed — helper violated read-only"
    FAIL=$((FAIL+1))
  fi
}

# Cleanup all .bak on EXIT so re-runs are clean
cleanup_all() {
  local fx
  for fx in "$FIXTURES_DIR"/*/; do
    restore_tokens "$fx"
  done
}
trap cleanup_all EXIT

# --- F1: nested-full → context 그대로 ----------------------------------------
echo "=== F1: nested-full ==="
F1="$FIXTURES_DIR/F1-nested-full"
materialize_tokens "$F1"
F1_ABS="$(cd "$F1" && pwd -P)"
mtime_before="$(stat -f %m "$F1/.seamos-context.json" 2>/dev/null || stat -c %Y "$F1/.seamos-context.json")"
out_f1="$(bash "$HELPER" "$F1_ABS" 2>/dev/null)"
err_f1="$(bash "$HELPER" "$F1_ABS" 2>&1 >/dev/null)"
assert_kv_eq F1 LAYOUT_KIND "nested" "$out_f1"
assert_kv_eq F1 FSP_PATH "$F1_ABS/foo/foo/com.bosch.fsp.foo" "$out_f1"
assert_kv_eq F1 APP_PROJECT_PATH "$F1_ABS/foo/foo/foo_App" "$out_f1"
assert_kv_eq F1 SDK_PROJECT_PATH "$F1_ABS/foo/foo/foo_CPP_SDK" "$out_f1"
assert_kv_eq F1 DEEP_UI_PATH "$F1_ABS/foo/foo/foo_App/ui" "$out_f1"
assert_kv_eq F1 CUSTOMUI_SRC_PATH "$F1_ABS/foo/customui-src" "$out_f1"
assert_kv_eq F1 WORKSPACE_PATH "$F1_ABS/foo" "$out_f1"
assert_kv_eq F1 MOUNT_ROOT "$F1_ABS/foo" "$out_f1"
assert_kv_eq F1 APP_PROJECT_PATH_CONTAINER "/workspace/foo/foo_App" "$out_f1"
assert_kv_eq F1 FSP_PATH_CONTAINER "/workspace/foo/com.bosch.fsp.foo" "$out_f1"
assert_no_write F1 "$F1/.seamos-context.json" "$mtime_before"

# --- F2: flat-full → context 그대로 ------------------------------------------
echo "=== F2: flat-full ==="
F2="$FIXTURES_DIR/F2-flat-full"
materialize_tokens "$F2"
F2_ABS="$(cd "$F2" && pwd -P)"
mtime_before="$(stat -f %m "$F2/.seamos-context.json" 2>/dev/null || stat -c %Y "$F2/.seamos-context.json")"
out_f2="$(bash "$HELPER" "$F2_ABS" 2>/dev/null)"
assert_kv_eq F2 LAYOUT_KIND "flat" "$out_f2"
assert_kv_eq F2 FSP_PATH "$F2_ABS/com.bosch.fsp.foo" "$out_f2"
assert_kv_eq F2 APP_PROJECT_PATH "$F2_ABS/foo_App" "$out_f2"
assert_kv_eq F2 SDK_PROJECT_PATH "$F2_ABS/foo_CPP_SDK" "$out_f2"
assert_kv_eq F2 DEEP_UI_PATH "$F2_ABS/foo_App/ui" "$out_f2"
assert_kv_eq F2 CUSTOMUI_SRC_PATH "$F2_ABS/customui-src" "$out_f2"
assert_kv_eq F2 WORKSPACE_PATH "$F2_ABS" "$out_f2"
assert_kv_eq F2 MOUNT_ROOT "$F2_ABS" "$out_f2"
assert_kv_eq F2 APP_PROJECT_PATH_CONTAINER "/workspace/foo_App" "$out_f2"
assert_kv_eq F2 FSP_PATH_CONTAINER "/workspace/com.bosch.fsp.foo" "$out_f2"
assert_no_write F2 "$F2/.seamos-context.json" "$mtime_before"

# --- F3: no-context-nested-disk → disk inference + WARN ---------------------
echo "=== F3: no-context-nested-disk ==="
F3="$FIXTURES_DIR/F3-no-context-nested-disk"
F3_ABS="$(cd "$F3" && pwd -P)"
out_f3="$(bash "$HELPER" "$F3_ABS" 2>/dev/null)"
err_f3="$(bash "$HELPER" "$F3_ABS" 2>&1 >/dev/null)"
assert_kv_eq F3 LAYOUT_KIND "nested" "$out_f3"
assert_kv_eq F3 FSP_PATH "$F3_ABS/foo/foo/com.bosch.fsp.foo" "$out_f3"
assert_kv_eq F3 APP_PROJECT_PATH "$F3_ABS/foo/foo/foo_App" "$out_f3"
assert_kv_eq F3 WORKSPACE_PATH "$F3_ABS/foo" "$out_f3"
assert_kv_eq F3 MOUNT_ROOT "$F3_ABS/foo" "$out_f3"
assert_stderr_contains F3 "WARN" "$err_f3"
assert_stderr_contains F3 "no context" "$err_f3"

# --- F4: no-context-flat-disk → disk inference + WARN -----------------------
echo "=== F4: no-context-flat-disk ==="
F4="$FIXTURES_DIR/F4-no-context-flat-disk"
F4_ABS="$(cd "$F4" && pwd -P)"
out_f4="$(bash "$HELPER" "$F4_ABS" 2>/dev/null)"
err_f4="$(bash "$HELPER" "$F4_ABS" 2>&1 >/dev/null)"
assert_kv_eq F4 LAYOUT_KIND "flat" "$out_f4"
assert_kv_eq F4 FSP_PATH "$F4_ABS/com.bosch.fsp.foo" "$out_f4"
assert_kv_eq F4 APP_PROJECT_PATH "$F4_ABS/foo_App" "$out_f4"
assert_kv_eq F4 WORKSPACE_PATH "$F4_ABS" "$out_f4"
assert_kv_eq F4 MOUNT_ROOT "$F4_ABS" "$out_f4"
assert_stderr_contains F4 "WARN" "$err_f4"

# --- F5: mismatched-ssot → context 사용 + WARN mismatch ---------------------
echo "=== F5: mismatched-ssot ==="
F5="$FIXTURES_DIR/F5-mismatched-ssot"
materialize_tokens "$F5"
F5_ABS="$(cd "$F5" && pwd -P)"
out_f5="$(bash "$HELPER" "$F5_ABS" 2>/dev/null)"
err_f5="$(bash "$HELPER" "$F5_ABS" 2>&1 >/dev/null)"
assert_kv_eq F5 LAYOUT_KIND "flat" "$out_f5"
assert_kv_eq F5 CUSTOMUI_SRC_PATH "$F5_ABS/customui-src" "$out_f5"
assert_stderr_contains F5 "mismatch" "$err_f5"

# --- F6: partial-context → all-or-nothing fallback to disk ------------------
echo "=== F6: partial-context ==="
F6="$FIXTURES_DIR/F6-partial-context"
materialize_tokens "$F6"
F6_ABS="$(cd "$F6" && pwd -P)"
out_f6="$(bash "$HELPER" "$F6_ABS" 2>/dev/null)"
err_f6="$(bash "$HELPER" "$F6_ABS" 2>&1 >/dev/null)"
assert_kv_eq F6 LAYOUT_KIND "flat" "$out_f6"
assert_kv_eq F6 FSP_PATH "$F6_ABS/com.bosch.fsp.foo" "$out_f6"
assert_kv_eq F6 SDK_PROJECT_PATH "$F6_ABS/foo_CPP_SDK" "$out_f6"
assert_kv_eq F6 DEEP_UI_PATH "$F6_ABS/foo_App/ui" "$out_f6"
assert_kv_eq F6 CUSTOMUI_SRC_PATH "$F6_ABS/customui-src" "$out_f6"
assert_stderr_contains F6 "partial" "$err_f6"

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
exit $FAIL
