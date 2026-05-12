#!/usr/bin/env bash
# test.sh — Stand-alone test for `setup.sh --adopt` mode.
# Covers 4 fixtures: nested-pristine, flat-pristine, partial-context,
# mismatched-ssot. Verifies non-destructive invariant (sha256 of every file
# except .seamos-context.json unchanged) + exit code matrix + stdout message.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SETUP_SH="$SCRIPT_DIR/../../setup.sh"
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

# Compute sha256 of every regular file under a dir, EXCLUDING the given path
# (relative to fixture root). Output is `<sha>  <relpath>` lines, sorted.
# macOS shasum -a 256, falls back to sha256sum on Linux.
sha_all_except() {
  local root="$1" exclude_rel="$2"
  local sha_cmd
  if command -v shasum >/dev/null 2>&1; then
    sha_cmd="shasum -a 256"
  else
    sha_cmd="sha256sum"
  fi
  ( cd "$root" && \
      find . -type f ! -path "./$exclude_rel" ! -name '*.bak' -print0 \
      | xargs -0 $sha_cmd 2>/dev/null \
      | sort )
}

# Capture mtime of one file (sec since epoch). Empty if missing.
mtime_of() {
  local f="$1"
  if [[ -f "$f" ]]; then
    stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null
  fi
}

# Restore baseline state for a fixture (delete .seamos-context.json that adopt
# wrote, restore any .bak originals). Safe to call multiple times.
reset_fixture() {
  local fixture_root="$1"
  local saved_ctx="$2"  # caller stashes pre-test .seamos-context.json content here, or empty

  rm -f "$fixture_root/.seamos-context.json"
  if [[ -n "$saved_ctx" ]]; then
    printf '%s' "$saved_ctx" > "$fixture_root/.seamos-context.json"
  fi
  restore_tokens "$fixture_root"
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  OK  [$name] '$expected'"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] expected '$expected' got '$actual'"
    FAIL=$((FAIL+1))
  fi
}

assert_exit_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  OK  [$name] exit code == $expected"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] expected exit $expected got $actual"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  OK  [$name] output contains '$needle'"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] output should contain '$needle', got: $haystack"
    FAIL=$((FAIL+1))
  fi
}

assert_count() {
  local name="$1" needle="$2" haystack="$3" expected_count="$4"
  local actual_count
  actual_count="$(printf '%s\n' "$haystack" | grep -cF "$needle" || true)"
  if [[ "$actual_count" == "$expected_count" ]]; then
    echo "  OK  [$name] '$needle' appears $expected_count time(s)"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] '$needle' expected $expected_count, got $actual_count: $haystack"
    FAIL=$((FAIL+1))
  fi
}

assert_jq_eq() {
  local name="$1" file="$2" expr="$3" expected="$4"
  local actual
  actual="$(jq -r "$expr" "$file" 2>/dev/null || echo "JQ_ERR")"
  assert_eq "$name" "$expected" "$actual"
}

# Snapshot pre-state, run a command, then verify the non-destructive invariant.
# Args: <fixture_root> <test_name> -- <cmd...>
# Returns the command's exit code in $RUN_EXIT and stdout/stderr in
# $RUN_STDOUT / $RUN_STDERR. After run, asserts sha256 of all files (excluding
# .seamos-context.json) is identical to pre-state.
RUN_EXIT=0
RUN_STDOUT=""
RUN_STDERR=""
run_and_check_invariant() {
  local fixture_root="$1"
  local test_name="$2"
  shift 2
  # consume `--`
  if [[ "${1:-}" == "--" ]]; then shift; fi

  local sha_before
  sha_before="$(sha_all_except "$fixture_root" ".seamos-context.json")"

  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  RUN_EXIT=$?
  set -e
  RUN_STDOUT="$(cat "$stdout_file")"
  RUN_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"

  local sha_after
  sha_after="$(sha_all_except "$fixture_root" ".seamos-context.json")"
  if [[ "$sha_before" == "$sha_after" ]]; then
    echo "  OK  [$test_name] non-destructive invariant: sha256 of all non-context files unchanged"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$test_name] non-destructive invariant VIOLATED"
    echo "  --- before:"
    echo "$sha_before"
    echo "  --- after:"
    echo "$sha_after"
    FAIL=$((FAIL+1))
  fi
}

# Cleanup on exit
cleanup_all() {
  local fx
  for fx in "$FIXTURES_DIR"/*/; do
    restore_tokens "$fx"
  done
}
trap cleanup_all EXIT

# ========================================================================
# F1 — nested-pristine: no context, Layout A on disk
# ========================================================================
echo "=== F1: nested-pristine ==="
FX1="$FIXTURES_DIR/nested-pristine"
FX1_ABS="$(cd "$FX1" && pwd -P)"
rm -f "$FX1/.seamos-context.json"

run_and_check_invariant "$FX1" "F1" -- \
  bash "$SETUP_SH" --adopt --workspace-dir "$FX1_ABS"

assert_exit_eq "F1" 0 "$RUN_EXIT"
assert_count   "F1-msg-once" "context 5필드를 기록했습니다" "$RUN_STDOUT" 1
assert_contains "F1-msg-path" "$FX1_ABS/.seamos-context.json" "$RUN_STDOUT"

if [[ -f "$FX1/.seamos-context.json" ]]; then
  assert_jq_eq "F1-fsp"   "$FX1/.seamos-context.json" '.last_project.fsp_path'          "$FX1_ABS/foo/foo/com.bosch.fsp.foo"
  assert_jq_eq "F1-sdk"   "$FX1/.seamos-context.json" '.last_project.sdk_project_path'  "$FX1_ABS/foo/foo/foo_CPP_SDK"
  assert_jq_eq "F1-app"   "$FX1/.seamos-context.json" '.last_project.app_project_path'  "$FX1_ABS/foo/foo/foo_App"
  assert_jq_eq "F1-deep"  "$FX1/.seamos-context.json" '.last_project.deep_ui_path'      "$FX1_ABS/foo/foo/foo_App/ui"
  assert_jq_eq "F1-cui"   "$FX1/.seamos-context.json" '.last_project.customui_src_path' "$FX1_ABS/foo/customui-src"
  assert_jq_eq "F1-layout" "$FX1/.seamos-context.json" '.last_project.layout_kind'      "nested"
else
  echo "  FAIL [F1] .seamos-context.json was not written"
  FAIL=$((FAIL+1))
fi
rm -f "$FX1/.seamos-context.json"

# ========================================================================
# F2 — flat-pristine: no context, Layout B on disk
# ========================================================================
echo "=== F2: flat-pristine ==="
FX2="$FIXTURES_DIR/flat-pristine"
FX2_ABS="$(cd "$FX2" && pwd -P)"
rm -f "$FX2/.seamos-context.json"

run_and_check_invariant "$FX2" "F2" -- \
  bash "$SETUP_SH" --adopt --workspace-dir "$FX2_ABS"

assert_exit_eq "F2" 0 "$RUN_EXIT"
assert_count   "F2-msg-once" "context 5필드를 기록했습니다" "$RUN_STDOUT" 1

if [[ -f "$FX2/.seamos-context.json" ]]; then
  assert_jq_eq "F2-fsp"    "$FX2/.seamos-context.json" '.last_project.fsp_path'          "$FX2_ABS/com.bosch.fsp.foo"
  assert_jq_eq "F2-sdk"    "$FX2/.seamos-context.json" '.last_project.sdk_project_path'  "$FX2_ABS/foo_CPP_SDK"
  assert_jq_eq "F2-app"    "$FX2/.seamos-context.json" '.last_project.app_project_path'  "$FX2_ABS/foo_App"
  assert_jq_eq "F2-deep"   "$FX2/.seamos-context.json" '.last_project.deep_ui_path'      "$FX2_ABS/foo_App/ui"
  assert_jq_eq "F2-cui"    "$FX2/.seamos-context.json" '.last_project.customui_src_path' "$FX2_ABS/customui-src"
  assert_jq_eq "F2-layout" "$FX2/.seamos-context.json" '.last_project.layout_kind'       "flat"
else
  echo "  FAIL [F2] .seamos-context.json was not written"
  FAIL=$((FAIL+1))
fi
rm -f "$FX2/.seamos-context.json"

# ========================================================================
# F3 — partial-context: 3-field context + Layout A on disk → re-infer + warn
# ========================================================================
echo "=== F3: partial-context ==="
FX3="$FIXTURES_DIR/partial-context"
FX3_ABS="$(cd "$FX3" && pwd -P)"
# Save original partial-context content (so we can restore if needed for re-run)
PARTIAL_TEMPLATE="$(cat "$FX3/.seamos-context.json")"
materialize_tokens "$FX3"

# Adopt on partial context requires --force (because context exists)
run_and_check_invariant "$FX3" "F3" -- \
  bash "$SETUP_SH" --adopt --force --workspace-dir "$FX3_ABS"

assert_exit_eq "F3" 0 "$RUN_EXIT"
assert_contains "F3-warn-partial" "partial" "$RUN_STDERR"
if [[ -f "$FX3/.seamos-context.json" ]]; then
  assert_jq_eq "F3-fsp"    "$FX3/.seamos-context.json" '.last_project.fsp_path'          "$FX3_ABS/foo/foo/com.bosch.fsp.foo"
  assert_jq_eq "F3-deep"   "$FX3/.seamos-context.json" '.last_project.deep_ui_path'      "$FX3_ABS/foo/foo/foo_App/ui"
  assert_jq_eq "F3-cui"    "$FX3/.seamos-context.json" '.last_project.customui_src_path' "$FX3_ABS/foo/customui-src"
  assert_jq_eq "F3-layout" "$FX3/.seamos-context.json" '.last_project.layout_kind'       "nested"
fi
# Restore template for next run
restore_tokens "$FX3"

# ========================================================================
# F4 — mismatched-ssot: default abort (exit 65), --force overrides with disk
# ========================================================================
echo "=== F4: mismatched-ssot (default abort) ==="
FX4="$FIXTURES_DIR/mismatched-ssot"
FX4_ABS="$(cd "$FX4" && pwd -P)"
MISMATCH_TEMPLATE="$(cat "$FX4/.seamos-context.json")"
materialize_tokens "$FX4"

# Capture context mtime before — must remain unchanged on abort
ctx_mtime_before="$(mtime_of "$FX4/.seamos-context.json")"

run_and_check_invariant "$FX4" "F4-abort" -- \
  bash "$SETUP_SH" --adopt --workspace-dir "$FX4_ABS"

assert_exit_eq "F4-abort" 65 "$RUN_EXIT"
assert_contains "F4-msg-mismatch" "mismatch" "$RUN_STDERR"
ctx_mtime_after="$(mtime_of "$FX4/.seamos-context.json")"
assert_eq "F4-abort-mtime" "$ctx_mtime_before" "$ctx_mtime_after"

# Now run with --force → disk wins
restore_tokens "$FX4"
materialize_tokens "$FX4"
echo "=== F4: mismatched-ssot --force (disk wins) ==="
run_and_check_invariant "$FX4" "F4-force" -- \
  bash "$SETUP_SH" --adopt --force --workspace-dir "$FX4_ABS"

assert_exit_eq "F4-force" 0 "$RUN_EXIT"
if [[ -f "$FX4/.seamos-context.json" ]]; then
  # After --force, disk (flat) wins — fsp_path must be flat
  assert_jq_eq "F4-force-fsp"    "$FX4/.seamos-context.json" '.last_project.fsp_path'    "$FX4_ABS/com.bosch.fsp.foo"
  assert_jq_eq "F4-force-layout" "$FX4/.seamos-context.json" '.last_project.layout_kind' "flat"
fi
restore_tokens "$FX4"

# ========================================================================
# F5 — --dry-run on nested-pristine: prints intended fields, writes nothing
# ========================================================================
echo "=== F5: --dry-run ==="
FX5="$FIXTURES_DIR/nested-pristine"
FX5_ABS="$(cd "$FX5" && pwd -P)"
rm -f "$FX5/.seamos-context.json"

# Dry-run must not create the file
run_and_check_invariant "$FX5" "F5-dryrun" -- \
  bash "$SETUP_SH" --adopt --dry-run --workspace-dir "$FX5_ABS"

assert_exit_eq "F5-dryrun" 0 "$RUN_EXIT"
assert_contains "F5-dryrun-prefix" "[dry-run]" "$RUN_STDOUT"
assert_contains "F5-dryrun-fsp"    "fsp_path" "$RUN_STDOUT"
if [[ ! -f "$FX5/.seamos-context.json" ]]; then
  echo "  OK  [F5-dryrun] .seamos-context.json NOT written"
  PASS=$((PASS+1))
else
  echo "  FAIL [F5-dryrun] .seamos-context.json should not exist after dry-run"
  FAIL=$((FAIL+1))
  rm -f "$FX5/.seamos-context.json"
fi

# ========================================================================
# Summary
# ========================================================================
echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
exit $FAIL
