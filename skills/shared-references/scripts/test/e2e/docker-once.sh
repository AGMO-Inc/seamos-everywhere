#!/usr/bin/env bash
# docker-once.sh — Tier 2 single real-docker e2e over the full FD Headless
# pipeline: GENERATE_FSP → GENERATE_SDK_APP → regen-sdk-app.sh (UPDATE_SDK_APP).
# Optional: requires DOCKER=1 to opt in. Without the env var, or when no docker
# daemon / no cached image is available, the script skips cleanly (exit 0,
# prints a skip line) so it can live in CI alongside Tier 1.
#
# The workspace is generated from scratch by FD itself (nested layout, exactly
# what create-project produces) — FD Headless cannot UPDATE_SDK_APP a flat
# (Layout B) workspace: Eclipse getRawLocation() is null for projects directly
# under the workspace root, so the F2-flat fixture is NOT usable here.
#
# Everything lives under a tmp dir and is removed on exit. Nothing is committed.
#
# Env knobs:
#   DOCKER=1                         opt-in (required to attempt real run)
#   SEAMOS_FD_IMAGE=<tag>            override docker image (default seamos-fd-headless:latest)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Layout: <SKILLS_DIR>/shared-references/scripts/test/e2e/docker-once.sh
SHARED_REF_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
SKILLS_DIR="$(cd "$SHARED_REF_DIR/.." && pwd -P)"
REGEN_SDK_APP_SH="$SKILLS_DIR/regen-sdk-app/scripts/regen-sdk-app.sh"
BUILD_CONFIG_SH="$SKILLS_DIR/create-project/scripts/build-config-prop.sh"
INTERFACE_JSON="$SKILLS_DIR/create-project/references/interface-sample.json"

IMAGE_TAG="${SEAMOS_FD_IMAGE:-seamos-fd-headless:latest}"
PROJECT=foo

skip() {
  printf 'Tier 2: skipped (%s)\n' "$1"
  exit 0
}

fail() {
  printf 'Tier 2: 0/1 passed (%s)\n' "$1"
  exit 1
}

# ─── Opt-in gate ────────────────────────────────────────────────────────────
if [[ "${DOCKER:-0}" != "1" ]]; then
  skip "no docker (DOCKER=1 not set)"
fi

# ─── Daemon check ──────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  skip "no docker (docker CLI not on PATH)"
fi
if ! docker info >/dev/null 2>&1; then
  skip "no docker (daemon unreachable)"
fi

# ─── Image availability check ──────────────────────────────────────────────
# `docker images -q` instead of `docker image inspect`: inspect resolves for the
# host platform and reports "No such image" for amd64-only images on arm64 hosts
# with the containerd image store, even though `docker run --platform` works.
if [[ -z "$(docker images -q "$IMAGE_TAG" 2>/dev/null)" ]]; then
  # Image not cached locally; do NOT attempt a pull (CI ECR access not assumed).
  skip "no docker (image $IMAGE_TAG not cached locally)"
fi

# ─── Tmp USER_ROOT ─────────────────────────────────────────────────────────
tmp="$(mktemp -d /tmp/dockeronce.XXXXXX)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
ws="$tmp/$PROJECT"          # FD workspace (mounted at /workspace)
mkdir -p "$ws"

# ─── Stage 1: GENERATE_FSP ─────────────────────────────────────────────────
echo "[docker-once] stage 1/3 GENERATE_FSP (image=$IMAGE_TAG)"
cp "$INTERFACE_JSON" "$ws/interface.json"
docker run --rm --platform linux/amd64 \
  -v "$ws:/workspace" \
  -e FD_WORKSPACE=/workspace \
  -e FD_OPERATION=GENERATE_FSP \
  -e FD_INTERFACE_JSON=/workspace/interface.json \
  -e FD_PROJECT_NAME="$PROJECT" \
  -e FD_UI_TYPE="Custom UI" \
  "$IMAGE_TAG" > "$tmp/generate-fsp.log" 2>&1
rc=$?
if [[ $rc -ne 0 ]] || ! grep -q "EXECUTION COMPLETED SUCCESSFULLY" "$tmp/generate-fsp.log"; then
  tail -20 "$tmp/generate-fsp.log"
  fail "GENERATE_FSP rc=$rc"
fi
fsp="$ws/$PROJECT/com.bosch.fsp.$PROJECT"
[[ -f "$fsp/Manifest.xml" ]] || fail "GENERATE_FSP produced no Manifest.xml at $fsp"

# ─── Stage 2: GENERATE_SDK_APP ─────────────────────────────────────────────
echo "[docker-once] stage 2/3 GENERATE_SDK_APP"
bash "$BUILD_CONFIG_SH" \
  --project-name "$PROJECT" --app-project-name App --codegen-type CPP \
  --output "$ws/_config.prop" >/dev/null
docker run --rm --platform linux/amd64 \
  -v "$ws:/workspace" \
  -e FD_WORKSPACE=/workspace \
  -e FD_OPERATION=GENERATE_SDK_APP \
  -e FD_CONFIG_PROP=/workspace/_config.prop \
  "$IMAGE_TAG" > "$tmp/generate-sdk-app.log" 2>&1
rc=$?
if [[ $rc -ne 0 ]] || grep -q "SEVERE" "$tmp/generate-sdk-app.log"; then
  tail -20 "$tmp/generate-sdk-app.log"
  fail "GENERATE_SDK_APP rc=$rc"
fi
app="$ws/$PROJECT/${PROJECT}_App"
sdk_zip="$ws/$PROJECT/${PROJECT}_CPP_SDK.zip"
[[ -n "$(ls -A "$app/src-gen" 2>/dev/null)" ]] || fail "GENERATE_SDK_APP produced empty $app/src-gen"
[[ -f "$sdk_zip" ]] || fail "GENERATE_SDK_APP produced no $sdk_zip"

# ─── Stage 3: regen-sdk-app.sh (UPDATE_SDK_APP) ────────────────────────────
echo "[docker-once] stage 3/3 regen-sdk-app.sh (UPDATE_SDK_APP)"
# Seed the context files create-project would have written (all fields).
cat > "$tmp/.seamos-context.json" <<EOF
{
  "last_project": {
    "name": "$PROJECT",
    "workspace_path": "$ws",
    "layout_kind": "nested",
    "fsp_path": "$fsp",
    "sdk_project_path": "$ws/$PROJECT/${PROJECT}_CPP_SDK",
    "app_project_path": "$app",
    "customui_src_path": "$ws/customui-src",
    "deep_ui_path": "$app/ui"
  }
}
EOF
cat > "$tmp/.seamos-workspace.json" <<EOF
{
  "ui": { "defaultFramework": "vanilla", "activeSrcPath": "customui-src" }
}
EOF
touch "$tmp/.mcp.json"
mkdir -p "$ws/customui-src"
# UPDATE_SDK_APP hard-fails ("App project does not contain the custom ui
# folder") when ui/ is empty — a real user project always has UI content.
mkdir -p "$app/ui"
[[ -n "$(ls -A "$app/ui")" ]] || printf '<html><body>e2e stub</body></html>\n' > "$app/ui/index.html"

sleep 1  # ensure mtime resolution between snapshot and update
zip_mtime_before=$(stat -f %m "$sdk_zip" 2>/dev/null || stat -c %Y "$sdk_zip")

set +e
out="$(cd "$tmp" && SEAMOS_FD_IMAGE="$IMAGE_TAG" bash "$REGEN_SDK_APP_SH" 2>&1)"
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  printf '%s\n' "$out" | tail -40
  fail "regen-sdk-app rc=$rc"
fi

# ─── Post-run assertions ────────────────────────────────────────────────────
log_file="$ws/run-sdk-app-update.log"
# FD SEVERE lines are timestamp-prefixed ("... INFO: / SEVERE: ..."), so match
# anywhere in the line, not just at line start.
if [[ -f "$log_file" ]] && grep -q "SEVERE" "$log_file"; then
  echo "[docker-once] SEVERE entries found in $log_file:"
  grep "SEVERE" "$log_file" | head -5
  fail "SEVERE in log"
fi

# UPDATE_SDK_APP preserves app user code (app src-gen may be byte-identical),
# but it always repackages the SDK — assert on the SDK zip advancing.
zip_mtime_after=$(stat -f %m "$sdk_zip" 2>/dev/null || stat -c %Y "$sdk_zip")
if [[ "$zip_mtime_after" -le "$zip_mtime_before" ]]; then
  echo "[docker-once] $sdk_zip mtime did not advance (before=$zip_mtime_before after=$zip_mtime_after)"
  fail "no SDK regeneration activity"
fi

echo "Tier 2: 1/1 passed"
exit 0
