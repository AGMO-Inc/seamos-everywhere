#!/usr/bin/env bash
# e2e-chain-smoke.sh — End-to-end chain smoke for the three SeamOS bootstrap skills.
#
# Verifies the USER_ROOT / .seamos-workspace.json / .seamos-context.json handoff
# between setup → create-project (--dry-run) → init-customui in a single fixture.
#
# Steps:
#   0. sanity (all four required paths exist; three scripts executable)
#   1. setup real run → .seamos-workspace.json (schemaVersion=1, scope=project),
#      .mcp.json (project scope), seamos-assets/{builds,screenshots}/
#   2. create-project --dry-run from inside the fixture → resolves USER_ROOT
#      via the new .seamos-workspace.json marker (OR-marker patch)
#   3. synthesize .seamos-context.json (simulates post-create-project state)
#   4. init-customui --ui vanilla real run → ui.defaultFramework="vanilla"
#      and ui/README.md dropped under the deep app-project ui/
#   5. PASS
#
# Constraints: no network, no docker, no git clone, no npm install.
# Mutates only ${FIXTURE} under /tmp.
#
# Note on STATUS_WARN: the chain's value is the cross-skill handoff, not the
# preflight. setup.sh emits STATUS_WARN (still exit 0) when host preflight tools
# are missing — this smoke tolerates that, since the assertions check the actual
# handoff artifacts rather than the final-line STATUS token.
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
readonly SETUP="${REPO_ROOT}/skills/setup/scripts/setup.sh"
readonly CREATE_PROJECT="${REPO_ROOT}/skills/create-project/scripts/create-project.sh"
readonly INIT_CUSTOMUI="${REPO_ROOT}/skills/init-customui/scripts/init-customui.sh"
readonly INTERFACE_SAMPLE="${REPO_ROOT}/skills/create-project/references/interface-sample.json"
readonly FIXTURE="/tmp/e2e-smoke-$$"

cleanup() { rm -rf "${FIXTURE}"; }
trap cleanup EXIT

fail() { echo "[e2e-smoke] FAIL: $1" >&2; exit 1; }
pass() { echo "[e2e-smoke] PASS"; }

# ─── Step 0 — sanity ───────────────────────────────────────────────────────
[[ -x "$SETUP" ]]           || fail "setup.sh not executable at $SETUP"
[[ -x "$CREATE_PROJECT" ]]  || fail "create-project.sh not executable at $CREATE_PROJECT"
[[ -x "$INIT_CUSTOMUI" ]]   || fail "init-customui.sh not executable at $INIT_CUSTOMUI"
[[ -f "$INTERFACE_SAMPLE" ]] || fail "interface sample missing at $INTERFACE_SAMPLE"
echo "[step0] sanity OK"

# ─── Step 1 — setup real run ───────────────────────────────────────────────
mkdir -p "${FIXTURE}"
bash "$SETUP" --workspace-dir "${FIXTURE}" --endpoint dev --non-interactive >/dev/null \
  || fail "setup exited non-zero"
jq -e '.schemaVersion == 1 and .scope == "project"' "${FIXTURE}/.seamos-workspace.json" >/dev/null \
  || fail "setup did not produce expected workspace JSON"
[[ -f "${FIXTURE}/.mcp.json" ]] || fail "setup did not write .mcp.json (project scope)"
[[ -d "${FIXTURE}/seamos-assets/builds" && -d "${FIXTURE}/seamos-assets/screenshots" ]] \
  || fail "setup did not bootstrap seamos-assets/"
echo "[step1] setup OK"

# ─── Step 2 — create-project --dry-run chained off the new marker ──────────
out2="$(cd "${FIXTURE}" && bash "$CREATE_PROJECT" \
  --project-name E2E \
  --skip-sdk-app \
  --workspace "${FIXTURE}/E2E" \
  --interface-json "${INTERFACE_SAMPLE}" \
  --dry-run 2>&1)" || fail "create-project --dry-run exited non-zero"
echo "$out2" | grep -q "e2e-smoke" \
  || fail "create-project did not resolve USER_ROOT to fixture (output had no 'e2e-smoke' substring)"
echo "[step2] create-project (--dry-run) recognized .seamos-workspace.json marker OK"

# ─── Step 3 — synthesize .seamos-context.json (simulate post-create-project) ─
mkdir -p "${FIXTURE}/E2E/E2E/E2E_App/ui"
cat > "${FIXTURE}/.seamos-context.json" <<EOF
{
  "last_project": {
    "name": "E2E",
    "app_project_name": "E2E_App",
    "app_project_path": "${FIXTURE}/E2E/E2E/E2E_App"
  }
}
EOF
echo "[step3] context synthesized"

# ─── Step 4 — init-customui --ui vanilla real run ──────────────────────────
(cd "${FIXTURE}" && bash "$INIT_CUSTOMUI" --ui vanilla --non-interactive >/dev/null) \
  || fail "init-customui exited non-zero"
jq -e '.ui.defaultFramework == "vanilla"' "${FIXTURE}/.seamos-workspace.json" >/dev/null \
  || fail "init-customui did not update workspace JSON to vanilla"
[[ -f "${FIXTURE}/E2E/E2E/E2E_App/ui/README.md" ]] \
  || fail "init-customui did not drop vanilla README"
echo "[step4] init-customui (vanilla) OK"

# ─── Step 5 — pass ─────────────────────────────────────────────────────────
pass
