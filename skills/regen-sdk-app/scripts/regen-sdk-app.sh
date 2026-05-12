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
#   --codegen-type JAVA|CPP     (overrides context; otherwise auto-detected from
#                               the existing app project's build files —
#                               CMakeLists.txt → CPP, pom.xml → JAVA — falling
#                               back to CPP if neither is present)
#   --app-project-path PATH     Host path to existing app project (overrides
#                               context; required if context missing)
#   --process-timer DUR         app.process.timer (default from context or 1s)
#   --mvn-args STR              Extra Maven args (default from context or empty)
#   --image-tag TAG             Docker image (default: seamos-fd-headless:latest)
#   --reset-tests               Delete <PROJECT>/com.bosch.fsp.<PROJECT>.gen.tests/
#                               before UPDATE_SDK_APP so FD regenerates the
#                               simulator scaffold (SDKTest.java, sample data,
#                               Manifest.xml). Required when interfaces changed
#                               (e.g. new plugin added). Refuses to run if user
#                               files are detected; pass --i-know-this-deletes-test-code
#                               to override.
#   --i-know-this-deletes-test-code  Acknowledge that --reset-tests removes any
#                                     hand-written code under .gen.tests/ .
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
RESET_TESTS=0
ACK_DELETES_TESTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)      PROJECT_NAME="${2:-}"; shift 2 ;;
    --app-project-name)  APP_PROJECT_NAME="${2:-}"; shift 2 ;;
    --codegen-type)      CODEGEN_TYPE="${2:-}"; shift 2 ;;
    --app-project-path)  APP_PROJECT_PATH="${2:-}"; shift 2 ;;
    --process-timer)     PROCESS_TIMER="${2:-}"; shift 2 ;;
    --mvn-args)          MVN_ARGS="${2:-}"; shift 2 ;;
    --image-tag)         IMAGE_TAG="${2:-}"; shift 2 ;;
    --reset-tests)       RESET_TESTS=1; shift ;;
    --i-know-this-deletes-test-code)
                         ACK_DELETES_TESTS=1; shift ;;
    --dry-run)           DRY_RUN=1; shift ;;
    --help|-h)           usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

# ─── Resolve USER_ROOT + context ───────────────────────────────────────────
USER_ROOT="$(find_user_root)"
CONTEXT_FILE="$USER_ROOT/.seamos-context.json"
RESOLVE_PATHS="$SCRIPT_DIR/../../shared-references/scripts/resolve-paths.sh"

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

# Auto-detect codegen.type from the existing app project's build files when
# neither the flag nor context provided one. CPP is the team-wide default; JAVA
# is detected only when an explicit Maven project is present.
detect_codegen_from_app() {
  local app_dir="$1"
  [[ -d "$app_dir" ]] || return 1
  if [[ -f "$app_dir/CMakeLists.txt" ]]; then
    echo "CPP"; return 0
  fi
  if [[ -f "$app_dir/pom.xml" ]]; then
    echo "JAVA"; return 0
  fi
  return 1
}

if [[ -z "$CODEGEN_TYPE" && -n "$APP_PROJECT_PATH" ]]; then
  if DETECTED="$(detect_codegen_from_app "$APP_PROJECT_PATH")"; then
    echo "[regen-sdk-app] auto-detected codegen.type=$DETECTED from $APP_PROJECT_PATH" >&2
    CODEGEN_TYPE="$DETECTED"
  fi
fi

# Apply silent defaults for truly optional fields
[[ -z "$CODEGEN_TYPE"   ]] && CODEGEN_TYPE="CPP"
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

# ─── Derived paths (delegated to resolve-paths helper) ─────────────────────
# Helper is layout-aware (nested vs flat) and SSOT for FSP_PATH,
# APP_PROJECT_PATH_CONTAINER, FSP_PATH_CONTAINER, and MOUNT_ROOT — the four
# values that previously hardcoded a nested-layout assumption.
if [[ ! -x "$RESOLVE_PATHS" ]]; then
  echo "ERROR: resolve-paths.sh not found or not executable at $RESOLVE_PATHS" >&2
  exit 1
fi
RESOLVED="$(bash "$RESOLVE_PATHS" "$USER_ROOT")" || {
  echo "ERROR: resolve-paths.sh failed for USER_ROOT=$USER_ROOT" >&2
  exit 1
}
FSP_PATH="$(printf '%s\n' "$RESOLVED" | grep '^FSP_PATH=' | head -1 | cut -d= -f2-)"
APP_PROJECT_PATH_CONTAINER="$(printf '%s\n' "$RESOLVED" | grep '^APP_PROJECT_PATH_CONTAINER=' | head -1 | cut -d= -f2-)"
MOUNT_ROOT="$(printf '%s\n' "$RESOLVED" | grep '^MOUNT_ROOT=' | head -1 | cut -d= -f2-)"
LAYOUT_KIND="$(printf '%s\n' "$RESOLVED" | grep '^LAYOUT_KIND=' | head -1 | cut -d= -f2-)"
# Layout-B (flat) advisory guard — this skill is for plugin create-project
# (nested) artifacts. seamos-IDE (flat) projects should regen inside the IDE.
# WARN-only; do not abort. nested / unknown / unset → silent.
if [[ "${LAYOUT_KIND:-}" == "flat" ]]; then
  echo "[WARN] Layout B (flat) 감지 — 이 스킬은 plugin create-project (nested) 산출물 전용입니다. seamos-IDE 산출물에서는 동작이 보장되지 않을 수 있습니다. IDE 안에서 실행하는 것을 권장합니다." >&2
fi
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
  -v "${MOUNT_ROOT}:/workspace"
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
  echo "[dry-run] MOUNT_ROOT=$MOUNT_ROOT"
  echo "[dry-run] FSP_PATH=$FSP_PATH"
  echo "[dry-run] APP_PROJECT_PATH=$APP_PROJECT_PATH"
  echo "[dry-run] APP_PROJECT_PATH_CONTAINER=$APP_PROJECT_PATH_CONTAINER"
  echo "[dry-run] CONFIG_PROP=$CONFIG_PROP"
  echo "[dry-run] CONTEXT_FILE=$CONTEXT_FILE"
  echo "[dry-run] operation=UPDATE_SDK_APP codegen_type=$CODEGEN_TYPE image=$IMAGE_TAG"
  echo "[dry-run] reset_tests=$RESET_TESTS ack_deletes_tests=$ACK_DELETES_TESTS"
  if [[ $RESET_TESTS -eq 1 ]]; then
    echo "[dry-run] would rm -rf: ${FSP_PATH}.gen.tests"
  fi
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
  echo "       run \`create-project --regen-fsp-only\` first to regenerate the FSP" >&2
  echo "       without touching your app code, then re-run regen-sdk-app." >&2
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

# ─── --reset-tests: drop FD-generated simulator scaffold so it regenerates ─
# Bosch's UPDATE_SDK_APP treats the entire .gen.tests/ tree as user-data and
# never overwrites it. After an interface change (e.g. adding GPSPlugin), the
# old SDKTest.java still hardcodes only the original providers (e.g. only
# IMUProvider) and no GPS signals are published. Deleting .gen.tests/ before
# UPDATE_SDK_APP forces FD to regenerate it from the current FSP/Manifest.
GEN_TESTS_DIR="${FSP_PATH}.gen.tests"
if [[ $RESET_TESTS -eq 1 ]]; then
  if [[ ! -d "$GEN_TESTS_DIR" ]]; then
    echo "[regen-sdk-app] --reset-tests: directory absent, nothing to delete: $GEN_TESTS_DIR" >&2
  else
    # Heuristic: any .java under src/ whose mtime is newer than .classpath
    # (which FD writes once at scaffold time) is likely user-edited.
    USER_TOUCHED=()
    if [[ -f "$GEN_TESTS_DIR/.classpath" ]]; then
      while IFS= read -r f; do
        USER_TOUCHED+=("$f")
      done < <(find "$GEN_TESTS_DIR/src" -type f -name '*.java' \
                 -newer "$GEN_TESTS_DIR/.classpath" 2>/dev/null || true)
    fi
    if (( ${#USER_TOUCHED[@]} > 0 )) && [[ $ACK_DELETES_TESTS -ne 1 ]]; then
      echo "ERROR: --reset-tests would delete files newer than .classpath under $GEN_TESTS_DIR/src/:" >&2
      printf '  %s\n' "${USER_TOUCHED[@]}" >&2
      echo >&2
      echo "If those edits are throw-away scaffolding, re-run with --i-know-this-deletes-test-code." >&2
      echo "If they're real user code, copy them out first, then re-run." >&2
      exit 64
    fi
    echo "[regen-sdk-app] --reset-tests: removing $GEN_TESTS_DIR" >&2
    rm -rf "$GEN_TESTS_DIR"
  fi
fi

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
