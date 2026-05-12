#!/usr/bin/env bash
# resolve-paths.sh — Resolve all SeamOS project paths (FSP / SDK / APP / UI /
# workspace / mount + container counterparts) for a given USER_ROOT.
#
# Strategy (read-only):
#   1. If <USER_ROOT>/.seamos-context.json has all 5 normalized fields under
#      last_project (fsp_path, sdk_project_path, app_project_path,
#      customui_src_path, deep_ui_path), use them verbatim.
#   2. If 1+ field is missing → WARN to stderr, fall back to disk inference for
#      ALL 5 fields (all-or-nothing).
#   3. If context file is absent → WARN to stderr, infer from disk.
#   4. Disk inference cannot determine layout → exit 2.
#
# Output: KEY=VALUE lines on stdout (10 keys). Diagnostics on stderr.
# Never writes to .seamos-context.json or .seamos-workspace.json.
#
# Compatible with bash 3.2 (macOS default). Requires: jq.
set -uo pipefail

# --- arg parsing -----------------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "ERROR: usage: resolve-paths.sh <USER_ROOT>" >&2
  exit 64
fi

USER_ROOT_INPUT="$1"
if [[ ! -d "$USER_ROOT_INPUT" ]]; then
  echo "ERROR: USER_ROOT does not exist or is not a directory: $USER_ROOT_INPUT" >&2
  exit 64
fi

USER_ROOT="$(cd "$USER_ROOT_INPUT" && pwd -P)"

# --- dependency check ------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 65
fi

# --- helpers ---------------------------------------------------------------

CTX_FILE="$USER_ROOT/.seamos-context.json"
WS_FILE="$USER_ROOT/.seamos-workspace.json"

# Normalize an existing absolute path through pwd -P (resolves symlinks like
# /tmp -> /private/tmp on macOS). Falls back to the original on failure.
normalize_path() {
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
  elif [[ -f "$p" ]]; then
    local d b
    d="$(dirname "$p")"
    b="$(basename "$p")"
    if [[ -d "$d" ]]; then
      echo "$(cd "$d" && pwd -P)/$b"
    else
      echo "$p"
    fi
  else
    # Path does not exist (yet) — try to normalize the deepest existing ancestor
    local cur="$p" tail=""
    while [[ "$cur" != "/" && ! -d "$cur" ]]; do
      tail="$(basename "$cur")${tail:+/$tail}"
      cur="$(dirname "$cur")"
    done
    if [[ -d "$cur" ]]; then
      local base
      base="$(cd "$cur" && pwd -P)"
      if [[ -n "$tail" ]]; then
        echo "$base/$tail"
      else
        echo "$base"
      fi
    else
      echo "$p"
    fi
  fi
}

# Extract <P> from a com.bosch.fsp.<P> directory name.
fsp_to_project_name() {
  local dir="$1"
  local base
  base="$(basename "$dir")"
  echo "${base#com.bosch.fsp.}"
}

# Find the first com.bosch.fsp.* directory under USER_ROOT (depth 1 or 2 only).
# Echoes the absolute path to stdout, or empty if none.
find_fsp_dir() {
  local found
  found="$(find "$USER_ROOT" -maxdepth 3 -type d -name 'com.bosch.fsp.*' 2>/dev/null | head -1)"
  if [[ -n "$found" ]]; then
    normalize_path "$found"
  fi
}

# --- context read ----------------------------------------------------------

# Read raw values from context. Sets globals CTX_* (empty if missing/unparseable).
CTX_FSP=""
CTX_SDK=""
CTX_APP=""
CTX_CUI=""
CTX_DEEP=""
CTX_WS=""
CTX_LAYOUT=""
CTX_NAME=""
CTX_PRESENT=0

read_context() {
  if [[ ! -f "$CTX_FILE" ]]; then
    return 0
  fi
  CTX_PRESENT=1
  CTX_FSP="$(jq -r '.last_project.fsp_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_SDK="$(jq -r '.last_project.sdk_project_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_APP="$(jq -r '.last_project.app_project_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_CUI="$(jq -r '.last_project.customui_src_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_DEEP="$(jq -r '.last_project.deep_ui_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_WS="$(jq -r '.last_project.workspace_path // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_LAYOUT="$(jq -r '.last_project.layout_kind // ""' "$CTX_FILE" 2>/dev/null)"
  CTX_NAME="$(jq -r '.last_project.name // ""' "$CTX_FILE" 2>/dev/null)"
  # jq prints "null" -> "" via // "" already; treat literal "null" defensively
  for v in CTX_FSP CTX_SDK CTX_APP CTX_DEEP CTX_WS CTX_LAYOUT CTX_NAME; do
    eval "[[ \"\${$v}\" == \"null\" ]] && $v=\"\""
  done
  # customui_src_path may legitimately be JSON null (vanilla mode)
  [[ "$CTX_CUI" == "null" ]] && CTX_CUI=""
}

# Returns 0 if all 5 normalized fields are present (non-empty).
# customui_src_path is allowed to be empty/null (vanilla mode) — we only require
# the other 4 to be non-empty, plus customui_src_path to be present in the JSON
# (either a string or explicit null). For simplicity: require fsp/sdk/app/deep
# all non-empty.
context_complete() {
  [[ -n "$CTX_FSP" && -n "$CTX_SDK" && -n "$CTX_APP" && -n "$CTX_DEEP" ]]
}

# --- disk inference --------------------------------------------------------

# Sets globals INF_LAYOUT, INF_PROJECT, INF_FSP, INF_SDK, INF_APP, INF_CUI,
# INF_DEEP, INF_WS. Returns 0 on success, 2 on failure.
INF_LAYOUT=""
INF_PROJECT=""
INF_FSP=""
INF_SDK=""
INF_APP=""
INF_CUI=""
INF_DEEP=""
INF_WS=""

infer_from_disk() {
  local fsp_dir
  fsp_dir="$(find_fsp_dir)"
  if [[ -z "$fsp_dir" ]]; then
    echo "ERROR: no com.bosch.fsp.* directory found under $USER_ROOT" >&2
    return 2
  fi

  INF_PROJECT="$(fsp_to_project_name "$fsp_dir")"
  INF_FSP="$fsp_dir"

  # Layout determination:
  #   flat   → fsp lives directly under USER_ROOT
  #            (USER_ROOT == dirname(fsp); workspace == USER_ROOT)
  #   nested → fsp lives under <USER_ROOT>/<P>/<P>/com.bosch.fsp.<P>
  #            and <USER_ROOT>/<P>/.metadata exists (Eclipse workspace marker).
  #            workspace == <USER_ROOT>/<P>
  local fsp_parent
  fsp_parent="$(dirname "$fsp_dir")"
  if [[ "$fsp_parent" == "$USER_ROOT" ]]; then
    INF_LAYOUT="flat"
    INF_WS="$USER_ROOT"
  else
    INF_LAYOUT="nested"
    # Walk up to find Eclipse workspace dir (one with .metadata sibling)
    local maybe_ws
    maybe_ws="$(dirname "$fsp_parent")"
    if [[ -d "$maybe_ws/.metadata" ]]; then
      INF_WS="$maybe_ws"
    else
      # Fallback: assume <USER_ROOT>/<P> is the workspace
      INF_WS="$maybe_ws"
    fi
  fi
  local ws_dir="$fsp_parent"

  # SDK / APP discovery within ws_dir
  # SDK = <P>_CPP_SDK or <P>_SDK
  # APP = any other <P>_* directory
  local sdk_candidate=""
  local app_candidate=""
  local d base
  local matches
  matches="$(find "$ws_dir" -maxdepth 1 -mindepth 1 -type d -name "${INF_PROJECT}_*" 2>/dev/null)"
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    base="$(basename "$d")"
    case "$base" in
      "${INF_PROJECT}_CPP_SDK"|"${INF_PROJECT}_SDK")
        if [[ -z "$sdk_candidate" ]]; then
          sdk_candidate="$d"
        fi
        ;;
      *)
        if [[ -z "$app_candidate" ]]; then
          app_candidate="$d"
        else
          echo "WARN: multiple ${INF_PROJECT}_* app candidates — using $(basename "$app_candidate")" >&2
        fi
        ;;
    esac
  done <<< "$matches"

  if [[ -z "$sdk_candidate" ]]; then
    echo "ERROR: SDK directory (${INF_PROJECT}_CPP_SDK or ${INF_PROJECT}_SDK) not found in $ws_dir" >&2
    return 2
  fi
  if [[ -z "$app_candidate" ]]; then
    echo "ERROR: APP directory (${INF_PROJECT}_*) not found in $ws_dir" >&2
    return 2
  fi

  INF_SDK="$(normalize_path "$sdk_candidate")"
  INF_APP="$(normalize_path "$app_candidate")"
  INF_DEEP="$INF_APP/ui"

  # CustomUI src — at Eclipse workspace level (INF_WS), which equals
  # USER_ROOT for flat and <USER_ROOT>/<P> for nested.
  if [[ -d "$INF_WS/customui-src" ]]; then
    INF_CUI="$(normalize_path "$INF_WS/customui-src")"
  else
    INF_CUI=""
  fi

  return 0
}

# --- SSOT mismatch check ---------------------------------------------------

check_ssot_mismatch() {
  local effective_cui="$1"
  if [[ ! -f "$WS_FILE" ]]; then
    return 0
  fi
  local ws_active
  ws_active="$(jq -r '.ui.activeSrcPath // ""' "$WS_FILE" 2>/dev/null)"
  [[ -z "$ws_active" || "$ws_active" == "null" ]] && return 0

  # Resolve workspace.activeSrcPath (USER_ROOT-relative) to absolute
  local ws_active_abs
  if [[ "$ws_active" = /* ]]; then
    ws_active_abs="$ws_active"
  else
    ws_active_abs="$USER_ROOT/$ws_active"
  fi

  if [[ -n "$effective_cui" && "$ws_active_abs" != "$effective_cui" ]]; then
    echo "WARN: SSOT mismatch — context.customui_src_path ($effective_cui) != workspace.activeSrcPath ($ws_active_abs)" >&2
  fi
}

# --- main ------------------------------------------------------------------

read_context

LAYOUT_KIND=""
FSP_PATH=""
SDK_PROJECT_PATH=""
APP_PROJECT_PATH=""
CUSTOMUI_SRC_PATH=""
DEEP_UI_PATH=""
WORKSPACE_PATH=""
PROJECT_NAME=""

if [[ "$CTX_PRESENT" -eq 1 ]] && context_complete; then
  # Use context verbatim
  FSP_PATH="$(normalize_path "$CTX_FSP")"
  SDK_PROJECT_PATH="$(normalize_path "$CTX_SDK")"
  APP_PROJECT_PATH="$(normalize_path "$CTX_APP")"
  DEEP_UI_PATH="$(normalize_path "$CTX_DEEP")"
  if [[ -n "$CTX_CUI" ]]; then
    CUSTOMUI_SRC_PATH="$(normalize_path "$CTX_CUI")"
  else
    CUSTOMUI_SRC_PATH="null"
  fi
  if [[ -n "$CTX_WS" ]]; then
    WORKSPACE_PATH="$(normalize_path "$CTX_WS")"
  else
    WORKSPACE_PATH="$(dirname "$FSP_PATH")"
  fi
  PROJECT_NAME="$CTX_NAME"
  if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(fsp_to_project_name "$FSP_PATH")"
  fi
  if [[ -n "$CTX_LAYOUT" ]]; then
    LAYOUT_KIND="$CTX_LAYOUT"
  else
    if [[ "$WORKSPACE_PATH" == "$USER_ROOT" ]]; then
      LAYOUT_KIND="flat"
    else
      LAYOUT_KIND="nested"
    fi
  fi
else
  # Fallback path: warn + infer
  if [[ "$CTX_PRESENT" -eq 0 ]]; then
    echo "WARN: no context — disk inference ($CTX_FILE missing)" >&2
  else
    echo "WARN: partial context — falling back to disk inference" >&2
  fi
  if ! infer_from_disk; then
    exit 2
  fi
  LAYOUT_KIND="$INF_LAYOUT"
  FSP_PATH="$INF_FSP"
  SDK_PROJECT_PATH="$INF_SDK"
  APP_PROJECT_PATH="$INF_APP"
  DEEP_UI_PATH="$INF_DEEP"
  if [[ -n "$INF_CUI" ]]; then
    CUSTOMUI_SRC_PATH="$INF_CUI"
  else
    CUSTOMUI_SRC_PATH="null"
  fi
  WORKSPACE_PATH="$INF_WS"
  PROJECT_NAME="$INF_PROJECT"
fi

# Always run SSOT mismatch check (advisory; non-fatal)
if [[ "$CUSTOMUI_SRC_PATH" != "null" ]]; then
  check_ssot_mismatch "$CUSTOMUI_SRC_PATH"
fi

# --- container path synthesis ---------------------------------------------

MOUNT_ROOT=""
APP_PROJECT_PATH_CONTAINER=""
FSP_PATH_CONTAINER=""

if [[ "$LAYOUT_KIND" == "nested" ]]; then
  MOUNT_ROOT="$WORKSPACE_PATH"
  APP_PROJECT_PATH_CONTAINER="/workspace/${PROJECT_NAME}/$(basename "$APP_PROJECT_PATH")"
  FSP_PATH_CONTAINER="/workspace/${PROJECT_NAME}/$(basename "$FSP_PATH")"
elif [[ "$LAYOUT_KIND" == "flat" ]]; then
  MOUNT_ROOT="$USER_ROOT"
  APP_PROJECT_PATH_CONTAINER="/workspace/$(basename "$APP_PROJECT_PATH")"
  FSP_PATH_CONTAINER="/workspace/$(basename "$FSP_PATH")"
else
  # unknown layout — fall back to host-mirrored container paths
  MOUNT_ROOT="$USER_ROOT"
  APP_PROJECT_PATH_CONTAINER="/workspace/$(basename "$APP_PROJECT_PATH")"
  FSP_PATH_CONTAINER="/workspace/$(basename "$FSP_PATH")"
fi

# --- emit ------------------------------------------------------------------

echo "LAYOUT_KIND=$LAYOUT_KIND"
echo "WORKSPACE_PATH=$WORKSPACE_PATH"
echo "FSP_PATH=$FSP_PATH"
echo "SDK_PROJECT_PATH=$SDK_PROJECT_PATH"
echo "APP_PROJECT_PATH=$APP_PROJECT_PATH"
echo "CUSTOMUI_SRC_PATH=$CUSTOMUI_SRC_PATH"
echo "DEEP_UI_PATH=$DEEP_UI_PATH"
echo "APP_PROJECT_PATH_CONTAINER=$APP_PROJECT_PATH_CONTAINER"
echo "FSP_PATH_CONTAINER=$FSP_PATH_CONTAINER"
echo "MOUNT_ROOT=$MOUNT_ROOT"
exit 0
