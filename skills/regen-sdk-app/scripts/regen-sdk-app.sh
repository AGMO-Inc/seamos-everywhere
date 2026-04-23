#!/bin/bash
# regen-sdk-app.sh — Re-run FD Headless UPDATE_SDK_APP on an existing workspace.
#
# Refreshes the generated SDK hooks + skeleton wiring in an existing app project
# while preserving the user's hand-written code. Reads context from
# $USER_ROOT/.seamos-context.json (written by create-project Stage 1B).
#
# Usage:
#   regen-sdk-app.sh [flags]
#
# Flags:
#   --project-name NAME         FSP project (overrides context.last_project.name)
#   --app-project-name NAME     App project (overrides context)
#   --codegen-type JAVA|CPP     (overrides context; defaults to JAVA if neither)
#   --app-project-path PATH     Host path to existing app project (overrides
#                               context; required if context missing)
#   --process-timer DUR         app.process.timer (default from context or 1s)
#   --mvn-args STR              Extra Maven args (default from context or empty)
#   --image-tag TAG             Docker image (default: seamos-fd-headless:latest)
#   --dry-run                   Print resolved paths + docker cmd, do not run
#   --help                      Show this help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── find_user_root (mirror create-project) ────────────────────────────────
find_user_root() {
  local dir
  dir="$(pwd -P)"
  while true; do
    if [[ -f "$dir/.mcp.json" ]]; then
      echo "$dir"; return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  if [[ "${SEAMOS_ALLOW_PWD_FALLBACK:-0}" == "1" ]]; then
    echo "WARN: no .mcp.json found upward from \$PWD — using \$PWD (test fallback)" >&2
    pwd -P; return 0
  fi
  echo "ERROR: no .mcp.json found upward from \$PWD" >&2
  echo "       regen-sdk-app requires a USER_ROOT marked by .mcp.json." >&2
  echo "       Run \`touch .mcp.json\` in your project root or cd there." >&2
  return 64
}

# ─── acquire_context_lock (flock → mkdir fallback) ─────────────────────────
acquire_context_lock() {
  local target="$1"
  local fd=9
  if command -v flock >/dev/null 2>&1; then
    # shellcheck disable=SC3013
    exec {fd}>"${target}.lock"
    flock -x "$fd"
    return 0
  fi
  local lockdir="${target}.lock.d"
  local tries=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries + 1))
    if (( tries > 300 )); then
      echo "ERROR: lock timeout on $lockdir" >&2
      return 1
    fi
    sleep 0.1
  done
  # Auto-release on script exit
  # shellcheck disable=SC2064
  trap "rmdir '$lockdir' 2>/dev/null || true" EXIT
  return 0
}

# ─── Arg parsing ───────────────────────────────────────────────────────────
usage() {
  sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

PROJECT_NAME=""
APP_PROJECT_NAME=""
CODEGEN_TYPE=""
APP_PROJECT_PATH=""   # host path
PROCESS_TIMER=""
MVN_ARGS=""
IMAGE_TAG="seamos-fd-headless:latest"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)      PROJECT_NAME="${2:-}"; shift 2 ;;
    --app-project-name)  APP_PROJECT_NAME="${2:-}"; shift 2 ;;
    --codegen-type)      CODEGEN_TYPE="${2:-}"; shift 2 ;;
    --app-project-path)  APP_PROJECT_PATH="${2:-}"; shift 2 ;;
    --process-timer)     PROCESS_TIMER="${2:-}"; shift 2 ;;
    --mvn-args)          MVN_ARGS="${2:-}"; shift 2 ;;
    --image-tag)         IMAGE_TAG="${2:-}"; shift 2 ;;
    --dry-run)           DRY_RUN=1; shift ;;
    --help|-h)           usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

# ─── Resolve USER_ROOT + context ───────────────────────────────────────────
USER_ROOT="$(find_user_root)"
CONTEXT_FILE="$USER_ROOT/.seamos-context.json"

if [[ ! -f "$CONTEXT_FILE" ]]; then
  echo "ERROR: context file not found: $CONTEXT_FILE" >&2
  echo "       UPDATE_SDK_APP requires an existing project — run create-project first." >&2
  exit 64
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 64
fi

# Helper: context lookup with empty-on-missing
ctx() { jq -r "$1 // empty" "$CONTEXT_FILE"; }

# Flag > context > fallback/error
PROJECT_NAME="${PROJECT_NAME:-$(ctx '.last_project.name')}"
APP_PROJECT_NAME="${APP_PROJECT_NAME:-$(ctx '.last_project.app_project_name')}"
CODEGEN_TYPE="${CODEGEN_TYPE:-$(ctx '.last_project.codegen_type')}"
APP_PROJECT_PATH="${APP_PROJECT_PATH:-$(ctx '.last_project.app_project_path')}"
PROCESS_TIMER="${PROCESS_TIMER:-$(ctx '.last_project.process_timer')}"
MVN_ARGS="${MVN_ARGS:-$(ctx '.last_project.mvn_args')}"
WORKSPACE="$(ctx '.last_project.workspace_path')"

# Apply silent defaults for truly optional fields
[[ -z "$CODEGEN_TYPE"   ]] && CODEGEN_TYPE="JAVA"
[[ -z "$PROCESS_TIMER"  ]] && PROCESS_TIMER="1s"
[[ -z "$APP_PROJECT_NAME" ]] && APP_PROJECT_NAME="$PROJECT_NAME"

# Hard-required fields (no silent defaults — surface the error)
MISSING=()
[[ -z "$PROJECT_NAME"     ]] && MISSING+=("PROJECT_NAME (--project-name or context.last_project.name)")
[[ -z "$WORKSPACE"        ]] && MISSING+=("WORKSPACE (context.last_project.workspace_path)")
[[ -z "$APP_PROJECT_PATH" ]] && MISSING+=("APP_PROJECT_PATH (--app-project-path or context.last_project.app_project_path)")

if (( ${#MISSING[@]} > 0 )); then
  echo "ERROR: missing required parameters for UPDATE_SDK_APP:" >&2
  for m in "${MISSING[@]}"; do
    echo "  - $m" >&2
  done
  echo >&2
  echo "Fix:" >&2
  echo "  1. Run \`create-project\` (including Stage 1B) to populate context, OR" >&2
  echo "  2. Pass the missing fields as CLI flags." >&2
  exit 64
fi

case "$CODEGEN_TYPE" in
  JAVA|CPP) ;;
  *) echo "ERROR: --codegen-type must be JAVA or CPP (got: $CODEGEN_TYPE)" >&2; exit 64 ;;
esac

# ─── Derived paths ─────────────────────────────────────────────────────────
FSP_PATH="$WORKSPACE/$PROJECT_NAME/com.bosch.fsp.$PROJECT_NAME"
# Container-internal path written into config.prop. Bosch's UPDATE_SDK_APP
# requires this path relative to FD_WORKSPACE (mounted as /workspace).
APP_PROJECT_PATH_CONTAINER="/workspace/$PROJECT_NAME/${PROJECT_NAME}_${APP_PROJECT_NAME}"
CONFIG_PROP="$WORKSPACE/_config.prop"
LOG="$WORKSPACE/run-sdk-app-update.log"

# Resolve timeout binary (macOS users installing coreutils get gtimeout)
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN=gtimeout
else
  echo "ERROR: neither 'timeout' nor 'gtimeout' found. Install coreutils." >&2
  exit 64
fi

DOCKER_CMD=(
  "$TIMEOUT_BIN" 600
  docker run --rm --platform linux/amd64
  -v "${WORKSPACE}:/workspace"
  -e FD_WORKSPACE=/workspace
  -e FD_OPERATION=UPDATE_SDK_APP
  -e FD_CONFIG_PROP=/workspace/_config.prop
  "$IMAGE_TAG"
)

# ─── Dry-run output ────────────────────────────────────────────────────────
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] USER_ROOT=$USER_ROOT"
  echo "[dry-run] PROJECT_NAME=$PROJECT_NAME"
  echo "[dry-run] APP_PROJECT_NAME=$APP_PROJECT_NAME"
  echo "[dry-run] WORKSPACE=$WORKSPACE"
  echo "[dry-run] FSP_PATH=$FSP_PATH"
  echo "[dry-run] APP_PROJECT_PATH=$APP_PROJECT_PATH"
  echo "[dry-run] APP_PROJECT_PATH_CONTAINER=$APP_PROJECT_PATH_CONTAINER"
  echo "[dry-run] CONFIG_PROP=$CONFIG_PROP"
  echo "[dry-run] CONTEXT_FILE=$CONTEXT_FILE"
  echo "[dry-run] operation=UPDATE_SDK_APP codegen_type=$CODEGEN_TYPE image=$IMAGE_TAG"
  echo "[dry-run] docker cmd: ${DOCKER_CMD[*]}"
  exit 0
fi

# ─── Pre-flight: workspace + FSP must already exist ────────────────────────
if [[ ! -d "$WORKSPACE" ]]; then
  echo "ERROR: workspace does not exist: $WORKSPACE" >&2
  echo "       Run create-project first." >&2
  exit 64
fi
if [[ ! -d "$FSP_PATH" ]]; then
  echo "ERROR: FSP project not found: $FSP_PATH" >&2
  echo "       The FSP must already be current. If interface.json changed," >&2
  echo "       run \`create-project --force-clean\` first to regenerate the FSP." >&2
  exit 64
fi

# ─── Write config.prop (delegates to shared helper) ─────────────────────────
BUILD_CONFIG="$SCRIPT_DIR/../../create-project/scripts/build-config-prop.sh"
if [[ ! -x "$BUILD_CONFIG" ]]; then
  echo "ERROR: build-config-prop.sh not found or not executable at $BUILD_CONFIG" >&2
  exit 1
fi

bash "$BUILD_CONFIG" \
  --project-name      "$PROJECT_NAME" \
  --app-project-name  "$APP_PROJECT_NAME" \
  --codegen-type      "$CODEGEN_TYPE" \
  --process-timer     "$PROCESS_TIMER" \
  --mvn-args          "$MVN_ARGS" \
  --app-project-path  "$APP_PROJECT_PATH_CONTAINER" \
  --output            "$CONFIG_PROP"

# ─── ensure_image ──────────────────────────────────────────────────────────
ensure_image() {
  local tag="$1"
  if docker image inspect "$tag" >/dev/null 2>&1; then
    echo "[image] using local: $tag" >&2
    return 0
  fi
  echo "[image] not found locally, attempting pull: $tag" >&2
  if docker pull --platform linux/amd64 "$tag"; then
    return 0
  fi
  echo "WARN: docker pull failed for $tag. Re-checking local cache..." >&2
  if docker image inspect "$tag" >/dev/null 2>&1; then
    return 0
  fi
  echo "ERROR: image not available locally and pull failed: $tag" >&2
  return 69
}
ensure_image "$IMAGE_TAG" || exit 69

# ─── Run UPDATE_SDK_APP ────────────────────────────────────────────────────
set +e
"${DOCKER_CMD[@]}" 2>&1 | tee "$LOG"
RUN_STATUS=${PIPESTATUS[0]}
set -e

if [[ $RUN_STATUS -eq 124 ]]; then
  echo "ERROR: UPDATE_SDK_APP run timed out after 600s" >&2
  exit 3
fi

if grep -qF "FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY" "$LOG"; then
  FINAL=0
elif grep -qF "FD HEADLESS EXECUTION EXITED WITH ERRORS" "$LOG"; then
  FINAL=1
else
  FINAL=2
fi

if [[ $FINAL -ne 0 ]]; then
  echo "[regen-sdk-app] UPDATE_SDK_APP failed (exit $FINAL) — see $LOG" >&2
  exit "$FINAL"
fi

# ─── Context upsert on success ─────────────────────────────────────────────
UPDATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PAYLOAD=$(jq -n \
  --arg operation "UPDATE_SDK_APP" \
  --arg sdk_app_updated_at "$UPDATED_AT" \
  '{operation:$operation, sdk_app_updated_at:$sdk_app_updated_at}')

(
  acquire_context_lock "$CONTEXT_FILE" || { echo "ERROR: failed to acquire context lock" >&2; exit 1; }
  TMP="${CONTEXT_FILE}.tmp.$$"
  jq --argjson p "$PAYLOAD" 'if .last_project then (.last_project += $p) else (.last_project = $p) end' "$CONTEXT_FILE" > "$TMP"
  mv "$TMP" "$CONTEXT_FILE"
)

echo "[regen-sdk-app] UPDATE_SDK_APP succeeded"
echo "[regen-sdk-app] context updated: operation=UPDATE_SDK_APP sdk_app_updated_at=$UPDATED_AT"
exit 0
