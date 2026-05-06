#!/usr/bin/env bash
# find-user-root-test.sh — Stand-alone unit test for find-user-root.sh.
# Covers 5 cases: marker priority, .mcp.json back-compat, both markers,
# missing-marker error (exit 64), and SEAMOS_ALLOW_PWD_FALLBACK=1 fallback.
set -euo pipefail

readonly LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/find-user-root.sh"
readonly FIXTURE="/tmp/fur-test-$$"

cleanup() { rm -rf "${FIXTURE}"; }
trap cleanup EXIT

fail() { echo "[find-user-root-test] FAIL: $1" >&2; exit 1; }
pass() { echo "[find-user-root-test] PASS"; }

# Case A — .seamos-workspace.json only → resolves
mkdir -p "${FIXTURE}/A/sub/deeper"
echo '{}' > "${FIXTURE}/A/.seamos-workspace.json"
out_a="$(cd "${FIXTURE}/A/sub/deeper" && bash "$LIB")"
expected="$(cd "${FIXTURE}/A" && pwd -P)"
[[ "$out_a" == "$expected" ]] || fail "Case A: expected '$expected' got '$out_a'"
echo "Case A: PASS"

# Case B — .mcp.json only (back-compat) → resolves
mkdir -p "${FIXTURE}/B/sub"
echo '{"mcpServers":{}}' > "${FIXTURE}/B/.mcp.json"
out_b="$(cd "${FIXTURE}/B/sub" && bash "$LIB")"
expected="$(cd "${FIXTURE}/B" && pwd -P)"
[[ "$out_b" == "$expected" ]] || fail "Case B: expected '$expected' got '$out_b'"
echo "Case B: PASS"

# Case C — both markers present → resolves to nearest containing dir (deterministic)
mkdir -p "${FIXTURE}/C/sub"
echo '{}' > "${FIXTURE}/C/.seamos-workspace.json"
echo '{}' > "${FIXTURE}/C/.mcp.json"
out_c="$(cd "${FIXTURE}/C/sub" && bash "$LIB")"
expected="$(cd "${FIXTURE}/C" && pwd -P)"
[[ "$out_c" == "$expected" ]] || fail "Case C: expected '$expected' got '$out_c'"
echo "Case C: PASS"

# Case D — neither marker, fallback off → exit 64 + error message
mkdir -p "${FIXTURE}/D/sub"
set +e
err_d="$(cd "${FIXTURE}/D/sub" && bash "$LIB" 2>&1 1>/dev/null)"
rc_d=$?
set -e
[[ "$rc_d" == "64" ]] || fail "Case D: expected exit 64, got $rc_d"
echo "$err_d" | grep -q "no .mcp.json or .seamos-workspace.json" \
  || fail "Case D: expected error message about both markers, got: $err_d"
echo "Case D: PASS"

# Case E — neither marker, fallback on → echoes PWD with WARN
mkdir -p "${FIXTURE}/E/sub"
out_e="$(cd "${FIXTURE}/E/sub" && SEAMOS_ALLOW_PWD_FALLBACK=1 bash "$LIB" 2>/dev/null)"
err_e="$(cd "${FIXTURE}/E/sub" && SEAMOS_ALLOW_PWD_FALLBACK=1 bash "$LIB" 2>&1 1>/dev/null)"
expected="$(cd "${FIXTURE}/E/sub" && pwd -P)"
[[ "$out_e" == "$expected" ]] || fail "Case E: expected '$expected' got '$out_e'"
echo "$err_e" | grep -q "WARN" || fail "Case E: expected WARN in stderr, got: $err_e"
echo "Case E: PASS"

pass
