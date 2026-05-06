#!/usr/bin/env bash
# smoke.sh — Docker-free smoke test for the setup skill.
# Exercises setup.sh against a temp fixture under /tmp:
#   1) sanity (script is executable)
#   2) --dry-run prints [dry-run] markers, last line STATUS_OK, no files written
#   3) real run produces a valid .seamos-workspace.json (schemaVersion=1, scope=project,
#      marketplace.endpoint=dev)
#   4) real run produces a .mcp.json with the seamos-marketplace entry (stdio + dev URL)
#   5) seamos-assets/{builds,screenshots}/ are created
#   6) idempotent re-run emits >=2 [skip] lines and STATUS_OK
#
# Constraints: no network, no docker, no git, no npm. Mutates only ${FIXTURE} under /tmp.
#
# Note on STATUS_WARN: setup.sh emits STATUS_WARN (still exit 0) when preflight tools
# (docker / jq / shasum / timeout) are missing on the host. This smoke ONLY accepts
# STATUS_OK as success — that is intentional. If the host is missing preflight tools
# the smoke is allowed to FAIL; that is a valid environmental signal, not a script bug.
# Remedy on macOS: prepend `/Applications/Docker.app/Contents/Resources/bin` to PATH
# (and ensure jq is installed via `brew install jq`) and re-run.
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
readonly SETUP="${REPO_ROOT}/skills/setup/scripts/setup.sh"
readonly FIXTURE="/tmp/setup-smoke-$$"

cleanup() { rm -rf "${FIXTURE}"; }
trap cleanup EXIT

fail() { echo "[smoke] FAIL: $1" >&2; exit 1; }
pass() { echo "[smoke] PASS"; }

# 1. Sanity
[[ -x "$SETUP" ]] || fail "setup.sh not executable at $SETUP"

# 2. Dry-run STATUS_OK
mkdir -p "${FIXTURE}/dry"
out="$(bash "$SETUP" --workspace-dir "${FIXTURE}/dry" --endpoint dev --non-interactive --dry-run)"
echo "$out" | tail -n1 | grep -q '^STATUS_OK$' || fail "dry-run last line not STATUS_OK"
echo "$out" | grep -q '\[dry-run\]' || fail "dry-run did not emit [dry-run] marker"
[[ ! -f "${FIXTURE}/dry/.seamos-workspace.json" ]] || fail "dry-run actually wrote workspace file"

# 3. Real run produces valid workspace JSON with schemaVersion=1
mkdir -p "${FIXTURE}/real"
bash "$SETUP" --workspace-dir "${FIXTURE}/real" --endpoint dev --non-interactive >/dev/null
jq -e '.schemaVersion == 1 and .scope == "project" and .marketplace.endpoint == "dev"' \
  "${FIXTURE}/real/.seamos-workspace.json" >/dev/null || fail "workspace JSON shape wrong"

# 4. Real run wrote .mcp.json with seamos-marketplace + stdio
jq -e '.mcpServers."seamos-marketplace".type == "stdio"' "${FIXTURE}/real/.mcp.json" >/dev/null \
  || fail ".mcp.json shape wrong"
grep -q "https://dev.marketplace-api.seamos.io/mcp" "${FIXTURE}/real/.mcp.json" \
  || fail "dev URL missing from .mcp.json"

# 5. seamos-assets/ created
[[ -d "${FIXTURE}/real/seamos-assets/builds" ]] || fail "builds/ missing"
[[ -d "${FIXTURE}/real/seamos-assets/screenshots" ]] || fail "screenshots/ missing"

# 6. Idempotent re-run emits [skip]
out2="$(bash "$SETUP" --workspace-dir "${FIXTURE}/real" --endpoint dev --non-interactive)"
skips="$(printf '%s\n' "$out2" | grep -c '\[skip\]')"
[[ "$skips" -ge 2 ]] || fail "idempotent re-run produced only ${skips} [skip] line(s) (expected >=2)"
echo "$out2" | tail -n1 | grep -q '^STATUS_OK$' || fail "idempotent re-run last line not STATUS_OK"

pass
