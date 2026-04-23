#!/bin/bash
# smoke.sh — Docker-free smoke test for regen-sdk-app skill.
# Exercises the path-resolution / context-reading / config.prop-emission logic
# via --dry-run on a temporary fixture USER_ROOT. No docker, no FD invocation.
#
# Runs 4 scenarios:
#   A. missing context         → exit 64, mentions create-project
#   B. partial context         → exit 64, enumerates missing fields
#   C. full context, dry-run   → exit 0, emits all 10 path variables + docker cmd
#   D. invoked from subdir     → USER_ROOT resolves via upward .mcp.json search
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/regen-sdk-app.sh"
BUILD_CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/create-project/scripts/build-config-prop.sh"

FIXT="$(mktemp -d /tmp/regen-sdk-app-smoke.XXXXXX)"
cleanup() {
  find "$FIXT" -type f -delete 2>/dev/null || true
  find "$FIXT" -depth -type d -empty -delete 2>/dev/null || true
}
trap cleanup EXIT

PASS=0
FAIL=0
assert() {
  local label="$1" cond="$2"
  if eval "$cond"; then
    echo "  [PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label"
    FAIL=$((FAIL + 1))
  fi
}

cd "$FIXT"
touch .mcp.json

# ─── Case A: missing context ───────────────────────────────────────────────
echo "=== Case A: missing context file ==="
set +e
OUT_A="$(bash "$SCRIPT" --dry-run 2>&1)"
EXIT_A=$?
set -e
assert "Case A exits 64"               '[[ $EXIT_A -eq 64 ]]'
assert "Case A mentions create-project" '[[ "$OUT_A" == *create-project* ]]'

# ─── Case B: partial context, no app_project_path ─────────────────────────
echo "=== Case B: partial context ==="
cat > .seamos-context.json <<JSON
{"last_project":{"name":"MyProj","workspace_path":"$FIXT"}}
JSON
set +e
OUT_B="$(bash "$SCRIPT" --dry-run 2>&1)"
EXIT_B=$?
set -e
assert "Case B exits 64"                      '[[ $EXIT_B -eq 64 ]]'
assert "Case B lists APP_PROJECT_PATH missing" '[[ "$OUT_B" == *APP_PROJECT_PATH* ]]'

# ─── Case C: full context, dry-run happy path ─────────────────────────────
echo "=== Case C: full context ==="
cat > .seamos-context.json <<JSON
{
  "last_project": {
    "name": "MyProj",
    "workspace_path": "$FIXT",
    "app_project_name": "MyApp",
    "codegen_type": "CPP",
    "app_project_path": "$FIXT/MyProj/MyProj_MyApp",
    "sdk_app_completed_at": "2026-04-23T00:00:00Z"
  }
}
JSON
set +e
OUT_C="$(bash "$SCRIPT" --dry-run 2>&1)"
EXIT_C=$?
set -e
assert "Case C exits 0"                               '[[ $EXIT_C -eq 0 ]]'
assert "Case C emits USER_ROOT="                      '[[ "$OUT_C" == *USER_ROOT=* ]]'
assert "Case C emits PROJECT_NAME=MyProj"             '[[ "$OUT_C" == *PROJECT_NAME=MyProj* ]]'
assert "Case C emits WORKSPACE="                      '[[ "$OUT_C" == *WORKSPACE=* ]]'
assert "Case C emits FSP_PATH="                       '[[ "$OUT_C" == *FSP_PATH=* ]]'
assert "Case C emits APP_PROJECT_PATH="               '[[ "$OUT_C" == *APP_PROJECT_PATH=* ]]'
assert "Case C emits container app path /workspace/"  '[[ "$OUT_C" == *APP_PROJECT_PATH_CONTAINER=/workspace/MyProj/MyProj_MyApp* ]]'
assert "Case C emits CONFIG_PROP="                    '[[ "$OUT_C" == *CONFIG_PROP=* ]]'
assert "Case C emits CONTEXT_FILE="                   '[[ "$OUT_C" == *CONTEXT_FILE=* ]]'
assert "Case C docker cmd uses UPDATE_SDK_APP"        '[[ "$OUT_C" == *FD_OPERATION=UPDATE_SDK_APP* ]]'
assert "Case C codegen_type=CPP (from context)"       '[[ "$OUT_C" == *codegen_type=CPP* ]]'

# ─── Case D: invoked from nested subdir ───────────────────────────────────
echo "=== Case D: invoked from nested subdir ==="
mkdir -p "$FIXT/deep/nest"
cd "$FIXT/deep/nest"
set +e
OUT_D="$(bash "$SCRIPT" --dry-run 2>&1)"
EXIT_D=$?
set -e
cd "$FIXT"
assert "Case D exits 0 (upward .mcp.json search)" '[[ $EXIT_D -eq 0 ]]'
assert "Case D USER_ROOT resolves to fixture"     '[[ "$OUT_D" == *USER_ROOT=*$(basename "$FIXT")* ]]'

# ─── Case E: build-config-prop backward compat (no --app-project-path) ─────
echo "=== Case E: build-config-prop backward compat ==="
OUT_CFG="$(bash "$BUILD_CFG" --project-name X --app-project-name Y --codegen-type JAVA --output /dev/stdout 2>/dev/null || true)"
assert "Case E GENERATE mode has no app.project.path line"        '[[ "$OUT_CFG" != *app.project.path=* ]]'
OUT_CFG_U="$(bash "$BUILD_CFG" --project-name X --app-project-name Y --codegen-type JAVA --app-project-path /workspace/X/X_Y --output /dev/stdout 2>/dev/null || true)"
assert "Case E UPDATE mode has app.project.path=/workspace/X/X_Y" '[[ "$OUT_CFG_U" == *app.project.path=/workspace/X/X_Y* ]]'

echo ""
echo "=== smoke: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "=== smoke OK ==="
