#!/bin/bash
# create-project.sh — Orchestrate FD Headless Docker run to generate FSP (+ optional SDK/APP skeleton)
# for a SeamOS project. Handles Stage 1A (GENERATE_FSP), Stage 1B (GENERATE_SDK_APP),
# and Stage 1C (seamos-assets/ bootstrap) in a single invocation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Default FD image tag. Maintainers push new builds to :latest.
# Override with --image-tag (or SEAMOS_FD_IMAGE env) for reproducibility or local dev.
readonly FD_IMAGE_PINNED_TAG="public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest"

# ─── Shared utility functions ──────────────────────────────────────────────

# find_user_root — walk up from $PWD looking for .mcp.json (v4 CIMP-1)
find_user_root() {
  local dir
  dir="$(pwd -P)"
  while true; do
    if [[ -f "$dir/.mcp.json" ]]; then
      echo "$dir"
      return 0
    fi
    if [[ "$dir" == "/" ]]; then
      break
    fi
    dir="$(dirname "$dir")"
  done
  if [[ "${SEAMOS_ALLOW_PWD_FALLBACK:-0}" == "1" ]]; then
    echo "WARN: no .mcp.json found from $PWD upward — using \$PWD as USER_ROOT (SEAMOS_ALLOW_PWD_FALLBACK=1)" >&2
    pwd -P
    return 0
  fi
  echo "ERROR: no .mcp.json found from $PWD upward — run inside a project that has .mcp.json at its root" >&2
  return 64
}

# detect_legacy_layout — warn about deprecated create-project-workspace/ directory
detect_legacy_layout() {
  local user_root="$1"
  if [[ -d "$user_root/create-project-workspace" ]]; then
    echo "WARN: legacy create-project-workspace detected at $user_root/create-project-workspace — this layout is deprecated; new projects go directly under \$USER_ROOT/<PROJECT_NAME>/" >&2
  fi
}

# acquire_context_lock — flock preferred, mkdir-based fallback (v4 CIMP-2)
acquire_context_lock() {
  local ctx="$1"
  local lock_dir="${ctx}.lock.d"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"${ctx}.lock"
    flock -x -w 30 9 || return 1
    return 0
  fi
  local waited=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    if (( waited >= 30 )); then
      return 1
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
  trap "rmdir '$lock_dir' 2>/dev/null || true" EXIT
  return 0
}

# Resolve offlineDB.json: env > bundle assets > repo fallback
resolve_offlinedb() {
  if [[ -n "${SEAMOS_OFFLINEDB_PATH:-}" && -f "${SEAMOS_OFFLINEDB_PATH}" ]]; then
    echo "${SEAMOS_OFFLINEDB_PATH}"; return 0
  fi
  local skill_root
  skill_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
  if [[ -f "${skill_root}/assets/offlineDB.json" ]]; then
    echo "${skill_root}/assets/offlineDB.json"; return 0
  fi
  if [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/ref/00_HeadlessFD/offlineDB.json" ]]; then
    echo "${REPO_ROOT}/ref/00_HeadlessFD/offlineDB.json"; return 0
  fi
  return 1
}

usage() {
  cat <<EOF
Usage: create-project.sh [options]

Options:
  --project-name <name>         Project name (required)
  --interface-json <path>       Path to fd_user_selected_interface.json
                                (promoted to \$USER_ROOT/<name>-interface.json SSOT)
  --workspace <path>            Workspace dir (default: \$USER_ROOT/<project-name>)
  --skip-sdk-app                Skip Stage 1B (generate FSP only)
  --codegen-type JAVA|CPP       Code generation type for Stage 1B
                                (required for Stage 1B; prompted interactively when a TTY is available)
  --app-project-name <name>     App project name (default: same as --project-name)
  --process-timer <duration>    app.process.timer value (default: 1s)
  --mvn-args <string>           Maven extra args (default: empty)
  --operation <OP>              (advanced) FD operation override — GENERATE_FSP |
                                GENERATE_SDK_APP | UPDATE_SDK_APP. Prefer --skip-sdk-app
  --image-tag <tag>             Docker image tag (default: ${FD_IMAGE_PINNED_TAG})
  --dry-run                     Print assembled commands and path variables, exit 0
  --force-clean                 Remove existing workspace (preserves seamos-assets/ and SSOT).
                                Refuses to run when the app project folder is non-empty
                                unless --i-know-this-deletes-app-code is also passed.
  --i-know-this-deletes-app-code
                                Acknowledge that --force-clean will delete user-written
                                app code under <workspace>/<PROJECT>/<PROJECT>_<APP>/.
                                Required guard for --force-clean over a non-empty app project.
  --regen-fsp-only              Re-run Stage 1A (GENERATE_FSP) only. Deletes only the FSP
                                folder (com.bosch.fsp.<PROJECT>/) and preserves the app
                                project folder. Use this when the interface JSON changed
                                and the SDK/skeleton needs to be refreshed via regen-sdk-app
                                without losing user code. Mutually exclusive with
                                --force-clean / --resume / --skip-sdk-app.
  --resume                      Reuse existing workspace; resume from last stage
  --help                        Show this help

USER_ROOT is the directory containing .mcp.json (walked up from \$PWD).
seamos-assets/, .seamos-context.json, and <PROJECT>-interface.json all live at USER_ROOT.

Exit codes:
  0   success
  1   FD reported errors / state mismatch
  2   malformed .gitignore sentinel (CIMP-2) / unknown FD outcome
  3   timeout (FD run exceeded 600s)
  64  invalid arguments / missing context
  69  image unavailable
EOF
}

# ─── Parse args ─────────────────────────────────────────────────────────────
PROJECT_NAME=""
INTERFACE_JSON=""
WORKSPACE=""
SKIP_SDK_APP=0
CODEGEN_TYPE=""
APP_PROJECT_NAME=""
PROCESS_TIMER="1s"
MVN_ARGS=""
OPERATION=""
IMAGE_TAG="$FD_IMAGE_PINNED_TAG"
DRY_RUN=0
FORCE_CLEAN=0
RESUME=0
REGEN_FSP_ONLY=0
ACK_DELETES_APP_CODE=0

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 64
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)      PROJECT_NAME="${2:-}"; shift 2 ;;
    --interface-json)    INTERFACE_JSON="${2:-}"; shift 2 ;;
    --workspace)         WORKSPACE="${2:-}"; shift 2 ;;
    --skip-sdk-app)      SKIP_SDK_APP=1; shift ;;
    --codegen-type)      CODEGEN_TYPE="${2:-}"; shift 2 ;;
    --app-project-name)  APP_PROJECT_NAME="${2:-}"; shift 2 ;;
    --process-timer)     PROCESS_TIMER="${2:-}"; shift 2 ;;
    --mvn-args)          MVN_ARGS="${2:-}"; shift 2 ;;
    --operation)         OPERATION="${2:-}"; shift 2 ;;
    --image-tag)         IMAGE_TAG="${2:-}"; shift 2 ;;
    --dry-run)           DRY_RUN=1; shift ;;
    --force-clean)       FORCE_CLEAN=1; shift ;;
    --regen-fsp-only)    REGEN_FSP_ONLY=1; shift ;;
    --i-know-this-deletes-app-code) ACK_DELETES_APP_CODE=1; shift ;;
    --resume)            RESUME=1; shift ;;
    --help|-h)           usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: --project-name is required" >&2
  usage >&2
  exit 64
fi

if [[ $FORCE_CLEAN -eq 1 && $RESUME -eq 1 ]]; then
  echo "ERROR: --force-clean and --resume are mutually exclusive" >&2
  exit 64
fi

# --regen-fsp-only is mutually exclusive with the other workspace-state flags.
# Allowing combinations is dangerous: regen-fsp-only deliberately preserves the
# app project, while force-clean deletes it; mixing them silently loses code.
if [[ $REGEN_FSP_ONLY -eq 1 ]]; then
  if [[ $FORCE_CLEAN -eq 1 ]]; then
    echo "ERROR: --regen-fsp-only and --force-clean are mutually exclusive" >&2
    exit 64
  fi
  if [[ $RESUME -eq 1 ]]; then
    echo "ERROR: --regen-fsp-only and --resume are mutually exclusive" >&2
    exit 64
  fi
  if [[ $SKIP_SDK_APP -eq 1 ]]; then
    echo "ERROR: --regen-fsp-only already implies skipping Stage 1B; do not pass --skip-sdk-app" >&2
    exit 64
  fi
fi

# --operation vs --skip-sdk-app policy (v2 I10)
# --skip-sdk-app is the public flag; --operation is advanced/hidden
if [[ -n "$OPERATION" && $SKIP_SDK_APP -eq 1 && "$OPERATION" != "GENERATE_FSP" ]]; then
  echo "WARN: --operation=$OPERATION specified together with --skip-sdk-app; --operation takes precedence" >&2
fi

# Derive effective operation mode. Default: GENERATE_FSP for Stage 1A; 1B runs unless SKIP_SDK_APP.
if [[ -z "$OPERATION" ]]; then
  OPERATION="GENERATE_FSP"
fi
case "$OPERATION" in
  GENERATE_FSP|GENERATE_SDK_APP|UPDATE_SDK_APP) ;;
  *) echo "ERROR: invalid --operation: $OPERATION (allowed: GENERATE_FSP, GENERATE_SDK_APP, UPDATE_SDK_APP)" >&2; exit 64 ;;
esac

# Normalize + validate CODEGEN_TYPE (if user specified)
if [[ -n "$CODEGEN_TYPE" ]]; then
  CODEGEN_TYPE="$(echo "$CODEGEN_TYPE" | tr '[:lower:]' '[:upper:]')"
  case "$CODEGEN_TYPE" in
    JAVA|CPP) ;;
    *) echo "ERROR: --codegen-type must be JAVA or CPP (got: $CODEGEN_TYPE)" >&2; exit 64 ;;
  esac
fi

[[ -z "$APP_PROJECT_NAME" ]] && APP_PROJECT_NAME="$PROJECT_NAME"

# ─── Resolve USER_ROOT (v4 CIMP-1) ─────────────────────────────────────────
USER_ROOT="$(find_user_root)" || exit 64
USER_ROOT="$(cd "$USER_ROOT" && pwd -P)"

detect_legacy_layout "$USER_ROOT"

# REPO_ROOT legacy context detection (v3 IMP-1)
if [[ "$REPO_ROOT" != "$USER_ROOT" && -f "$REPO_ROOT/.seamos-context.json" ]]; then
  echo "WARN: legacy context detected at $REPO_ROOT/.seamos-context.json — this is no longer read; canonical location is $USER_ROOT/.seamos-context.json" >&2
fi

# Default workspace path + SSOT path + context path (all USER_ROOT-relative)
[[ -z "$WORKSPACE" ]] && WORKSPACE="${USER_ROOT}/${PROJECT_NAME}"
SSOT_PATH="${USER_ROOT}/${PROJECT_NAME}-interface.json"
CONTEXT_FILE="${USER_ROOT}/.seamos-context.json"

# ─── Path normalization (v2 I8) ────────────────────────────────────────────
# Canonicalize a path that may not exist yet, resolving symlinks for the
# deepest existing ancestor (handles /tmp → /private/tmp on macOS).
normalize_path() {
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
    return
  fi
  if command -v realpath >/dev/null 2>&1 && realpath -m "$p" >/dev/null 2>&1; then
    realpath -m "$p"
    return
  fi
  # Fallback: canonicalize the deepest existing parent, then append the tail.
  local parent="$p" tail=""
  while [[ -n "$parent" && ! -d "$parent" ]]; do
    tail="/$(basename "$parent")$tail"
    local next
    next="$(dirname "$parent")"
    if [[ "$next" == "$parent" ]]; then
      parent=""
      break
    fi
    parent="$next"
  done
  if [[ -n "$parent" ]]; then
    local parent_real
    parent_real="$(cd "$parent" && pwd -P)"
    echo "${parent_real}${tail}"
  else
    echo "$p"
  fi
}
ABS_WS="$(normalize_path "$WORKSPACE")"

# Defense: WORKSPACE must be inside USER_ROOT and not equal to USER_ROOT
if [[ "$ABS_WS" == "$USER_ROOT" ]]; then
  echo "ERROR: --workspace cannot equal USER_ROOT ($USER_ROOT) — pick a subdirectory" >&2
  exit 64
fi
case "$ABS_WS" in
  "$USER_ROOT"/*) ;;
  *)
    echo "ERROR: --workspace ($ABS_WS) must be inside USER_ROOT ($USER_ROOT)" >&2
    exit 64
    ;;
esac

# ─── Preflight (skipped in --dry-run) ───────────────────────────────────────
PREFLIGHT="${SCRIPT_DIR}/preflight.sh"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ -x "$PREFLIGHT" ]]; then
    bash "$PREFLIGHT" --check-only >&2 \
      || { echo "ERROR: preflight failed — fix host environment and retry." >&2; exit 1; }
  else
    echo "WARN: preflight.sh not found or not executable at $PREFLIGHT" >&2
  fi
fi

# v4 CIMP-2: preflight info — lock fallback availability
if ! command -v flock >/dev/null 2>&1; then
  echo "WARN: flock not found; using mkdir-based lock fallback" >&2
fi

TIMEOUT_BIN="$(command -v gtimeout || command -v timeout || true)"
if [[ -z "$TIMEOUT_BIN" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    TIMEOUT_BIN="timeout"  # placeholder for dry-run output only
  else
    echo "ERROR: neither gtimeout nor timeout found (preflight should have caught this)" >&2
    exit 1
  fi
fi

# ─── Resume state matrix (v2 C4) ───────────────────────────────────────────
WS_EXISTS=0
if [[ -d "$ABS_WS" && -n "$(ls -A "$ABS_WS" 2>/dev/null)" ]]; then
  WS_EXISTS=1
fi

FSP_COMPLETED_AT=""
SDK_APP_COMPLETED_AT=""
if [[ -f "$CONTEXT_FILE" ]]; then
  FSP_COMPLETED_AT="$(jq -r '.last_project.fsp_completed_at // empty' "$CONTEXT_FILE" 2>/dev/null || true)"
  SDK_APP_COMPLETED_AT="$(jq -r '.last_project.sdk_app_completed_at // empty' "$CONTEXT_FILE" 2>/dev/null || true)"
fi

RUN_STAGE_1A=1
RUN_STAGE_1B=1

# Path of the app project that holds user-written code. Both --force-clean's
# guard and --regen-fsp-only's preserve-list need this resolved before either
# branch runs.
APP_PROJECT_DIR="${ABS_WS}/${PROJECT_NAME}/${PROJECT_NAME}_${APP_PROJECT_NAME}"
FSP_DIR="${ABS_WS}/${PROJECT_NAME}/com.bosch.fsp.${PROJECT_NAME}"

# Returns 0 when the path is a non-empty directory (any entry, including dotfiles).
app_project_has_code() {
  [[ -d "$1" ]] || return 1
  [[ -n "$(ls -A "$1" 2>/dev/null)" ]]
}

if [[ $REGEN_FSP_ONLY -eq 1 ]]; then
  # Refresh only the FSP folder. Leaves the app project (user code) and the
  # rest of the workspace untouched. Stage 1B is skipped — call regen-sdk-app
  # afterwards to merge new SDK hooks into the preserved app project.
  if [[ ! -d "$ABS_WS" ]]; then
    echo "ERROR: --regen-fsp-only requires an existing workspace at $ABS_WS — run create-project first" >&2
    exit 64
  fi
  if [[ -d "$FSP_DIR" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[workspace] --regen-fsp-only [dry-run]: would remove $FSP_DIR (would preserve app project at $APP_PROJECT_DIR)"
    else
      echo "[workspace] --regen-fsp-only: removing FSP folder $FSP_DIR (preserving app project at $APP_PROJECT_DIR)"
      rm -rf "$FSP_DIR"
    fi
  else
    echo "[workspace] --regen-fsp-only: no existing FSP folder at $FSP_DIR — will generate fresh"
  fi
  RUN_STAGE_1A=1
  RUN_STAGE_1B=0
  WS_EXISTS=1
elif [[ $FORCE_CLEAN -eq 1 ]]; then
  # Guardrail: --force-clean wipes the workspace, which includes the app
  # project. Refuse to do so silently when the app project has user code,
  # unless the caller explicitly acknowledges the loss.
  if app_project_has_code "$APP_PROJECT_DIR" && [[ $ACK_DELETES_APP_CODE -ne 1 ]]; then
    echo "ERROR: --force-clean would delete user-written app code at:" >&2
    echo "         $APP_PROJECT_DIR" >&2
    echo "       Pass --i-know-this-deletes-app-code to confirm, OR use --regen-fsp-only" >&2
    echo "       to refresh the FSP without touching the app project." >&2
    exit 64
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[workspace] --force-clean [dry-run]: would remove $ABS_WS (would preserve seamos-assets/ and SSOT)"
  else
    echo "[workspace] --force-clean: removing $ABS_WS (preserving seamos-assets/ and SSOT)"
    # Preserve: USER_ROOT/seamos-assets/, USER_ROOT/<PROJECT>-interface.json, USER_ROOT/.seamos-context.json
    if [[ -d "$ABS_WS" ]]; then
      rm -rf "$ABS_WS"
    fi
  fi
  WS_EXISTS=0
else
  # Matrix interpretation:
  #   (exist, fsp, sdk) → already_complete (state 1)
  #   (exist, fsp, _)   → resume Stage 1B only (state 2)
  #   (exist, _, _)     → context missing (state 3), error
  #   (!exist, fsp|sdk, _) with --resume → state mismatch (states 4, 5)
  #   (!exist, _, _)    → normal (state 6)
  if [[ $WS_EXISTS -eq 1 ]]; then
    if [[ -n "$FSP_COMPLETED_AT" && -n "$SDK_APP_COMPLETED_AT" ]]; then
      echo "[resume] already complete for $PROJECT_NAME — workspace at $ABS_WS. Use --force-clean to recreate." >&2
      exit 0
    elif [[ -n "$FSP_COMPLETED_AT" ]]; then
      echo "[resume] Stage 1B (SDK/APP resume) — FSP already complete at $ABS_WS" >&2
      RUN_STAGE_1A=0
    else
      echo "ERROR: workspace exists at $ABS_WS but context missing — workspace may be stale. Use --force-clean 으로 초기화 후 재실행." >&2
      exit 64
    fi
  else
    if [[ $RESUME -eq 1 && ( -n "$FSP_COMPLETED_AT" || -n "$SDK_APP_COMPLETED_AT" ) ]]; then
      echo "ERROR: state mismatch — context indicates completion but workspace missing at $ABS_WS. Use --force-clean 으로 초기화 후 재실행." >&2
      exit 1
    fi
  fi
fi

# Honor --operation override (advanced)
if [[ "$OPERATION" == "GENERATE_SDK_APP" || "$OPERATION" == "UPDATE_SDK_APP" ]]; then
  RUN_STAGE_1A=0
  RUN_STAGE_1B=1
fi
if [[ $SKIP_SDK_APP -eq 1 || "$OPERATION" == "GENERATE_FSP" ]]; then
  if [[ $SKIP_SDK_APP -eq 1 ]]; then
    RUN_STAGE_1B=0
  fi
fi
# Explicit --operation GENERATE_FSP without --skip-sdk-app is also FSP-only
if [[ -n "${OPERATION:-}" && "$OPERATION" == "GENERATE_FSP" && $SKIP_SDK_APP -eq 0 && $# -ge 0 ]]; then
  : # default: still run 1B unless SKIP_SDK_APP is set
fi
# If user explicitly set --operation GENERATE_FSP with intent of FSP-only,
# treat the same as --skip-sdk-app for Stage 1B determination.
# This is the canonical alias mapping (I10).
for arg in "$@"; do :; done  # no-op placeholder (original args already consumed)

# Validate --interface-json readability BEFORE dry-run output
WS_IFACE="${ABS_WS}/_interface.json"
if [[ -n "$INTERFACE_JSON" ]]; then
  [[ -r "$INTERFACE_JSON" ]] || { echo "ERROR: --interface-json not readable: $INTERFACE_JSON" >&2; exit 1; }
fi

# For non-dry-run or when missing sources, warn about interface requirements
if [[ -z "$INTERFACE_JSON" && ! -f "$SSOT_PATH" && ! -f "$WS_IFACE" ]]; then
  echo "NOTE: --interface-json not provided and no SSOT present. The skill's Claude flow should synthesize $WS_IFACE (and $SSOT_PATH) interactively before invoking this script." >&2
  if [[ $DRY_RUN -eq 0 && $RUN_STAGE_1A -eq 1 ]]; then
    echo "ERROR: interface JSON is required for Stage 1A execution." >&2
    exit 1
  fi
fi

# ─── Stage 1A / 1B docker commands ─────────────────────────────────────────
# Docker mount invariant (v2 C2):
#   host ${ABS_WS}:/workspace  ⇒  container-internal fd.project.path=/workspace/${PROJECT_NAME}/com.bosch.fsp.${PROJECT_NAME}
#   → host output at ${ABS_WS}/${PROJECT_NAME}/com.bosch.fsp.${PROJECT_NAME}/ (FD Eclipse workspace auto depth)
DOCKER_CMD_1A=(
  "$TIMEOUT_BIN" 600
  docker run --rm --platform linux/amd64
  -v "${ABS_WS}:/workspace"
  -e FD_WORKSPACE=/workspace
  -e FD_INTERFACE_JSON=/workspace/_interface.json
  -e FD_PROJECT_NAME="$PROJECT_NAME"
  -e FD_UI_TYPE="Custom UI"
  -e FD_OPERATION="GENERATE_FSP"
  "$IMAGE_TAG"
)

# Stage 1B config (v2 I6: app_project_path format)
BUILD_CONFIG="${SCRIPT_DIR}/build-config-prop.sh"
CONFIG_PROP="${ABS_WS}/_config.prop"
SDK_LOG="${ABS_WS}/run-sdk-app.log"
APP_PROJECT_PATH="${ABS_WS}/${PROJECT_NAME}/${PROJECT_NAME}_${APP_PROJECT_NAME}"

DOCKER_CMD_1B=(
  "$TIMEOUT_BIN" 600
  docker run --rm --platform linux/amd64
  -v "${ABS_WS}:/workspace"
  -e FD_WORKSPACE=/workspace
  -e FD_OPERATION=GENERATE_SDK_APP
  -e FD_CONFIG_PROP=/workspace/_config.prop
  "$IMAGE_TAG"
)

# Auto-detect codegen.type from an existing app project (regen-fsp-only or
# resume scenarios). CPP is the team-wide default; JAVA is only chosen when an
# explicit Maven project is detected. Detection happens before the interactive
# prompt so the resolved value is offered as the default.
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

if [[ -z "$CODEGEN_TYPE" ]]; then
  if DETECTED="$(detect_codegen_from_app "$APP_PROJECT_DIR")"; then
    echo "[codegen] auto-detected codegen.type=$DETECTED from $APP_PROJECT_DIR" >&2
    CODEGEN_TYPE="$DETECTED"
  elif [[ -f "$CONTEXT_FILE" ]]; then
    CTX_CODEGEN="$(jq -r '.last_project.codegen_type // empty' "$CONTEXT_FILE" 2>/dev/null || true)"
    if [[ -n "$CTX_CODEGEN" ]]; then
      echo "[codegen] using codegen.type=$CTX_CODEGEN from .seamos-context.json" >&2
      CODEGEN_TYPE="$CTX_CODEGEN"
    fi
  fi
fi

# Resolve CODEGEN_TYPE for Stage 1B if still unresolved.
# Fail closed when invoked without a TTY (e.g., by an LLM agent) so the caller is
# forced to surface the choice to the user instead of silently defaulting.
# Default is CPP — the team-wide convention for SeamOS apps.
if [[ $RUN_STAGE_1B -eq 1 && -z "$CODEGEN_TYPE" ]]; then
  if [[ -t 0 && $DRY_RUN -eq 0 ]]; then
    read -r -p "Select codegen.type [CPP/JAVA] (default: CPP): " CODEGEN_TYPE_INPUT
    CODEGEN_TYPE="${CODEGEN_TYPE_INPUT:-CPP}"
    CODEGEN_TYPE="$(echo "$CODEGEN_TYPE" | tr '[:lower:]' '[:upper:]')"
  else
    echo "ERROR: --codegen-type is required when running non-interactively (no TTY)." >&2
    echo "       Pass --codegen-type CPP or --codegen-type JAVA explicitly." >&2
    echo "       (If you are an LLM agent, ask the user which codegen type they want before invoking.)" >&2
    exit 64
  fi
fi

# ─── Dry-run output (v4 CIMP-4: expose key paths) ──────────────────────────
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] USER_ROOT=$USER_ROOT"
  echo "[dry-run] PROJECT_NAME=$PROJECT_NAME"
  echo "[dry-run] WORKSPACE=$ABS_WS"
  echo "[dry-run] FSP_PATH=${ABS_WS}/${PROJECT_NAME}/com.bosch.fsp.${PROJECT_NAME}"
  echo "[dry-run] BUILD_DIR=${USER_ROOT}/seamos-assets/builds"
  echo "[dry-run] CONTEXT_FILE=$CONTEXT_FILE"
  echo "[dry-run] SSOT_PATH=$SSOT_PATH"
  echo "[dry-run] operation=$OPERATION skip_sdk_app=$SKIP_SDK_APP force_clean=$FORCE_CLEAN resume=$RESUME regen_fsp_only=$REGEN_FSP_ONLY ack_deletes_app_code=$ACK_DELETES_APP_CODE"
  echo "[dry-run] APP_PROJECT_DIR=$APP_PROJECT_DIR FSP_DIR=$FSP_DIR"
  if [[ $RUN_STAGE_1A -eq 1 ]]; then
    echo "[dry-run] Stage 1A GENERATE_FSP: ${DOCKER_CMD_1A[*]}"
  fi
  if [[ $RUN_STAGE_1B -eq 1 ]]; then
    echo "[dry-run] Stage 1B GENERATE_SDK_APP: ${DOCKER_CMD_1B[*]}"
    echo "[dry-run] Stage 1B _config.prop=$CONFIG_PROP app_project_path=$APP_PROJECT_PATH codegen_type=$CODEGEN_TYPE"
  fi
  exit 0
fi

# ─── Beyond this point: disk-mutating operations (skipped during --dry-run) ──
mkdir -p "$ABS_WS"

# ─── Interface JSON handling with SSOT policy (TODO 31, v3 IMP-2) ──────────
if [[ -n "$INTERFACE_JSON" ]]; then
  # Explicit --interface-json: promote to SSOT first, then copy to workspace
  cp "$INTERFACE_JSON" "$SSOT_PATH"
  cp "$SSOT_PATH" "$WS_IFACE"
elif [[ -f "$SSOT_PATH" ]]; then
  # SSOT master policy — if SSOT and workspace differ, SSOT wins
  if [[ -f "$WS_IFACE" ]]; then
    if ! cmp -s "$SSOT_PATH" "$WS_IFACE"; then
      echo "[interface] SSOT master — overwriting workspace copy with $SSOT_PATH" >&2
      cp "$SSOT_PATH" "$WS_IFACE"
    fi
  else
    cp "$SSOT_PATH" "$WS_IFACE"
  fi
elif [[ -f "$WS_IFACE" ]]; then
  # workspace-only: promote to SSOT with warning (case d)
  echo "WARN: workspace _interface.json exists without SSOT — promoting to SSOT at $SSOT_PATH" >&2
  cp "$WS_IFACE" "$SSOT_PATH"
fi

# Validator gate
if [[ -f "$WS_IFACE" ]]; then
  VALIDATOR="${SCRIPT_DIR}/validate-interface-json.sh"
  OFFLINEDB="$(resolve_offlinedb || true)"
  if [[ -x "$VALIDATOR" && -n "$OFFLINEDB" ]]; then
    bash "$VALIDATOR" "$WS_IFACE" "$OFFLINEDB" \
      || { echo "ERROR: interface JSON validation failed — docker run skipped." >&2; exit 1; }
  else
    echo "WARN: validator or offlineDB.json missing — skipping preflight validation." >&2
  fi
fi

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

# ─── Run Stage 1A (GENERATE_FSP) ────────────────────────────────────────────
LOG="${ABS_WS}/run.log"
FINAL_1A=0
if [[ $RUN_STAGE_1A -eq 1 ]]; then
  set +e
  "${DOCKER_CMD_1A[@]}" 2>&1 | tee "$LOG"
  RUN_STATUS=${PIPESTATUS[0]}
  set -e
  if [[ $RUN_STATUS -eq 124 ]]; then
    echo "ERROR: FSP run timed out after 600s" >&2
    exit 3
  fi
  if grep -qF "FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY" "$LOG"; then
    FINAL_1A=0
  elif grep -qF "FD HEADLESS EXECUTION EXITED WITH ERRORS" "$LOG"; then
    FINAL_1A=1
  else
    FINAL_1A=2
  fi
fi

if [[ $FINAL_1A -ne 0 ]]; then
  echo "[create-project] FSP stage failed (exit $FINAL_1A) — skipping SDK/APP stage" >&2
  exit "$FINAL_1A"
fi

# ─── Context upsert — Stage 1A completion (TODO 3: merge + fsp_completed_at) ─
[[ ! -f "$CONTEXT_FILE" ]] && echo '{}' > "$CONTEXT_FILE"

IFACE_SHA=""
if [[ -f "$WS_IFACE" ]]; then
  if command -v shasum >/dev/null 2>&1; then
    IFACE_SHA=$(shasum -a 256 "$WS_IFACE" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    IFACE_SHA=$(sha256sum "$WS_IFACE" | awk '{print $1}')
  fi
fi
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

FSP_PAYLOAD=$(jq -n \
  --arg name "$PROJECT_NAME" \
  --arg workspace_path "$ABS_WS" \
  --arg operation "GENERATE_FSP" \
  --arg image_tag "$IMAGE_TAG" \
  --arg interface_json_sha256 "$IFACE_SHA" \
  --arg created_at "$CREATED_AT" \
  --arg fsp_completed_at "$CREATED_AT" \
  '{name:$name, workspace_path:$workspace_path, operation:$operation, image_tag:$image_tag, interface_json_sha256:$interface_json_sha256, created_at:$created_at, fsp_completed_at:$fsp_completed_at}')

(
  acquire_context_lock "$CONTEXT_FILE" || { echo "ERROR: failed to acquire context lock" >&2; exit 1; }
  TMP="${CONTEXT_FILE}.tmp.$$"
  # Merge (preserve existing fields, e.g. sdk_app_completed_at from prior run)
  jq --argjson p "$FSP_PAYLOAD" 'if .last_project then (.last_project += $p) else (.last_project = $p) end' "$CONTEXT_FILE" > "$TMP"
  mv "$TMP" "$CONTEXT_FILE"
)

# ─── Run Stage 1B (GENERATE_SDK_APP) ───────────────────────────────────────
FINAL_1B=0
if [[ $RUN_STAGE_1B -eq 1 ]]; then
  if [[ ! -x "$BUILD_CONFIG" ]]; then
    echo "ERROR: build-config-prop.sh not found or not executable at $BUILD_CONFIG" >&2
    exit 1
  fi
  bash "$BUILD_CONFIG" \
    --project-name     "$PROJECT_NAME" \
    --app-project-name "$APP_PROJECT_NAME" \
    --codegen-type     "$CODEGEN_TYPE" \
    --process-timer    "$PROCESS_TIMER" \
    --mvn-args         "$MVN_ARGS" \
    --output           "$CONFIG_PROP"

  set +e
  "${DOCKER_CMD_1B[@]}" 2>&1 | tee "$SDK_LOG"
  RUN_STATUS=${PIPESTATUS[0]}
  set -e
  if [[ $RUN_STATUS -eq 124 ]]; then
    echo "ERROR: SDK/APP run timed out after 600s" >&2
    exit 3
  fi
  if grep -qF "FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY" "$SDK_LOG"; then
    FINAL_1B=0
  elif grep -qF "FD HEADLESS EXECUTION EXITED WITH ERRORS" "$SDK_LOG"; then
    FINAL_1B=1
  else
    FINAL_1B=2
  fi

  if [[ $FINAL_1B -eq 0 ]]; then
    SDK_COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    SDK_PAYLOAD=$(jq -n \
      --arg operation "GENERATE_SDK_APP" \
      --arg app_project_name "$APP_PROJECT_NAME" \
      --arg codegen_type "$CODEGEN_TYPE" \
      --arg app_project_path "$APP_PROJECT_PATH" \
      --arg sdk_app_completed_at "$SDK_COMPLETED_AT" \
      '{operation:$operation, app_project_name:$app_project_name, codegen_type:$codegen_type, app_project_path:$app_project_path, sdk_app_completed_at:$sdk_app_completed_at}')
    (
      acquire_context_lock "$CONTEXT_FILE" || { echo "ERROR: failed to acquire context lock" >&2; exit 1; }
      TMP="${CONTEXT_FILE}.tmp.$$"
      jq --argjson p "$SDK_PAYLOAD" 'if .last_project then (.last_project += $p) else (.last_project = $p) end' "$CONTEXT_FILE" > "$TMP"
      mv "$TMP" "$CONTEXT_FILE"
    )
    echo "[create-project] SDK/APP SUCCESS — skeleton at: $APP_PROJECT_PATH" >&2
  fi
fi

FINAL=0
if [[ $FINAL_1B -ne 0 ]]; then
  FINAL=$FINAL_1B
fi

# ─── Stage 1C: seamos-assets/ bootstrap (TODO 8, idempotent) ───────────────
if [[ $FINAL -eq 0 ]]; then
  if [[ ! -d "$USER_ROOT/seamos-assets" ]]; then
    mkdir -p "$USER_ROOT/seamos-assets/builds" "$USER_ROOT/seamos-assets/screenshots"
    echo "[create-project] bootstrapped seamos-assets/ at $USER_ROOT/seamos-assets" >&2
  fi
fi

# ─── .gitignore auto-append with sentinel pair validation (TODO 9, v4 CIMP-2) ─
if [[ $FINAL -eq 0 ]]; then
  GITIGNORE="$USER_ROOT/.gitignore"
  [[ ! -f "$GITIGNORE" ]] && touch "$GITIGNORE"

  BEGIN_CNT=$(grep -c "^# BEGIN seamos-create-project:${PROJECT_NAME}$" "$GITIGNORE" 2>/dev/null || true)
  END_CNT=$(grep -c "^# END seamos-create-project:${PROJECT_NAME}$" "$GITIGNORE" 2>/dev/null || true)
  BEGIN_CNT=${BEGIN_CNT:-0}
  END_CNT=${END_CNT:-0}

  if [[ ( $BEGIN_CNT -eq 0 && $END_CNT -eq 0 ) || ( $BEGIN_CNT -eq 1 && $END_CNT -eq 1 ) ]]; then
    if [[ $BEGIN_CNT -eq 1 ]]; then
      TMP="${GITIGNORE}.tmp.$$"
      sed "/^# BEGIN seamos-create-project:${PROJECT_NAME}\$/,/^# END seamos-create-project:${PROJECT_NAME}\$/d" "$GITIGNORE" > "$TMP"
      mv "$TMP" "$GITIGNORE"
    fi
    {
      echo "# BEGIN seamos-create-project:${PROJECT_NAME}"
      echo "${PROJECT_NAME}/_interface.json"
      echo "${PROJECT_NAME}/_config.prop"
      echo "${PROJECT_NAME}/IDT_OFFLINE_DATA/"
      echo "${PROJECT_NAME}/run*.log"
      echo "${PROJECT_NAME}/${PROJECT_NAME}/com.bosch.fsp.*/"
      echo "# END seamos-create-project:${PROJECT_NAME}"
    } >> "$GITIGNORE"
  else
    echo "ERROR: .gitignore has malformed sentinel for ${PROJECT_NAME} (BEGIN=${BEGIN_CNT}, END=${END_CNT}) — manual repair required / 수동 수리 요구" >&2
    exit 2
  fi
fi

exit "$FINAL"
