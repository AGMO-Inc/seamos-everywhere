#!/usr/bin/env bash
# docker-once.sh — Tier 2 single real-docker execution against an F2 (flat)
# fixture copy. Optional: requires DOCKER=1 to opt in. Without the env var,
# or when no docker daemon / no cached image is available, the script skips
# cleanly (exit 0, prints a skip line) so it can live in CI alongside Tier 1.
#
# Mutates ONLY a temp copy of F2-flat-full. The git-tracked fixture is never
# touched. Artifacts (logs, generated src-gen) live under the tmp dir and
# are NOT committed.
#
# Env knobs:
#   DOCKER=1                         opt-in (required to attempt real run)
#   SEAMOS_FD_IMAGE=<tag>            override docker image (default seamos-fd-headless:latest)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Layout: <SKILLS_DIR>/shared-references/scripts/test/e2e/docker-once.sh
SHARED_REF_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
SKILLS_DIR="$(cd "$SHARED_REF_DIR/.." && pwd -P)"
FIXTURES_DIR="$SCRIPT_DIR/../resolve-paths/fixtures"
REGEN_SDK_APP_SH="$SKILLS_DIR/regen-sdk-app/scripts/regen-sdk-app.sh"

IMAGE_TAG="${SEAMOS_FD_IMAGE:-seamos-fd-headless:latest}"

skip() {
  printf 'Tier 2: skipped (%s)\n' "$1"
  exit 0
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
if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
  # Image not cached locally; do NOT attempt a pull (CI ECR access not assumed).
  skip "no docker (image $IMAGE_TAG not cached locally)"
fi

# ─── Materialize F2 tmp copy ────────────────────────────────────────────────
src_abs="$(cd "$FIXTURES_DIR/F2-flat-full" && pwd -P)"
tmp="$(mktemp -d /tmp/dockeronce-F2.XXXXXX)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

cp -R "$src_abs"/. "$tmp"/

# Rewrite materialized absolute paths in context JSON to point at the tmp copy.
for jf in "$tmp/.seamos-context.json" "$tmp/.seamos-workspace.json"; do
  if [[ -f "$jf" ]]; then
    sed -i.bak "s|$src_abs|$tmp|g" "$jf"
    rm -f "$jf.bak"
  fi
done

# Required markers/files for regen-sdk-app to succeed.
touch "$tmp/.mcp.json"
fsp="$(jq -r '.last_project.fsp_path' "$tmp/.seamos-context.json")"
app="$(jq -r '.last_project.app_project_path' "$tmp/.seamos-context.json")"
printf 'CPP_APP_PATH="cmake|%s"\n' "$(basename "$app")" > "$fsp/FDProject.props"
touch "$app/CMakeLists.txt"

# Snapshot src-gen mtime baseline (will be 0 if no src-gen yet — that's OK,
# any post-run mtime > 0 counts as growth).
src_gen_dir="$app/src-gen"
mkdir -p "$src_gen_dir"
mtime_before=$(stat -f %m "$src_gen_dir" 2>/dev/null || stat -c %Y "$src_gen_dir")

# ─── Real run ───────────────────────────────────────────────────────────────
echo "[docker-once] running regen-sdk-app.sh against $tmp (image=$IMAGE_TAG)"
set +e
out="$(cd "$tmp" && SEAMOS_FD_IMAGE="$IMAGE_TAG" bash "$REGEN_SDK_APP_SH" 2>&1)"
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  printf '%s\n' "$out" | tail -40
  echo "Tier 2: 0/1 passed (regen-sdk-app rc=$rc)"
  exit 1
fi

# ─── Post-run assertions ────────────────────────────────────────────────────
log_file="$tmp/run-sdk-app-update.log"
if [[ -f "$log_file" ]]; then
  if grep -q '^SEVERE' "$log_file" 2>/dev/null; then
    echo "[docker-once] SEVERE entries found in $log_file:"
    grep '^SEVERE' "$log_file" | head -5
    echo "Tier 2: 0/1 passed (SEVERE in log)"
    exit 1
  fi
fi

mtime_after=$(stat -f %m "$src_gen_dir" 2>/dev/null || stat -c %Y "$src_gen_dir")
if [[ "$mtime_after" -le "$mtime_before" ]]; then
  echo "[docker-once] src-gen mtime did not advance (before=$mtime_before after=$mtime_after)"
  echo "Tier 2: 0/1 passed (no src-gen activity)"
  exit 1
fi

echo "Tier 2: 1/1 passed"
exit 0
