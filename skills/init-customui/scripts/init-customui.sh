#!/usr/bin/env bash
# init-customui.sh — SeamOS app CustomUI scaffold (vanilla / react), idempotent.
# Implements Execution Flow + Mode Transition Matrix described in
# skills/init-customui/SKILL.md and references/mode-transition-matrix.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SHARED_FIND_USER_ROOT="$SCRIPT_DIR/../../shared-references/scripts/find-user-root.sh"
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

# ─── Step 5 — Compute deep ui/ path ────────────────────────────────────────
DEEP_UI=""
if [[ -n "$CTX_APP_PROJECT_PATH" && -d "$CTX_APP_PROJECT_PATH" ]]; then
  DEEP_UI="$CTX_APP_PROJECT_PATH/ui"
else
  DEEP_UI="$USER_ROOT/$PROJECT/$PROJECT/$APP_PROJECT/ui"
fi

if [[ ! -d "$DEEP_UI" ]]; then
  err "STATUS_ERR: deep ui/ not found at $DEEP_UI — run 'create-project' first"
  log "STATUS_ERR: deep ui/ not found at $DEEP_UI — run 'create-project' first"
  exit 64
fi
# Normalize to absolute realpath so it shares prefix with USER_ROOT (macOS /tmp ↔ /private/tmp).
DEEP_UI="$( cd "$DEEP_UI" && pwd -P )"
log "[deep-ui] $DEEP_UI"

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
CUSTOMUI_SRC="$USER_ROOT/$PROJECT/customui-src"

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

# Helper: update workspace JSON ui fields.
update_workspace_ui() {
  local fw="$1"
  local active="$2"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would update workspace JSON ui.defaultFramework=${fw}, ui.activeSrcPath=${active}"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  jq --arg fw "$fw" --arg path "$active" \
    '.ui.defaultFramework=$fw | .ui.activeSrcPath=$path' \
    "$WORKSPACE_JSON" > "$tmp"
  mv "$tmp" "$WORKSPACE_JSON"
  log "[write] $WORKSPACE_JSON (ui.defaultFramework=${fw}, ui.activeSrcPath=${active})"
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

  # Update workspace JSON.
  local current_active
  current_active="$(jq -r '.ui.activeSrcPath // empty' "$WORKSPACE_JSON")"
  if [[ "$CURRENT_MODE" == "vanilla" && "$current_active" == "$DEEP_UI_REL_USER_ROOT" ]]; then
    log "[skip] vanilla mode already configured"
    log "[skip] activeSrcPath already set"
  else
    update_workspace_ui "vanilla" "$DEEP_UI_REL_USER_ROOT"
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
        err "STATUS_ERR: git clone failed"
        log "STATUS_ERR: git clone failed"
        exit 74
      fi
      log "[clone] $CUSTOMUI_SRC"
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

  # Update workspace JSON.
  local active_path="$PROJECT/customui-src"
  local current_active
  current_active="$(jq -r '.ui.activeSrcPath // empty' "$WORKSPACE_JSON")"
  if [[ "$CURRENT_MODE" == "react" && "$current_active" == "$active_path" ]]; then
    log "[skip] react mode already configured"
    log "[skip] activeSrcPath already set"
  else
    update_workspace_ui "react" "$active_path"
  fi
}

# Auto-patch deploy output path. Pattern A → Pattern B fallback.
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
    # Pattern A: vite.config — substitute outDir literal.
    sed -i.bak -E "s|outDir:[[:space:]]*['\"]dist['\"]|outDir: '${DEEP_UI_REL}'|" "$cfg"
    rm -f "${cfg}.bak"
    log "[deploy-patch] vite outDir → ${DEEP_UI_REL} ($cfg)"
    return 0
  fi

  local pkg="$CUSTOMUI_SRC/package.json"
  if [[ -f "$pkg" ]] && jq -e '.scripts.deploy' "$pkg" >/dev/null 2>&1; then
    # Pattern B: package.json#scripts.deploy.
    local tmp
    tmp="$(mktemp)"
    jq --arg dir "$DEEP_UI_REL" \
      '.scripts.deploy = ("npm run build && cp -r dist/* " + $dir + "/")' \
      "$pkg" > "$tmp"
    mv "$tmp" "$pkg"
    log "[deploy-patch] package.json deploy → ${DEEP_UI_REL}"
    return 0
  fi

  warn "[deploy-patch] could not auto-patch — see references/react-template.md 'Patch failure recovery'"
  return 0
}

# ─── Dispatch ──────────────────────────────────────────────────────────────
case "$TARGET_MODE" in
  vanilla) do_vanilla ;;
  react)   do_react ;;
esac

log "STATUS_OK"
exit 0
