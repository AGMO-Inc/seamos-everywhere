#!/bin/bash
# create-project.sh — Orchestrate FD Headless Docker run to create a SeamOS project.
# TODO D.1 (args) + D.2 (image) + D.3 (run) + D.4 (context).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: create-project.sh [options]

Options:
  --project-name <name>         Project name (required)
  --interface-json <path>       Path to fd_user_selected_interface.json
                                (if omitted, the skill drives interactive synthesis)
  --workspace <path>            Workspace dir (default: create-project-workspace/<project-name>)
  --operation <OP>              FD operation: GENERATE_FSP | GENERATE_SDK_APP | UPDATE_SDK_APP
                                (default: GENERATE_FSP)
  --image-tag <tag>             Docker image tag
                                (default: public.ecr.aws/<alias>/seamos-fd-headless:latest)
  --dry-run                     Print the assembled docker command and exit (no run)
  --force-clean                 Remove existing workspace before running (mutually exclusive with --resume)
  --resume                      Keep existing workspace (mutually exclusive with --force-clean)
  --help                        Show this help

Exit codes:
  0   success (FD reported SUCCESS string)
  1   FD reported errors (EXITED WITH ERRORS string)
  2   unknown outcome (neither success nor failure string found)
  3   timeout (FD run exceeded 600s)
  64  invalid arguments
  69  image unavailable
EOF
}

# ── 0. Parse args ────────────────────────────────────────────────────────────
PROJECT_NAME=""
INTERFACE_JSON=""
WORKSPACE=""
OPERATION="GENERATE_FSP"
IMAGE_TAG="public.ecr.aws/<alias>/seamos-fd-headless:latest"
DRY_RUN=0
FORCE_CLEAN=0
RESUME=0

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 64
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)  PROJECT_NAME="${2:-}"; shift 2 ;;
    --interface-json) INTERFACE_JSON="${2:-}"; shift 2 ;;
    --workspace)     WORKSPACE="${2:-}"; shift 2 ;;
    --operation)     OPERATION="${2:-}"; shift 2 ;;
    --image-tag)     IMAGE_TAG="${2:-}"; shift 2 ;;
    --dry-run)       DRY_RUN=1; shift ;;
    --force-clean)   FORCE_CLEAN=1; shift ;;
    --resume)        RESUME=1; shift ;;
    --help|-h)       usage; exit 0 ;;
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

case "$OPERATION" in
  GENERATE_FSP|GENERATE_SDK_APP|UPDATE_SDK_APP) ;;
  *) echo "ERROR: invalid --operation: $OPERATION (allowed: GENERATE_FSP, GENERATE_SDK_APP, UPDATE_SDK_APP)" >&2; exit 64 ;;
esac

[[ -z "$WORKSPACE" ]] && WORKSPACE="${REPO_ROOT}/create-project-workspace/${PROJECT_NAME}"

# ── 1. Preflight ─────────────────────────────────────────────────────────────
PREFLIGHT="${SCRIPT_DIR}/preflight.sh"
if [[ -x "$PREFLIGHT" ]]; then
  bash "$PREFLIGHT" --check-only >&2 || { echo "ERROR: preflight failed — fix host environment and retry." >&2; exit 1; }
else
  echo "WARN: preflight.sh not found or not executable at $PREFLIGHT" >&2
fi

# ── 2. TIMEOUT_BIN discovery ─────────────────────────────────────────────────
TIMEOUT_BIN="$(command -v gtimeout || command -v timeout || true)"
if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "ERROR: neither gtimeout nor timeout found (preflight should have caught this)" >&2
  exit 1
fi

# ── 3. Workspace existence gate ──────────────────────────────────────────────
if [[ -e "$WORKSPACE" ]]; then
  if [[ $FORCE_CLEAN -eq 1 ]]; then
    echo "[workspace] --force-clean: removing $WORKSPACE"
    rm -rf "$WORKSPACE"
  elif [[ $RESUME -eq 1 ]]; then
    echo "[workspace] --resume: reusing $WORKSPACE"
  else
    echo "ERROR: Workspace already exists: $WORKSPACE" >&2
    echo "Use --force-clean to recreate or --resume to continue." >&2
    exit 1
  fi
fi
mkdir -p "$WORKSPACE"

# ── 4. Interface JSON handling ───────────────────────────────────────────────
WS_IFACE="${WORKSPACE}/_interface.json"
if [[ -n "$INTERFACE_JSON" ]]; then
  [[ -r "$INTERFACE_JSON" ]] || { echo "ERROR: --interface-json not readable: $INTERFACE_JSON" >&2; exit 1; }
  cp "$INTERFACE_JSON" "$WS_IFACE"

  # ── 4a. Validator gate
  VALIDATOR="${SCRIPT_DIR}/validate-interface-json.sh"
  OFFLINEDB="${REPO_ROOT}/ref/00_HeadlessFD/offlineDB.json"
  if [[ -x "$VALIDATOR" && -r "$OFFLINEDB" ]]; then
    bash "$VALIDATOR" "$WS_IFACE" "$OFFLINEDB" \
      || { echo "ERROR: interface JSON validation failed — docker run skipped." >&2; exit 1; }
  else
    echo "WARN: validator or offlineDB.json missing — skipping preflight validation." >&2
  fi
else
  echo "NOTE: --interface-json not provided. The skill's Claude flow should synthesize $WS_IFACE interactively before invoking this script." >&2
  [[ $DRY_RUN -eq 0 ]] && { echo "ERROR: interface JSON is required for non-dry-run execution." >&2; exit 1; }
fi

# ── 5. Assemble docker command ───────────────────────────────────────────────
ABS_WS="$(cd "$WORKSPACE" && pwd)"
DOCKER_CMD=(
  "$TIMEOUT_BIN" 600
  docker run --rm --platform linux/amd64
  -v "${ABS_WS}:/workspace"
  -e FD_WORKSPACE=/workspace
  -e FD_INTERFACE_JSON=/workspace/_interface.json
  -e FD_PROJECT_NAME="$PROJECT_NAME"
  -e FD_UI_TYPE="Custom UI"
  -e FD_OPERATION="$OPERATION"
  "$IMAGE_TAG"
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] ${DOCKER_CMD[*]}"
  echo "[dry-run] project=$PROJECT_NAME operation=$OPERATION workspace=$ABS_WS image=$IMAGE_TAG"
  exit 0
fi

# ── 6. ensure_image — pull if missing ────────────────────────────────────────
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

# ── 7. Run FD with tee ───────────────────────────────────────────────────────
LOG="${ABS_WS}/run.log"
set +e
"${DOCKER_CMD[@]}" 2>&1 | tee "$LOG"
RUN_STATUS=${PIPESTATUS[0]}
set -e

# ── 8. Result grep (success/failure/unknown/timeout) ─────────────────────────
if [[ $RUN_STATUS -eq 124 ]]; then
  echo "ERROR: FD run timed out after 600s" >&2
  exit 3
fi

if grep -qF "FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY" "$LOG"; then
  FINAL=0
elif grep -qF "FD HEADLESS EXECUTION EXITED WITH ERRORS" "$LOG"; then
  FINAL=1
else
  FINAL=2
fi

# ── 9. Update .seamos-context.json (atomic + flock) ─────────────────────────
if [[ $FINAL -eq 0 ]]; then
  CONTEXT_FILE="${REPO_ROOT}/.seamos-context.json"
  LOCK_FILE="${CONTEXT_FILE}.lock"
  [[ ! -f "$CONTEXT_FILE" ]] && echo '{}' > "$CONTEXT_FILE"

  IFACE_SHA=""
  if command -v shasum >/dev/null 2>&1; then
    IFACE_SHA=$(shasum -a 256 "$WS_IFACE" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    IFACE_SHA=$(sha256sum "$WS_IFACE" | awk '{print $1}')
  fi
  CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  PAYLOAD=$(jq -n \
    --arg name "$PROJECT_NAME" \
    --arg workspace_path "$ABS_WS" \
    --arg operation "$OPERATION" \
    --arg image_tag "$IMAGE_TAG" \
    --arg interface_json_sha256 "$IFACE_SHA" \
    --arg created_at "$CREATED_AT" \
    '{name:$name, workspace_path:$workspace_path, operation:$operation, image_tag:$image_tag, interface_json_sha256:$interface_json_sha256, created_at:$created_at}')

  # flock for cross-invocation mutual exclusion
  (
    if command -v flock >/dev/null 2>&1; then
      flock 9
    fi
    TMP="${CONTEXT_FILE}.tmp.$$"
    jq --argjson p "$PAYLOAD" '. + {last_project: $p}' "$CONTEXT_FILE" > "$TMP"
    mv "$TMP" "$CONTEXT_FILE"
  ) 9>"$LOCK_FILE"
fi

exit "$FINAL"
