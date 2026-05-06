#!/usr/bin/env bash
# smoke.sh — Docker-free, network-free smoke test for the init-customui skill.
# Exercises init-customui.sh against temp fixtures under /tmp:
#   1) sanity (script is executable)
#   2) vanilla real run sets ui.defaultFramework="vanilla" + ui.activeSrcPath
#   3) vanilla idempotent re-run emits [skip] and STATUS_OK
#   4) missing workspace JSON → exit 64
#   5) react --dry-run previews actions, no clone, no JSON mutation
#   6) destructive transition + --non-interactive without --reset → [skip] mode mismatch
#
# Constraints: no network, no docker, no git, no npm. Mutates only ${FIXTURE} under /tmp.
#
# Note on STATUS_WARN: only STATUS_OK counts as success — same convention as setup smoke.
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
readonly ICU="${REPO_ROOT}/skills/init-customui/scripts/init-customui.sh"
readonly FIXTURE="/tmp/icu-smoke-$$"

cleanup() { rm -rf "${FIXTURE}"; }
trap cleanup EXIT

fail() { echo "[smoke] FAIL: $1" >&2; exit 1; }
pass() { echo "[smoke] PASS"; }

# Setup helper: write workspace JSON + context JSON + deep ui/ for a case
setup_fixture() {
  local dir="$1" framework="${2:-null}"
  mkdir -p "$dir/MyProj/MyProj/MyProj_App/ui"
  cat > "$dir/.seamos-workspace.json" <<EOF
{
  "schemaVersion": 1,
  "createdAt": "2026-05-06T00:00:00Z",
  "scope": "project",
  "ui": {
    "defaultFramework": ${framework},
    "activeSrcPath": null,
    "react": {
      "templateRepo": "https://github.com/AGMO-Inc/custom-ui-react-template",
      "templateRef": "main"
    }
  },
  "marketplace": {
    "endpoint": "dev",
    "endpointUrl": "https://dev.marketplace-api.seamos.io/mcp"
  }
}
EOF
  cat > "$dir/.seamos-context.json" <<EOF
{
  "last_project": {
    "name": "MyProj",
    "app_project_name": "MyProj_App",
    "app_project_path": "$dir/MyProj/MyProj/MyProj_App"
  }
}
EOF
}

# 1. Sanity
[[ -x "$ICU" ]] || fail "init-customui.sh not executable at $ICU"

# 2. Vanilla real run sets defaultFramework correctly
setup_fixture "$FIXTURE/v1" 'null'
(cd "$FIXTURE/v1" && bash "$ICU" --ui vanilla --non-interactive >/dev/null) \
  || fail "vanilla real run exited non-zero"
jq -e '.ui.defaultFramework == "vanilla" and .ui.activeSrcPath != null' \
  "$FIXTURE/v1/.seamos-workspace.json" >/dev/null \
  || fail "workspace JSON not updated to vanilla"

# 3. Vanilla idempotent re-run emits [skip] and STATUS_OK
out2="$(cd "$FIXTURE/v1" && bash "$ICU" --ui vanilla --non-interactive)"
echo "$out2" | grep -q '\[skip\]' || fail "idempotent re-run did not emit [skip]"
echo "$out2" | tail -n1 | grep -q '^STATUS_OK$' || fail "idempotent re-run last line not STATUS_OK"

# 4. Missing workspace JSON → exit 64
setup_fixture "$FIXTURE/missing" 'null'
rm "$FIXTURE/missing/.seamos-workspace.json"
set +e
(cd "$FIXTURE/missing" && bash "$ICU" --ui vanilla --non-interactive 2>/dev/null)
rc=$?
set -e
[[ "$rc" == "64" ]] || fail "missing workspace JSON should exit 64, got $rc"

# 5. React dry-run prints expected actions (no actual clone)
setup_fixture "$FIXTURE/r1" 'null'
out_r="$(cd "$FIXTURE/r1" && bash "$ICU" --ui react --non-interactive --dry-run)"
echo "$out_r" | grep -q 'git clone' || fail "react dry-run did not preview git clone"
echo "$out_r" | grep -q 'customui-src' || fail "react dry-run did not mention customui-src"
echo "$out_r" | tail -n1 | grep -q '^STATUS_OK$' || fail "react dry-run last line not STATUS_OK"
# No mutation
[[ ! -d "$FIXTURE/r1/MyProj/customui-src" ]] || fail "react dry-run actually created customui-src/"
jq -e '.ui.defaultFramework == null' "$FIXTURE/r1/.seamos-workspace.json" >/dev/null \
  || fail "react dry-run mutated workspace JSON"

# 6. Destructive transition + --non-interactive without --reset → skip
setup_fixture "$FIXTURE/dest1" '"vanilla"'
# mark workspace as already in vanilla mode
jq '.ui.activeSrcPath = "MyProj/MyProj/MyProj_App/ui"' "$FIXTURE/dest1/.seamos-workspace.json" \
  > "$FIXTURE/dest1/.ws.tmp" && mv "$FIXTURE/dest1/.ws.tmp" "$FIXTURE/dest1/.seamos-workspace.json"
out_d="$(cd "$FIXTURE/dest1" && bash "$ICU" --ui react --non-interactive)"
echo "$out_d" | grep -q '\[skip\] mode mismatch' || fail "destructive without --reset should emit [skip] mode mismatch"
echo "$out_d" | tail -n1 | grep -q '^STATUS_OK$' || fail "destructive skip last line not STATUS_OK"

pass
