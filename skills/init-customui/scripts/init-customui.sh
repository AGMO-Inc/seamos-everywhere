#!/usr/bin/env bash
# init-customui.sh — SeamOS app CustomUI scaffold (vanilla / react), idempotent.
# Implements Execution Flow + Mode Transition Matrix described in
# skills/init-customui/SKILL.md and references/mode-transition-matrix.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SHARED_FIND_USER_ROOT="$SCRIPT_DIR/../../shared-references/scripts/find-user-root.sh"
SHARED_RESOLVE_PATHS="$SCRIPT_DIR/../../shared-references/scripts/resolve-paths.sh"
ASSET_DO_NOT_EDIT="$SKILL_DIR/assets/seamos-do-not-edit.md"
ASSET_VANILLA_README="$SKILL_DIR/assets/vanilla-readme.md"

# ─── Defaults / args ───────────────────────────────────────────────────────
PROJECT_ARG=""
APP_PROJECT_ARG=""
UI_ARG=""
RESET=0
NON_INTERACTIVE=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: init-customui.sh [options]

Initialize the per-app CustomUI directory layout for a SeamOS project.
Vanilla mode: deep ui/ is the working SSOT (no build step).
React mode: scaffolds \${PROJECT}/customui-src/ from a template, npm install,
            patches deploy output to deep ui/, drops a do-not-edit marker.

Options:
  --project-name <name>       Project name (default: .seamos-context.json
                              last_project.name)
  --ui <react|vanilla>        Target UI mode (default: .seamos-workspace.json
                              ui.defaultFramework)
  --app-project-name <name>   App-project name (default: .seamos-context.json
                              last_project.app_project_name)
  --reset                     Switch modes destructively (deep ui/ →
                              ui.bak.{ts}/). Required when switching modes.
  --non-interactive           Never prompt. Destructive transitions FAIL-CLOSED
                              (exit 64) under this flag.
  --dry-run                   Print planned actions without mutating anything.
  --help                      Show this help and exit 0

Exit codes:
  0   OK / no-op (idempotent re-run, dry-run, skip, abort)
  64  usage / preflight (workspace JSON missing, deep ui/ missing,
      app_project_name unresolved, non-interactive destructive)
  65  data fault (malformed workspace JSON or context JSON)
  73  reserved
  74  network / IO (git clone, npm install)

Last line of stdout is one of:
  STATUS_OK
  STATUS_WARN: <reason>
  STATUS_ERR: <reason>
EOF
}

# ─── Logging helpers ───────────────────────────────────────────────────────
log()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "WARN: $*" >&2; }
err()  { printf '%s\n' "ERROR: $*" >&2; }

# ─── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      if [[ $# -lt 2 ]]; then err "--project-name requires a value"; exit 64; fi
      PROJECT_ARG="$2"; shift 2 ;;
    --app-project-name)
      if [[ $# -lt 2 ]]; then err "--app-project-name requires a value"; exit 64; fi
      APP_PROJECT_ARG="$2"; shift 2 ;;
    --ui)
      if [[ $# -lt 2 ]]; then err "--ui requires a value"; exit 64; fi
      UI_ARG="$2"; shift 2 ;;
    --reset)            RESET=1; shift ;;
    --non-interactive)  NON_INTERACTIVE=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    --help|-h)          usage; exit 0 ;;
    *) err "unknown argument: $1"; usage >&2; exit 64 ;;
  esac
done

# ─── jq required ───────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  err "jq is required — install jq and re-run"
  log "STATUS_ERR: jq missing"
  exit 73
fi

# ─── Step 1 — Resolve USER_ROOT via shared lib ─────────────────────────────
if [[ ! -f "$SHARED_FIND_USER_ROOT" ]]; then
  err "shared lib not found: $SHARED_FIND_USER_ROOT"
  log "STATUS_ERR: find-user-root.sh missing"
  exit 64
fi

USER_ROOT=""
set +e
USER_ROOT="$(SEAMOS_ALLOW_PWD_FALLBACK=0 bash "$SHARED_FIND_USER_ROOT" 2>/dev/null)"
fur_rc=$?
set -e
if [[ $fur_rc -ne 0 || -z "$USER_ROOT" ]]; then
  err "STATUS_ERR: .seamos-workspace.json not found — run 'setup' first"
  log "STATUS_ERR: .seamos-workspace.json not found — run 'setup' first"
  exit 64
fi
log "[user-root] $USER_ROOT"

WORKSPACE_JSON="$USER_ROOT/.seamos-workspace.json"
CONTEXT_JSON="$USER_ROOT/.seamos-context.json"

# ─── Step 2 — Validate workspace JSON ──────────────────────────────────────
if [[ ! -f "$WORKSPACE_JSON" ]]; then
  err "STATUS_ERR: .seamos-workspace.json not found — run 'setup' first"
  log "STATUS_ERR: .seamos-workspace.json not found — run 'setup' first"
  exit 64
fi
if ! jq -e . "$WORKSPACE_JSON" >/dev/null 2>&1; then
  err "STATUS_ERR: .seamos-workspace.json is invalid JSON"
  log "STATUS_ERR: .seamos-workspace.json is invalid JSON"
  exit 65
fi
WS_SCHEMA_VERSION="$(jq -r '.schemaVersion // empty' "$WORKSPACE_JSON")"
if [[ "$WS_SCHEMA_VERSION" != "1" ]]; then
  err "STATUS_ERR: .seamos-workspace.json schemaVersion is '$WS_SCHEMA_VERSION', expected 1 — re-run 'setup' or migrate manually"
  log "STATUS_ERR: schemaVersion mismatch"
  exit 65
fi

# ─── Step 3 — Load context (optional if both --project-name + --app-project-name given) ─────
HAS_BOTH_OVERRIDES=0
if [[ -n "$PROJECT_ARG" && -n "$APP_PROJECT_ARG" ]]; then
  HAS_BOTH_OVERRIDES=1
fi

CTX_PROJECT=""
CTX_APP_PROJECT=""
CTX_APP_PROJECT_PATH=""
if [[ -f "$CONTEXT_JSON" ]]; then
  if ! jq -e . "$CONTEXT_JSON" >/dev/null 2>&1; then
    if [[ $HAS_BOTH_OVERRIDES -eq 1 ]]; then
      warn ".seamos-context.json invalid JSON — using CLI overrides"
    else
      err "STATUS_ERR: .seamos-context.json missing or invalid — run 'create-project' first"
      log "STATUS_ERR: .seamos-context.json missing or invalid — run 'create-project' first"
      exit 64
    fi
  else
    CTX_PROJECT="$(jq -r '.last_project.name // empty' "$CONTEXT_JSON")"
    CTX_APP_PROJECT="$(jq -r '.last_project.app_project_name // empty' "$CONTEXT_JSON")"
    CTX_APP_PROJECT_PATH="$(jq -r '.last_project.app_project_path // empty' "$CONTEXT_JSON")"
  fi
else
  if [[ $HAS_BOTH_OVERRIDES -ne 1 ]]; then
    err "STATUS_ERR: .seamos-context.json missing or invalid — run 'create-project' first"
    log "STATUS_ERR: .seamos-context.json missing or invalid — run 'create-project' first"
    exit 64
  fi
fi

# ─── Step 4 — Resolve effective values ─────────────────────────────────────
PROJECT="${PROJECT_ARG:-$CTX_PROJECT}"
APP_PROJECT="${APP_PROJECT_ARG:-$CTX_APP_PROJECT}"

CURRENT_MODE="$(jq -r '.ui.defaultFramework // "null"' "$WORKSPACE_JSON")"
if [[ -n "$UI_ARG" ]]; then
  TARGET_MODE="$UI_ARG"
else
  WS_DEFAULT_FW="$(jq -r '.ui.defaultFramework // empty' "$WORKSPACE_JSON")"
  TARGET_MODE="$WS_DEFAULT_FW"
fi

if [[ -z "$PROJECT" ]]; then
  err "STATUS_ERR: --project-name unresolved — pass --project-name or run 'create-project' first"
  log "STATUS_ERR: --project-name unresolved"
  exit 64
fi
if [[ -z "$APP_PROJECT" ]]; then
  err "STATUS_ERR: --app-project-name unresolved — pass --app-project-name or run 'create-project' first"
  log "STATUS_ERR: --app-project-name unresolved"
  exit 64
fi
if [[ -z "$TARGET_MODE" ]]; then
  err "STATUS_ERR: --ui unresolved — pass --ui react|vanilla (no defaultFramework set in workspace JSON)"
  log "STATUS_ERR: --ui unresolved"
  exit 64
fi
case "$TARGET_MODE" in
  vanilla|react) ;;
  *)
    err "STATUS_ERR: --ui must be 'react' or 'vanilla' (got '$TARGET_MODE')"
    log "STATUS_ERR: --ui invalid"
    exit 64 ;;
esac

log "[project] $PROJECT"
log "[app-project] $APP_PROJECT"
log "[mode] current=$CURRENT_MODE target=$TARGET_MODE"

# ─── Step 5 — Resolve paths via shared helper ─────────────────────────────
# Delegate all path resolution (deep ui, customui src, workspace, layout) to
# the shared `resolve-paths.sh` so init-customui never reasons about layout
# itself. Helper emits KEY=VALUE lines on stdout; we eval them into locals.
if [[ ! -f "$SHARED_RESOLVE_PATHS" ]]; then
  err "STATUS_ERR: shared lib not found: $SHARED_RESOLVE_PATHS"
  log "STATUS_ERR: resolve-paths.sh missing"
  exit 64
fi

LAYOUT_KIND=""
WORKSPACE_PATH=""
DEEP_UI_PATH=""
CUSTOMUI_SRC_PATH=""

set +e
RESOLVE_OUT="$(bash "$SHARED_RESOLVE_PATHS" "$USER_ROOT" 2>&1 >/dev/null)"
RESOLVE_KV="$(bash "$SHARED_RESOLVE_PATHS" "$USER_ROOT" 2>/dev/null)"
resolve_rc=$?
set -e
if [[ $resolve_rc -ne 0 ]]; then
  err "STATUS_ERR: resolve-paths.sh failed (rc=$resolve_rc): $RESOLVE_OUT"
  log "STATUS_ERR: resolve-paths.sh failed"
  exit 64
fi
while IFS='=' read -r _k _v; do
  case "$_k" in
    LAYOUT_KIND)        LAYOUT_KIND="$_v" ;;
    WORKSPACE_PATH)     WORKSPACE_PATH="$_v" ;;
    DEEP_UI_PATH)       DEEP_UI_PATH="$_v" ;;
    CUSTOMUI_SRC_PATH)  CUSTOMUI_SRC_PATH="$_v" ;;
  esac
done <<< "$RESOLVE_KV"

DEEP_UI="$DEEP_UI_PATH"
if [[ -z "$DEEP_UI" || ! -d "$DEEP_UI" ]]; then
  err "STATUS_ERR: deep ui/ not found at $DEEP_UI — run 'create-project' first"
  log "STATUS_ERR: deep ui/ not found at $DEEP_UI — run 'create-project' first"
  exit 64
fi
# Normalize to absolute realpath so it shares prefix with USER_ROOT (macOS /tmp ↔ /private/tmp).
DEEP_UI="$( cd "$DEEP_UI" && pwd -P )"
log "[deep-ui] $DEEP_UI"
log "[layout] $LAYOUT_KIND"

# Helper: USER_ROOT-relative path (portable across macOS/Linux).
relpath_from_user_root() {
  local target="$1"
  python3 -c "import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" \
    "$target" "$USER_ROOT"
}
relpath_between() {
  # $1 = target, $2 = base
  python3 -c "import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" \
    "$1" "$2"
}

DEEP_UI_REL_USER_ROOT="$(relpath_from_user_root "$DEEP_UI")"
# CustomUI src lives at the Eclipse-workspace level for both layouts
# (helper-defined WORKSPACE_PATH). In vanilla mode the helper returns the
# literal string "null" for CUSTOMUI_SRC_PATH; we still need a known location
# to drop / clone customui-src/ if/when react mode is invoked.
if [[ -n "$CUSTOMUI_SRC_PATH" && "$CUSTOMUI_SRC_PATH" != "null" ]]; then
  CUSTOMUI_SRC="$CUSTOMUI_SRC_PATH"
else
  CUSTOMUI_SRC="$WORKSPACE_PATH/customui-src"
fi

# ─── Step 6 — Determine transition ─────────────────────────────────────────
# CURRENT_MODE: "null" / "vanilla" / "react"
# TARGET_MODE:  "vanilla" / "react"
DESTRUCTIVE=0
if [[ "$CURRENT_MODE" == "vanilla" && "$TARGET_MODE" == "react" ]]; then
  DESTRUCTIVE=1
elif [[ "$CURRENT_MODE" == "react" && "$TARGET_MODE" == "vanilla" ]]; then
  DESTRUCTIVE=1
fi

if [[ $DESTRUCTIVE -eq 1 ]]; then
  if [[ $RESET -ne 1 ]]; then
    log "[skip] mode mismatch (current=${CURRENT_MODE}, requested=${TARGET_MODE}) — pass --reset to switch"
    log "STATUS_OK"
    exit 0
  fi
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    err "STATUS_ERR: destructive transition requires interactive confirmation"
    log "STATUS_ERR: destructive transition requires interactive confirmation"
    exit 64
  fi
  # Interactive confirm (skip in dry-run; just announce).
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would prompt user to confirm destructive transition"
  else
    if [[ -t 0 ]]; then
      printf 'This will move existing %s to ui.bak.<timestamp>/ and delete customui-src/ (or vice versa).\n' "$DEEP_UI"
      printf "Type 'yes' to confirm: "
      reply=""
      read -r reply || reply=""
      if [[ "$reply" != "yes" ]]; then
        log "[abort] user declined"
        log "STATUS_OK"
        exit 0
      fi
    else
      err "STATUS_ERR: destructive transition requires interactive confirmation (no tty)"
      log "STATUS_ERR: destructive transition requires interactive confirmation (no tty)"
      exit 64
    fi
  fi
fi

# Timestamp for backups (UTC ISO 8601 with colons removed).
UTC_ISO_NO_COLONS="$(date -u +%Y-%m-%dT%H%MZ)"

# Helper: update workspace JSON ui fields AND context JSON customui_src_path
# in a single transaction. Either both files are updated, or neither is —
# never one without the other. Pattern: jq → both tmp files → pre-flight
# writability check → mv #1 → mv #2 (with mv #1 rollback on mv #2 failure).
#
# Args:
#   $1 fw       — "vanilla" or "react"
#   $2 active   — workspace.ui.activeSrcPath value (USER_ROOT-relative)
#   $3 ctx_cui  — context.last_project.customui_src_path value:
#                 absolute path for react, or the literal "null" to set JSON null
update_ssot_pair() {
  local fw="$1"
  local active="$2"
  local ctx_cui="$3"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would update workspace JSON ui.defaultFramework=${fw}, ui.activeSrcPath=${active}"
    log "[dry-run] would update context JSON last_project.customui_src_path=${ctx_cui}"
    return 0
  fi

  # Pre-flight: workspace JSON must exist and be writable (read-only chmod must
  # abort BEFORE any mv so both files keep their mtime).
  if [[ ! -w "$WORKSPACE_JSON" ]]; then
    err "STATUS_ERR: $WORKSPACE_JSON not writable — SSOT pair update aborted (both files unchanged)"
    log "STATUS_ERR: workspace JSON not writable"
    exit 73
  fi
  # Context JSON is optional from create-project, but if present must be writable.
  if [[ -f "$CONTEXT_JSON" && ! -w "$CONTEXT_JSON" ]]; then
    err "STATUS_ERR: $CONTEXT_JSON not writable — SSOT pair update aborted (both files unchanged)"
    log "STATUS_ERR: context JSON not writable"
    exit 73
  fi

  local tmp_ws tmp_ctx
  tmp_ws="$(mktemp)"
  if ! jq --arg fw "$fw" --arg path "$active" \
       '.ui.defaultFramework=$fw | .ui.activeSrcPath=$path' \
       "$WORKSPACE_JSON" > "$tmp_ws"; then
    rm -f "$tmp_ws"
    err "STATUS_ERR: jq failed on $WORKSPACE_JSON — SSOT pair update aborted"
    log "STATUS_ERR: workspace JSON jq failed"
    exit 65
  fi

  # Build context tmp only if context JSON exists; otherwise skip context write.
  local have_ctx=0
  if [[ -f "$CONTEXT_JSON" ]]; then
    tmp_ctx="$(mktemp)"
    have_ctx=1
    if [[ "$ctx_cui" == "null" ]]; then
      if ! jq '.last_project.customui_src_path = null' \
           "$CONTEXT_JSON" > "$tmp_ctx"; then
        rm -f "$tmp_ws" "$tmp_ctx"
        err "STATUS_ERR: jq failed on $CONTEXT_JSON — SSOT pair update aborted"
        log "STATUS_ERR: context JSON jq failed"
        exit 65
      fi
    else
      if ! jq --arg p "$ctx_cui" \
           '.last_project.customui_src_path = $p' \
           "$CONTEXT_JSON" > "$tmp_ctx"; then
        rm -f "$tmp_ws" "$tmp_ctx"
        err "STATUS_ERR: jq failed on $CONTEXT_JSON — SSOT pair update aborted"
        log "STATUS_ERR: context JSON jq failed"
        exit 65
      fi
    fi
  fi

  # Commit phase. Workspace first; on workspace mv failure neither file is
  # touched. On context mv failure (rare), roll workspace back from a snapshot.
  local ws_snapshot=""
  ws_snapshot="$(mktemp)"
  cp "$WORKSPACE_JSON" "$ws_snapshot"

  if ! mv "$tmp_ws" "$WORKSPACE_JSON"; then
    rm -f "$tmp_ws" "$ws_snapshot"
    [[ $have_ctx -eq 1 ]] && rm -f "$tmp_ctx"
    err "STATUS_ERR: mv to $WORKSPACE_JSON failed — SSOT pair update aborted (both files unchanged)"
    log "STATUS_ERR: workspace JSON mv failed"
    exit 73
  fi

  if [[ $have_ctx -eq 1 ]]; then
    if ! mv "$tmp_ctx" "$CONTEXT_JSON"; then
      # Rollback workspace from snapshot so the invariant holds.
      cp "$ws_snapshot" "$WORKSPACE_JSON" || true
      rm -f "$tmp_ctx" "$ws_snapshot"
      err "STATUS_ERR: mv to $CONTEXT_JSON failed — workspace rolled back (both files unchanged)"
      log "STATUS_ERR: context JSON mv failed (workspace rolled back)"
      exit 73
    fi
  fi

  rm -f "$ws_snapshot"
  log "[write] $WORKSPACE_JSON (ui.defaultFramework=${fw}, ui.activeSrcPath=${active})"
  if [[ $have_ctx -eq 1 ]]; then
    log "[write] $CONTEXT_JSON (last_project.customui_src_path=${ctx_cui})"
  fi
}

# Helper: backup deep ui/ → ui.bak.{ts}/
backup_deep_ui() {
  local parent
  parent="$(dirname "$DEEP_UI")"
  local backup="$parent/ui.bak.$UTC_ISO_NO_COLONS"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would mv $DEEP_UI $backup"
    log "[dry-run] would mkdir -p $DEEP_UI"
  else
    mv "$DEEP_UI" "$backup"
    log "[backup] $backup"
    mkdir -p "$DEEP_UI"
    log "[mkdir] $DEEP_UI"
  fi
}

# Helper: count files in deep ui/ (used by vanilla README drop heuristic).
deep_ui_is_skeleton_or_empty() {
  # Returns 0 (true) if deep ui/ is empty OR contains only index.html.
  local count
  count="$(find "$DEEP_UI" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    return 0
  fi
  if [[ "$count" -eq 1 ]]; then
    if [[ -f "$DEEP_UI/index.html" ]]; then
      return 0
    fi
  fi
  return 1
}

# Helper: remove sentinel block from .gitignore.
remove_gitignore_sentinel() {
  local gi="$USER_ROOT/.gitignore"
  if [[ ! -f "$gi" ]]; then
    return 0
  fi
  local begin="# BEGIN seamos-init-customui:${PROJECT}"
  local end="# END seamos-init-customui:${PROJECT}"
  if ! grep -Fq "$begin" "$gi" 2>/dev/null; then
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would remove sentinel block from $gi"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    BEGIN { skip = 0 }
    {
      if ($0 == b) { skip = 1; next }
      if (skip == 1 && $0 == e) { skip = 0; next }
      if (skip == 0) print
    }
  ' "$gi" > "$tmp"
  mv "$tmp" "$gi"
  log "[edit] $gi (sentinel block removed)"
}

# Helper: append sentinel block to .gitignore (idempotent).
append_gitignore_sentinel() {
  local gi="$USER_ROOT/.gitignore"
  local begin="# BEGIN seamos-init-customui:${PROJECT}"
  local end="# END seamos-init-customui:${PROJECT}"
  if [[ -f "$gi" ]] && grep -Fq "$begin" "$gi" 2>/dev/null; then
    log "[skip] .gitignore sentinel already present"
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would append sentinel block to $gi"
    return 0
  fi
  {
    if [[ -f "$gi" ]] && [[ -s "$gi" ]]; then
      # Ensure trailing newline before appending block.
      tail -c 1 "$gi" | od -An -c | grep -q '\\n' || printf '\n' >> "$gi"
    fi
    printf '%s\n' "$begin" >> "$gi"
    printf '%s/customui-src/dist/\n' "$PROJECT" >> "$gi"
    printf '%s/customui-src/node_modules/\n' "$PROJECT" >> "$gi"
    printf '%s\n' "$end" >> "$gi"
  }
  log "[edit] $gi (sentinel block appended)"
}

# ─── Vanilla mode ──────────────────────────────────────────────────────────
do_vanilla() {
  # Destructive transition: react → vanilla.
  if [[ "$CURRENT_MODE" == "react" && $RESET -eq 1 ]]; then
    backup_deep_ui
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[dry-run] would rm -rf $CUSTOMUI_SRC"
    else
      if [[ -d "$CUSTOMUI_SRC" ]]; then
        rm -rf "$CUSTOMUI_SRC"
        log "[remove] $CUSTOMUI_SRC"
      fi
    fi
    remove_gitignore_sentinel
  fi

  # Drop vanilla README if deep ui/ is empty/skeleton.
  if deep_ui_is_skeleton_or_empty; then
    local target="$DEEP_UI/README.md"
    if [[ -f "$target" ]]; then
      log "[skip] $target already exists"
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[dry-run] would write $target (vanilla README)"
      else
        if [[ ! -f "$ASSET_VANILLA_README" ]]; then
          warn "vanilla README asset missing: $ASSET_VANILLA_README"
        else
          cp "$ASSET_VANILLA_README" "$target"
          log "[write] $target"
        fi
      fi
    fi
  else
    log "[skip] deep ui/ already has user content — README not dropped"
  fi

  # Update workspace + context JSON (single SSOT transaction).
  # vanilla → activeSrcPath = deep ui (USER_ROOT-relative);
  #           context.customui_src_path = null (no react source tree).
  local current_active current_cui
  current_active="$(jq -r '.ui.activeSrcPath // empty' "$WORKSPACE_JSON")"
  current_cui="null"
  if [[ -f "$CONTEXT_JSON" ]]; then
    current_cui="$(jq -r '.last_project.customui_src_path // "null"' "$CONTEXT_JSON")"
  fi
  if [[ "$CURRENT_MODE" == "vanilla" \
        && "$current_active" == "$DEEP_UI_REL_USER_ROOT" \
        && "$current_cui" == "null" ]]; then
    log "[skip] vanilla mode already configured"
    log "[skip] activeSrcPath already set"
    log "[skip] context customui_src_path already null"
  else
    update_ssot_pair "vanilla" "$DEEP_UI_REL_USER_ROOT" "null"
  fi
}

# ─── React mode ────────────────────────────────────────────────────────────
do_react() {
  # Destructive transition: vanilla → react.
  if [[ "$CURRENT_MODE" == "vanilla" && $RESET -eq 1 ]]; then
    backup_deep_ui
  fi

  # If customui-src/ already exists and not --reset, skip clone (idempotent).
  local clone_needed=1
  if [[ -d "$CUSTOMUI_SRC" ]]; then
    if [[ $RESET -eq 1 && "$CURRENT_MODE" == "react" ]]; then
      # react → react with --reset: re-clone.
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[dry-run] would rm -rf $CUSTOMUI_SRC"
      else
        rm -rf "$CUSTOMUI_SRC"
        log "[remove] $CUSTOMUI_SRC (re-clone)"
      fi
    elif [[ $RESET -eq 1 && "$CURRENT_MODE" == "vanilla" ]]; then
      # vanilla → react but customui-src/ somehow exists (stale): wipe.
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[dry-run] would rm -rf $CUSTOMUI_SRC (stale)"
      else
        rm -rf "$CUSTOMUI_SRC"
        log "[remove] $CUSTOMUI_SRC (stale)"
      fi
    else
      log "[skip] customui-src/ already present — pass --reset to re-clone"
      clone_needed=0
    fi
  fi

  local TEMPLATE_REPO TEMPLATE_REF
  TEMPLATE_REPO="$(jq -r '.ui.react.templateRepo // empty' "$WORKSPACE_JSON")"
  TEMPLATE_REF="$(jq -r '.ui.react.templateRef // empty' "$WORKSPACE_JSON")"
  if [[ -z "$TEMPLATE_REPO" || -z "$TEMPLATE_REF" ]]; then
    err "STATUS_ERR: workspace JSON ui.react.{templateRepo,templateRef} missing"
    log "STATUS_ERR: workspace JSON ui.react.{templateRepo,templateRef} missing"
    exit 65
  fi

  # A4 (2026-05): resolve remote HEAD when templateRef is the legacy default
  # 'main' (or empty). Treat the remote's actual default branch as authoritative
  # so a future template-repo rename never silently breaks setup -> init flow.
  if [[ "$TEMPLATE_REF" == "main" ]]; then
    if command -v git >/dev/null 2>&1; then
      remote_default="$(git ls-remote --symref "$TEMPLATE_REPO" HEAD 2>/dev/null \
        | awk '/^ref:/ { sub("refs/heads/", "", $2); print $2; exit }')" || remote_default=""
      if [[ -n "$remote_default" && "$remote_default" != "$TEMPLATE_REF" ]]; then
        warn "workspace ui.react.templateRef='$TEMPLATE_REF' overridden by remote default '$remote_default' (template repo: $TEMPLATE_REPO)"
        TEMPLATE_REF="$remote_default"
      fi
    fi
  fi

  if [[ $clone_needed -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[dry-run] would git clone --depth 1 -b $TEMPLATE_REF $TEMPLATE_REPO $CUSTOMUI_SRC"
    else
      mkdir -p "$(dirname "$CUSTOMUI_SRC")"
      if ! git clone --depth 1 -b "$TEMPLATE_REF" "$TEMPLATE_REPO" "$CUSTOMUI_SRC"; then
        # Cleanup partial clone.
        if [[ -d "$CUSTOMUI_SRC" ]]; then
          rm -rf "$CUSTOMUI_SRC"
        fi
        err "STATUS_ERR: git clone failed (ref='$TEMPLATE_REF', repo='$TEMPLATE_REPO'). If the branch was renamed, run: setup --reconfigure"
        log "STATUS_ERR: git clone failed"
        exit 74
      fi
      log "[clone] $CUSTOMUI_SRC (ref=$TEMPLATE_REF)"
      rm -rf "$CUSTOMUI_SRC/.git"
      log "[clean] removed .git/ from $CUSTOMUI_SRC"
    fi
  fi

  # npm install.
  if [[ $clone_needed -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[dry-run] would (cd $CUSTOMUI_SRC && npm install)"
    else
      if ! ( cd "$CUSTOMUI_SRC" && npm install ); then
        err "STATUS_ERR: npm install failed (clone preserved at $CUSTOMUI_SRC)"
        log "STATUS_ERR: npm install failed (clone preserved at $CUSTOMUI_SRC)"
        exit 74
      fi
      log "[install] npm install completed"
    fi
  else
    log "[skip] npm install (customui-src/ already present)"
  fi

  # Auto-patch deploy output path.
  if [[ $clone_needed -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[dry-run] would auto-patch deploy output path (vite.config or package.json#scripts.deploy)"
    else
      auto_patch_deploy
    fi
  else
    log "[skip] deploy auto-patch (customui-src/ already present)"
  fi

  # Drop do-not-edit marker.
  local marker="$DEEP_UI/.seamos-do-not-edit.md"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would write $marker"
  else
    if [[ ! -f "$ASSET_DO_NOT_EDIT" ]]; then
      warn "do-not-edit asset missing: $ASSET_DO_NOT_EDIT"
    else
      cp "$ASSET_DO_NOT_EDIT" "$marker"
      log "[write] $marker"
    fi
  fi

  # .gitignore sentinel.
  append_gitignore_sentinel

  # Update workspace + context JSON (single SSOT transaction).
  # react → activeSrcPath = customui-src dir (USER_ROOT-relative, layout-aware
  #         via helper's WORKSPACE_PATH); context.customui_src_path = absolute.
  local active_path
  active_path="$(relpath_from_user_root "$CUSTOMUI_SRC")"
  local current_active current_cui
  current_active="$(jq -r '.ui.activeSrcPath // empty' "$WORKSPACE_JSON")"
  current_cui=""
  if [[ -f "$CONTEXT_JSON" ]]; then
    current_cui="$(jq -r '.last_project.customui_src_path // ""' "$CONTEXT_JSON")"
  fi
  if [[ "$CURRENT_MODE" == "react" \
        && "$current_active" == "$active_path" \
        && "$current_cui" == "$CUSTOMUI_SRC" ]]; then
    log "[skip] react mode already configured"
    log "[skip] activeSrcPath already set"
    log "[skip] context customui_src_path already set"
  else
    update_ssot_pair "react" "$active_path" "$CUSTOMUI_SRC"
  fi
}

# Auto-patch deploy output path. Pattern A → Pattern A2 (insert) → Pattern B fallback.
#
# A5: 0.7.1 의 회귀 — sed substitute 가 매치 실패해도 SUCCESS 로 보고했고,
#     사용자는 npm run build 후 산출물이 deep ui/ 가 아닌 customui-src/dist/ 로
#     떨어지는 걸 manifest 비교로 한참 뒤에야 발견했다.
#
# 2026-05 부터:
#   1) sed 직후 grep 으로 실제 patch 됐는지 검증.
#   2) sed 가 못 잡았으면 (defineConfig 안에 build.outDir 키가 아예 없는 경우)
#      awk 로 defineConfig 의 닫는 `}` 직전에 build 블록 삽입을 시도.
#   3) 그래도 실패하면 STATUS_WARN — false-SUCCESS 금지.
auto_patch_deploy() {
  local DEEP_UI_REL
  DEEP_UI_REL="$(relpath_between "$DEEP_UI" "$CUSTOMUI_SRC")"

  local cfg_ts="$CUSTOMUI_SRC/vite.config.ts"
  local cfg_js="$CUSTOMUI_SRC/vite.config.js"
  local cfg=""
  if [[ -f "$cfg_ts" ]]; then
    cfg="$cfg_ts"
  elif [[ -f "$cfg_js" ]]; then
    cfg="$cfg_js"
  fi

  if [[ -n "$cfg" ]]; then
    # ── Pattern A: substitute existing outDir literal ──
    # Match common forms: outDir: 'dist' / outDir: "dist" / outDir:"./dist" / outDir: 'dist/'
    cp "$cfg" "${cfg}.bak"
    sed -i.tmp -E "s|outDir:[[:space:]]*['\"]\\.?/?dist/?['\"]|outDir: '${DEEP_UI_REL}'|" "$cfg"
    rm -f "${cfg}.tmp"

    if grep -qE "outDir:[[:space:]]*['\"]${DEEP_UI_REL//\//\\/}['\"]" "$cfg"; then
      rm -f "${cfg}.bak"
      log "[deploy-patch] vite outDir → ${DEEP_UI_REL} ($cfg) [pattern A: substitute]"
      return 0
    fi

    # ── Pattern A2: outDir absent → insert a build block into defineConfig ──
    # Restore from backup before retrying so we don't double-patch.
    mv "${cfg}.bak" "$cfg"

    # Skip A2 if the file already contains `build:` or `outDir:` we couldn't
    # match — the config is non-standard and editing risks producing invalid TS.
    if grep -qE '(^|[[:space:]])build:[[:space:]]*\{' "$cfg" \
       || grep -qE '(^|[[:space:]])outDir:' "$cfg"; then
      warn "[deploy-patch] vite.config has a non-standard outDir/build block we can't safely patch — falling through to package.json"
    else
      # Insert immediately after `defineConfig({` opening — safe because it is
      # the standard scaffold pattern in the AGMO custom-ui-react-template.
      local tmp_cfg
      tmp_cfg="$(mktemp)"
      awk -v deep="$DEEP_UI_REL" '
        BEGIN { inserted = 0 }
        # Match `defineConfig({` on a line; insert after it.
        /defineConfig\s*\(\s*\{/ && !inserted {
          print
          print "  build: { outDir: '\''" deep "'\'', emptyOutDir: false },"
          inserted = 1
          next
        }
        { print }
        END { exit (inserted ? 0 : 1) }
      ' "$cfg" > "$tmp_cfg"
      if [[ $? -eq 0 ]] && grep -q "outDir: '${DEEP_UI_REL}'" "$tmp_cfg"; then
        mv "$tmp_cfg" "$cfg"
        log "[deploy-patch] vite outDir → ${DEEP_UI_REL} ($cfg) [pattern A2: insert]"
        return 0
      fi
      rm -f "$tmp_cfg"
    fi

    # vite.config 패치 모두 실패. package.json fallback 으로 진행.
    warn "[deploy-patch] vite.config patch failed (no recognized outDir literal, no defineConfig anchor)"
  fi

  local pkg="$CUSTOMUI_SRC/package.json"
  if [[ -f "$pkg" ]] && jq -e '.scripts.deploy' "$pkg" >/dev/null 2>&1; then
    # Pattern B: package.json#scripts.deploy.
    local tmp
    tmp="$(mktemp)"
    if jq --arg dir "$DEEP_UI_REL" \
        '.scripts.deploy = ("npm run build && cp -r dist/* " + $dir + "/")' \
        "$pkg" > "$tmp"; then
      mv "$tmp" "$pkg"
      if jq -e --arg dir "$DEEP_UI_REL" '.scripts.deploy | contains($dir)' "$pkg" >/dev/null 2>&1; then
        log "[deploy-patch] package.json deploy → ${DEEP_UI_REL} [pattern B]"
        return 0
      fi
    fi
    rm -f "$tmp"
    warn "[deploy-patch] package.json scripts.deploy patch failed"
  fi

  # All patterns failed — surface a STATUS_WARN reason (not SUCCESS).
  DEPLOY_PATCH_FAILED=1
  warn "[deploy-patch] could not auto-patch — see references/react-template.md 'Patch failure recovery'"
  warn "[deploy-patch] manual fix: add to ${cfg:-customui-src/vite.config.ts} inside defineConfig({...}):"
  warn "[deploy-patch]   build: { outDir: '${DEEP_UI_REL}', emptyOutDir: false },"
  return 0
}

# ─── Dispatch ──────────────────────────────────────────────────────────────
# Track non-fatal warnings raised during do_react.
DEPLOY_PATCH_FAILED=0

case "$TARGET_MODE" in
  vanilla) do_vanilla ;;
  react)   do_react ;;
esac

# A5: deploy-patch 실패 시 SUCCESS 가 아니라 STATUS_WARN 으로 종료.
if [[ "${DEPLOY_PATCH_FAILED:-0}" -eq 1 ]]; then
  log "STATUS_WARN: deploy-path patch skipped — add build.outDir manually (see warn lines above)"
  exit 0
fi

log "STATUS_OK"
exit 0
