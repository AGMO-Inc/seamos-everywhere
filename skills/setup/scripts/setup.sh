#!/usr/bin/env bash
# setup.sh — SeamOS workspace bootstrap (idempotent).
# Implements Execution Flow described in skills/setup/SKILL.md (8 steps).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SHARED_FIND_USER_ROOT="$SCRIPT_DIR/../../shared-references/scripts/find-user-root.sh"
SHARED_RESOLVE_PATHS="$SCRIPT_DIR/../../shared-references/scripts/resolve-paths.sh"
TEMPLATE_MCP_JSON="$SKILL_DIR/assets/.mcp.json.template"

# ─── Defaults / args ───────────────────────────────────────────────────────
WORKSPACE_DIR=""
ENDPOINT_INPUT="dev"
RECONFIGURE=0
NON_INTERACTIVE=0
DRY_RUN=0
SCOPE_OVERRIDE=""  # --scope project|user (B1)
ADOPT=0            # --adopt: import existing on-disk layout into .seamos-context.json (TODO 8)
FORCE=0            # --force: allow overwrite on existing context / SSOT mismatch (adopt only)
UPDATE_GITIGNORE=0 # --update-gitignore: opt-in gitignore mutation (adopt only); default OFF

usage() {
  cat <<EOF
Usage: setup.sh [options]

One-time SeamOS workspace bootstrap. Writes .seamos-workspace.json (and, in
project scope, .mcp.json) plus seamos-assets/{builds,screenshots}/. Idempotent.

Options:
  --workspace-dir <path>        USER_ROOT candidate (default: find-user-root.sh / \$PWD)
  --endpoint <dev|local|<URL>>  Marketplace MCP endpoint (default: dev)
                                  dev   → https://dev.marketplace-api.seamos.io/mcp
                                  local → http://localhost:8088/mcp
                                  <URL> → used verbatim
  --scope <project|user>        Force install scope (overrides auto-detection;
                                useful when the BASH_SOURCE heuristic mis-classifies
                                a plugin cache path as user-scope)
  --reconfigure                 Allow overwrite/merge prompts when files differ
  --non-interactive             Never prompt; defaults applied (skip on conflict)
  --dry-run                     Print intended writes without mutating anything
  --adopt                       Import existing on-disk SeamOS layout into
                                <USER_ROOT>/.seamos-context.json (5 normalized
                                fields). Writes ONLY .seamos-context.json —
                                no other file is touched.
  --force                       (adopt) Permit overwrite of an existing
                                .seamos-context.json and resolve SSOT
                                mismatches by trusting on-disk inference.
  --update-gitignore            (adopt) Opt-in: append SeamOS markers to
                                <USER_ROOT>/.gitignore. Default OFF.
  --help                        Show this help and exit 0

Exit codes:
  0   OK / no-op (idempotent re-run, dry-run, preflight warnings only)
  3   adopt: multiple project candidates on disk (cannot pick <P>)
  4   adopt: layout is neither nested nor flat
  5   adopt: existing .seamos-context.json without --force
  64  usage error (bad args / unresolvable workspace dir)
  65  adopt: SSOT mismatch between context and disk (without --force) OR
      data fault (existing workspace JSON malformed)
  66  adopt: disk inference failed (no com.bosch.fsp.* under USER_ROOT)
  74  reserved for network / IO failures (unused here)

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
    --workspace-dir)
      if [[ $# -lt 2 ]]; then err "--workspace-dir requires a value"; exit 64; fi
      WORKSPACE_DIR="$2"; shift 2 ;;
    --endpoint)
      if [[ $# -lt 2 ]]; then err "--endpoint requires a value"; exit 64; fi
      ENDPOINT_INPUT="$2"; shift 2 ;;
    --reconfigure)     RECONFIGURE=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    --adopt)           ADOPT=1; shift ;;
    --force)           FORCE=1; shift ;;
    --update-gitignore) UPDATE_GITIGNORE=1; shift ;;
    --scope)
      if [[ $# -lt 2 ]]; then err "--scope requires a value"; exit 64; fi
      case "$2" in
        project|user) SCOPE_OVERRIDE="$2" ;;
        *) err "--scope must be 'project' or 'user'"; exit 64 ;;
      esac
      shift 2 ;;
    --help|-h)         usage; exit 0 ;;
    *) err "unknown argument: $1"; usage >&2; exit 64 ;;
  esac
done

# ─── Step 1 — Resolve scope (B1: multi-layer fallback) ─────────────────────
# Priority order:
#   1. --scope explicit override (always wins)
#   2. ~/.claude/installed_plugins.json — authoritative when present
#   3. BASH_SOURCE heuristic, but excluding the plugins/cache subtree which is
#      a local-install download cache, NOT the user-scope install dir
SCOPE=""
SCOPE_REASON=""

if [[ -n "$SCOPE_OVERRIDE" ]]; then
  SCOPE="$SCOPE_OVERRIDE"
  SCOPE_REASON="--scope flag"
fi

if [[ -z "$SCOPE" ]] && command -v jq >/dev/null 2>&1; then
  IPJ="$HOME/.claude/installed_plugins.json"
  if [[ -f "$IPJ" ]]; then
    # The Claude Code plugin registry shape varies across versions; try the
    # known fields. Accept either an object map or an array of plugin records.
    PLUGIN_SCOPE_RAW="$(jq -r '
      def find_seamos:
        if type == "array" then
          map(select(.name == "seamos-everywhere" or .pluginName == "seamos-everywhere")) | first
        elif type == "object" then
          (.plugins // {}) as $p
          | if ($p | type) == "array"
              then $p | map(select(.name == "seamos-everywhere" or .pluginName == "seamos-everywhere")) | first
              else $p["seamos-everywhere"] // empty
            end
        else empty end;
      (find_seamos // {}) | (.scope // .installScope // .installLocation // "")
    ' "$IPJ" 2>/dev/null || echo "")"
    case "$PLUGIN_SCOPE_RAW" in
      user|global)         SCOPE="user";    SCOPE_REASON="installed_plugins.json:$PLUGIN_SCOPE_RAW" ;;
      project|local|repo)  SCOPE="project"; SCOPE_REASON="installed_plugins.json:$PLUGIN_SCOPE_RAW" ;;
    esac
  fi
fi

if [[ -z "$SCOPE" ]]; then
  case "${BASH_SOURCE[0]}" in
    */.claude/plugins/cache/*) SCOPE="project"; SCOPE_REASON="bash-source:cache (local install)" ;;
    */.claude/plugins/*)       SCOPE="user";    SCOPE_REASON="bash-source:user-plugins" ;;
    *)                         SCOPE="project"; SCOPE_REASON="bash-source:other" ;;
  esac
fi

log "[scope] $SCOPE ($SCOPE_REASON)"

# ─── Step 2 — Resolve USER_ROOT ────────────────────────────────────────────
resolve_realpath() {
  # macOS bash 3.2 compatible absolute path resolution.
  local p="$1"
  ( cd "$p" && pwd -P )
}

if [[ -n "$WORKSPACE_DIR" ]]; then
  if [[ ! -d "$WORKSPACE_DIR" ]]; then
    if ! mkdir -p "$WORKSPACE_DIR" 2>/dev/null; then
      err "--workspace-dir does not exist and could not be created: $WORKSPACE_DIR"
      exit 64
    fi
  fi
  USER_ROOT="$(resolve_realpath "$WORKSPACE_DIR")" || {
    err "failed to resolve absolute path for --workspace-dir: $WORKSPACE_DIR"; exit 64; }
elif [[ -f "$SHARED_FIND_USER_ROOT" ]] && \
     USER_ROOT_TRY="$(SEAMOS_ALLOW_PWD_FALLBACK=0 bash "$SHARED_FIND_USER_ROOT" 2>/dev/null)" && \
     [[ -n "$USER_ROOT_TRY" ]]; then
  USER_ROOT="$USER_ROOT_TRY"
else
  warn "no --workspace-dir given and no marker found — falling back to \$PWD"
  USER_ROOT="$(pwd -P)"
fi
log "[user-root] $USER_ROOT"

# ─── --adopt mode (TODO 8) ────────────────────────────────────────────────
# Writes ONLY <USER_ROOT>/.seamos-context.json. Every other file on disk is
# treated as read-only. Exits before reaching the default-mode write blocks
# (.mcp.json / .seamos-workspace.json / seamos-assets/).
if [[ $ADOPT -eq 1 ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    err "jq is required for --adopt"
    exit 65
  fi

  CTX_FILE="$USER_ROOT/.seamos-context.json"

  # --- Step A1: disk inference (read-only) -----------------------------------
  # Finds com.bosch.fsp.<P> under USER_ROOT (depth ≤ 3), determines layout,
  # locates SDK/APP/customui paths. Mirrors resolve-paths.sh logic but kept
  # local so we can distinguish "disk truth" from "context truth" for the
  # mismatch check below.
  ADOPT_FSP_DIR=""
  ADOPT_PROJECT=""
  ADOPT_LAYOUT=""
  ADOPT_WORKSPACE=""
  ADOPT_FSP=""
  ADOPT_SDK=""
  ADOPT_APP=""
  ADOPT_DEEP=""
  ADOPT_CUI=""

  # Locate fsp dirs (could be more than one → error)
  FSP_MATCHES="$(find "$USER_ROOT" -maxdepth 3 -type d -name 'com.bosch.fsp.*' 2>/dev/null)"
  FSP_COUNT="$(printf '%s\n' "$FSP_MATCHES" | grep -c . || true)"
  if [[ "$FSP_COUNT" == "0" ]]; then
    err "no com.bosch.fsp.* directory found under $USER_ROOT — cannot infer project"
    exit 66
  fi
  if [[ "$FSP_COUNT" -gt 1 ]]; then
    err "multiple com.bosch.fsp.* candidates under $USER_ROOT — refuse to guess <P>:"
    printf '%s\n' "$FSP_MATCHES" >&2
    exit 3
  fi
  ADOPT_FSP_DIR="$(printf '%s' "$FSP_MATCHES" | head -1)"
  ADOPT_FSP="$(cd "$ADOPT_FSP_DIR" && pwd -P)"
  ADOPT_PROJECT="$(basename "$ADOPT_FSP")"
  ADOPT_PROJECT="${ADOPT_PROJECT#com.bosch.fsp.}"

  # Layout determination — see resolve-paths.sh for the same rules:
  #   flat   → parent(fsp) == USER_ROOT
  #   nested → parent(fsp) is two levels under USER_ROOT and a sibling
  #            .metadata dir exists at the workspace level
  ADOPT_FSP_PARENT="$(dirname "$ADOPT_FSP")"
  if [[ "$ADOPT_FSP_PARENT" == "$USER_ROOT" ]]; then
    ADOPT_LAYOUT="flat"
    ADOPT_WORKSPACE="$USER_ROOT"
  elif [[ "$(dirname "$ADOPT_FSP_PARENT")" != "$USER_ROOT" ]] && \
       [[ -d "$(dirname "$ADOPT_FSP_PARENT")/.metadata" ]]; then
    ADOPT_LAYOUT="nested"
    ADOPT_WORKSPACE="$(dirname "$ADOPT_FSP_PARENT")"
  else
    err "layout is neither nested nor flat — fsp at $ADOPT_FSP under $USER_ROOT"
    exit 4
  fi

  # SDK / APP discovery within fsp-parent
  ADOPT_WS_DIR="$ADOPT_FSP_PARENT"
  ADOPT_SDK_CANDIDATE=""
  ADOPT_APP_CANDIDATE=""
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    base="$(basename "$d")"
    case "$base" in
      "${ADOPT_PROJECT}_CPP_SDK"|"${ADOPT_PROJECT}_SDK")
        [[ -z "$ADOPT_SDK_CANDIDATE" ]] && ADOPT_SDK_CANDIDATE="$d"
        ;;
      "${ADOPT_PROJECT}_"*)
        if [[ -z "$ADOPT_APP_CANDIDATE" ]]; then
          ADOPT_APP_CANDIDATE="$d"
        fi
        ;;
    esac
  done < <(find "$ADOPT_WS_DIR" -maxdepth 1 -mindepth 1 -type d -name "${ADOPT_PROJECT}_*" 2>/dev/null)

  if [[ -z "$ADOPT_SDK_CANDIDATE" ]]; then
    err "SDK directory (${ADOPT_PROJECT}_CPP_SDK or ${ADOPT_PROJECT}_SDK) not found in $ADOPT_WS_DIR"
    exit 66
  fi
  if [[ -z "$ADOPT_APP_CANDIDATE" ]]; then
    err "APP directory (${ADOPT_PROJECT}_*) not found in $ADOPT_WS_DIR"
    exit 66
  fi

  ADOPT_SDK="$(cd "$ADOPT_SDK_CANDIDATE" && pwd -P)"
  ADOPT_APP="$(cd "$ADOPT_APP_CANDIDATE" && pwd -P)"
  ADOPT_DEEP="$ADOPT_APP/ui"

  if [[ -d "$ADOPT_WORKSPACE/customui-src" ]]; then
    ADOPT_CUI="$(cd "$ADOPT_WORKSPACE/customui-src" && pwd -P)"
  else
    ADOPT_CUI=""
  fi

  log "[adopt] layout=$ADOPT_LAYOUT project=$ADOPT_PROJECT workspace=$ADOPT_WORKSPACE"

  # --- Step A2: existing-context handling -----------------------------------
  # If .seamos-context.json exists:
  #   - read its 5 normalized fields (if all present), compare to disk-inferred
  #     values. Any difference → SSOT mismatch.
  #   - without --force: exit 5 on bare existence, exit 65 on detected mismatch
  #   - with --force: proceed and let disk truth win
  if [[ -f "$CTX_FILE" ]]; then
    if [[ $FORCE -ne 1 ]]; then
      # Check whether 5 fields exist + match disk truth. If 1+ fields missing →
      # treat as a generic existing-context conflict (exit 5).
      CTX_FSP="$(jq -r '.last_project.fsp_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
      CTX_SDK="$(jq -r '.last_project.sdk_project_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
      CTX_APP="$(jq -r '.last_project.app_project_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
      CTX_DEEP="$(jq -r '.last_project.deep_ui_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
      CTX_CUI_KEY_PRESENT="$(jq -r 'if (.last_project | has("customui_src_path")) then "1" else "0" end' "$CTX_FILE" 2>/dev/null || echo "0")"
      CTX_CUI_RAW="$(jq -r '.last_project.customui_src_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
      for v in CTX_FSP CTX_SDK CTX_APP CTX_DEEP CTX_CUI_RAW; do
        eval "if [[ \"\${$v}\" == \"null\" ]]; then $v=\"\"; fi"
      done
      if [[ -z "$CTX_FSP" || -z "$CTX_SDK" || -z "$CTX_APP" || -z "$CTX_DEEP" || "$CTX_CUI_KEY_PRESENT" != "1" ]]; then
        err "existing .seamos-context.json present (partial 5-field set) — pass --force to overwrite from disk"
        exit 5
      fi
      # 5 fields complete — verify each against disk truth
      MISMATCH_REASONS=""
      if [[ "$CTX_FSP"  != "$ADOPT_FSP"  ]]; then MISMATCH_REASONS="$MISMATCH_REASONS fsp_path(ctx=$CTX_FSP disk=$ADOPT_FSP)"; fi
      if [[ "$CTX_SDK"  != "$ADOPT_SDK"  ]]; then MISMATCH_REASONS="$MISMATCH_REASONS sdk_project_path(ctx=$CTX_SDK disk=$ADOPT_SDK)"; fi
      if [[ "$CTX_APP"  != "$ADOPT_APP"  ]]; then MISMATCH_REASONS="$MISMATCH_REASONS app_project_path(ctx=$CTX_APP disk=$ADOPT_APP)"; fi
      if [[ "$CTX_DEEP" != "$ADOPT_DEEP" ]]; then MISMATCH_REASONS="$MISMATCH_REASONS deep_ui_path(ctx=$CTX_DEEP disk=$ADOPT_DEEP)"; fi
      if [[ "$CTX_CUI_RAW" != "$ADOPT_CUI" ]]; then
        MISMATCH_REASONS="$MISMATCH_REASONS customui_src_path(ctx=${CTX_CUI_RAW:-null} disk=${ADOPT_CUI:-null})"
      fi
      if [[ -n "$MISMATCH_REASONS" ]]; then
        err "SSOT mismatch between .seamos-context.json and on-disk layout — re-run with --force to trust disk:$MISMATCH_REASONS"
        exit 65
      fi
      # 5 fields match disk exactly → no-op (idempotent)
      log "[adopt] .seamos-context.json already matches disk — no write needed"
      exit 0
    fi
    # --force path: emit a partial-context warning if applicable, then proceed
    # to overwrite below.
    CTX_FSP="$(jq -r '.last_project.fsp_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
    CTX_SDK="$(jq -r '.last_project.sdk_project_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
    CTX_APP="$(jq -r '.last_project.app_project_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
    CTX_DEEP="$(jq -r '.last_project.deep_ui_path // ""' "$CTX_FILE" 2>/dev/null || echo "")"
    CTX_CUI_KEY_PRESENT="$(jq -r 'if (.last_project | has("customui_src_path")) then "1" else "0" end' "$CTX_FILE" 2>/dev/null || echo "0")"
    for v in CTX_FSP CTX_SDK CTX_APP CTX_DEEP; do
      eval "if [[ \"\${$v}\" == \"null\" ]]; then $v=\"\"; fi"
    done
    if [[ -z "$CTX_FSP" || -z "$CTX_SDK" || -z "$CTX_APP" || -z "$CTX_DEEP" || "$CTX_CUI_KEY_PRESENT" != "1" ]]; then
      warn "partial .seamos-context.json — re-inferring all 5 fields from disk (--force)"
    fi
  fi

  # --- Step A3: build payload ----------------------------------------------
  if [[ -n "$ADOPT_CUI" ]]; then
    CUI_JSON_ARG=(--arg customui_src_path "$ADOPT_CUI")
    CUI_JQ_EXPR='customui_src_path:$customui_src_path'
  else
    CUI_JSON_ARG=()
    CUI_JQ_EXPR='customui_src_path:null'
  fi

  NORMALIZED_PAYLOAD="$(jq -n \
    --arg name "$ADOPT_PROJECT" \
    --arg workspace_path "$ADOPT_WORKSPACE" \
    --arg layout_kind "$ADOPT_LAYOUT" \
    --arg fsp_path "$ADOPT_FSP" \
    --arg sdk_project_path "$ADOPT_SDK" \
    --arg app_project_path "$ADOPT_APP" \
    --arg deep_ui_path "$ADOPT_DEEP" \
    "${CUI_JSON_ARG[@]}" \
    "{name:\$name, workspace_path:\$workspace_path, layout_kind:\$layout_kind, fsp_path:\$fsp_path, sdk_project_path:\$sdk_project_path, app_project_path:\$app_project_path, deep_ui_path:\$deep_ui_path, $CUI_JQ_EXPR}")"

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would write 5 normalized fields to $CTX_FILE:"
    printf '%s\n' "$NORMALIZED_PAYLOAD"
    exit 0
  fi

  # --- Step A4: atomic write -----------------------------------------------
  # Merge into any existing top-level keys but replace last_project entirely
  # with the new normalized payload.
  TMP="${CTX_FILE}.tmp.$$"
  if [[ -f "$CTX_FILE" ]]; then
    jq --argjson p "$NORMALIZED_PAYLOAD" '.last_project = $p' "$CTX_FILE" > "$TMP"
  else
    jq -n --argjson p "$NORMALIZED_PAYLOAD" '{last_project:$p}' > "$TMP"
  fi
  mv "$TMP" "$CTX_FILE"
  log "context 5필드를 기록했습니다 ($CTX_FILE)"

  # --- Step A5: optional .gitignore (opt-in) -------------------------------
  if [[ $UPDATE_GITIGNORE -eq 1 ]]; then
    GI="$USER_ROOT/.gitignore"
    if ! grep -qxF ".seamos-context.json" "$GI" 2>/dev/null; then
      printf '\n# SeamOS workspace state\n.seamos-context.json\n' >> "$GI"
      log "[write] $GI (.seamos-context.json appended)"
    fi
  fi

  exit 0
fi

# ─── Endpoint resolution ───────────────────────────────────────────────────
ENDPOINT_NAME="$ENDPOINT_INPUT"
case "$ENDPOINT_INPUT" in
  dev)
    ENDPOINT_URL="https://dev.marketplace-api.seamos.io/mcp" ;;
  local)
    ENDPOINT_URL="http://localhost:8088/mcp" ;;
  *)
    ENDPOINT_URL="$ENDPOINT_INPUT"
    ENDPOINT_NAME="custom" ;;
esac
log "[endpoint] $ENDPOINT_NAME ($ENDPOINT_URL)"

# ─── Step 3 — Bootstrap seamos-assets/ ─────────────────────────────────────
ASSETS_BUILDS="$USER_ROOT/seamos-assets/builds"
ASSETS_SHOTS="$USER_ROOT/seamos-assets/screenshots"
if [[ -d "$ASSETS_BUILDS" && -d "$ASSETS_SHOTS" ]]; then
  log "[skip] seamos-assets already bootstrapped"
else
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would create $ASSETS_BUILDS and $ASSETS_SHOTS"
  else
    mkdir -p "$ASSETS_BUILDS" "$ASSETS_SHOTS"
    log "[write] $ASSETS_BUILDS"
    log "[write] $ASSETS_SHOTS"
  fi
fi

# ─── Step 4 — .mcp.json (project scope only) ───────────────────────────────
write_mcp_json_project() {
  local target="$USER_ROOT/.mcp.json"

  if [[ ! -f "$TEMPLATE_MCP_JSON" ]]; then
    err ".mcp.json template not found: $TEMPLATE_MCP_JSON"
    exit 65
  fi

  # Build the substituted JSON. Use python-free sed; URLs may contain '/', so use '|'.
  # The marketplace backend authenticates via OAuth (PKCE) on the first MCP call —
  # no API key collection at setup time.
  local rendered
  rendered="$(sed -e "s|{ENDPOINT_URL}|$ENDPOINT_URL|g" "$TEMPLATE_MCP_JSON")"

  if [[ -f "$target" ]]; then
    # Detect deprecated key.
    if command -v jq >/dev/null 2>&1; then
      if jq -e '.mcpServers["sdm-marketplace"]' "$target" >/dev/null 2>&1; then
        warn "deprecated 'sdm-marketplace' detected — manual rename to 'seamos-marketplace' recommended (see references/mcp-template.md Migration section)"
      fi
    fi

    local equal=0
    if command -v jq >/dev/null 2>&1; then
      local existing_norm new_norm
      if existing_norm="$(jq -S '.mcpServers["seamos-marketplace"]' "$target" 2>/dev/null)" && \
         new_norm="$(printf '%s' "$rendered" | jq -S '.mcpServers["seamos-marketplace"]' 2>/dev/null)"; then
        if [[ "$existing_norm" == "$new_norm" && -n "$existing_norm" && "$existing_norm" != "null" ]]; then
          equal=1
        fi
      fi
    fi

    if [[ $equal -eq 1 ]]; then
      log "[skip] .mcp.json already configured"
      return 0
    fi

    if [[ $RECONFIGURE -ne 1 ]]; then
      log "[skip] .mcp.json exists with different content — pass --reconfigure to update"
      return 0
    fi

    # --reconfigure path
    local choice="s"
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      log "[skip] non-interactive + --reconfigure — defaulting to skip"
      return 0
    fi
    if [[ -t 0 ]]; then
      printf '(o)verwrite / (m)erge / (s)kip [s]: '
      read -r choice || choice="s"
      [[ -z "$choice" ]] && choice="s"
      # lowercase via tr (bash 3.2 safe)
      choice="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"
    fi

    case "$choice" in
      o|overwrite)
        if [[ $DRY_RUN -eq 1 ]]; then
          log "[dry-run] would overwrite $target"
        else
          printf '%s\n' "$rendered" > "$target"
          log "[write] $target (overwrite)"
        fi
        ;;
      m|merge)
        if ! command -v jq >/dev/null 2>&1; then
          warn "jq not found — falling back to skip on merge"
          log "[skip] .mcp.json merge unavailable without jq"
          return 0
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
          log "[dry-run] would merge seamos-marketplace entry into $target"
        else
          local merged
          merged="$(jq -s '.[0] * {mcpServers: ((.[0].mcpServers // {}) * .[1].mcpServers)}' \
                      "$target" <(printf '%s' "$rendered"))"
          printf '%s\n' "$merged" > "$target"
          log "[write] $target (merge)"
        fi
        ;;
      *)
        log "[skip] .mcp.json kept as-is"
        ;;
    esac
    return 0
  fi

  # Fresh write.
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would write $target"
  else
    printf '%s\n' "$rendered" > "$target"
    log "[write] $target"
  fi
}

if [[ "$SCOPE" == "user" ]]; then
  log "[user-scope] skipping .mcp.json — plugin auto-registers MCP via mcp-servers.json"
else
  write_mcp_json_project
fi

# Tracks whether write_workspace_json found stale ui.react.templateRef='main'
# without auto-migrating (caller didn't pass --reconfigure). Surfaced in Step 8.
STALE_TEMPLATE_REF_DETECTED=0

# ─── Step 5 — .seamos-workspace.json ───────────────────────────────────────
write_workspace_json() {
  local target="$USER_ROOT/.seamos-workspace.json"

  if ! command -v jq >/dev/null 2>&1; then
    err "jq is required to write .seamos-workspace.json — install jq and re-run"
    exit 65
  fi

  local created_at
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local new_json
  new_json="$(jq -n \
    --arg createdAt "$created_at" \
    --arg scope "$SCOPE" \
    --arg endpoint "$ENDPOINT_NAME" \
    --arg endpointUrl "$ENDPOINT_URL" \
    '{schemaVersion:1, createdAt:$createdAt, scope:$scope,
      ui:{defaultFramework:null, activeSrcPath:null,
          react:{templateRepo:"https://github.com/AGMO-Inc/custom-ui-react-template", templateRef:"master"}},
      marketplace:{endpoint:$endpoint, endpointUrl:$endpointUrl}}')"

  if [[ -f "$target" ]]; then
    # Validate JSON.
    if ! jq -e . "$target" >/dev/null 2>&1; then
      err "STATUS_ERR: existing .seamos-workspace.json is invalid JSON — back up or delete it manually" >&2
      log "STATUS_ERR: invalid existing .seamos-workspace.json"
      exit 65
    fi

    local existing_version
    existing_version="$(jq -r '.schemaVersion // empty' "$target" 2>/dev/null || echo "")"

    if [[ "$existing_version" == "1" ]]; then
      # A4: detect stale ui.react.templateRef == "main" left over from 0.7.0/0.7.1.
      # The custom-ui-react-template default branch is `master`, so a stale
      # `main` reference makes init-customui's git clone fail.
      local existing_ref
      existing_ref="$(jq -r '.ui.react.templateRef // empty' "$target" 2>/dev/null || echo "")"
      local stale_template_ref=0
      if [[ "$existing_ref" == "main" ]]; then
        stale_template_ref=1
        warn "stale .seamos-workspace.json detected: ui.react.templateRef='main' (template repo default is 'master'). Pass --reconfigure to migrate."
        STALE_TEMPLATE_REF_DETECTED=1
      fi

      if [[ $RECONFIGURE -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          log "[dry-run] would merge new endpoint values into $target"
          if [[ $stale_template_ref -eq 1 ]]; then
            log "[dry-run] would migrate ui.react.templateRef: 'main' → 'master'"
          fi
        else
          local merged
          # Always rewrite endpoint; conditionally migrate templateRef.
          if [[ $stale_template_ref -eq 1 ]]; then
            merged="$(jq --arg endpoint "$ENDPOINT_NAME" --arg endpointUrl "$ENDPOINT_URL" \
              '.marketplace.endpoint=$endpoint | .marketplace.endpointUrl=$endpointUrl
               | .ui.react.templateRef="master"' \
              "$target")"
            log "[migrate] ui.react.templateRef: 'main' → 'master'"
            STALE_TEMPLATE_REF_DETECTED=0  # migrated this run, clear flag
          else
            merged="$(jq --arg endpoint "$ENDPOINT_NAME" --arg endpointUrl "$ENDPOINT_URL" \
              '.marketplace.endpoint=$endpoint | .marketplace.endpointUrl=$endpointUrl' \
              "$target")"
          fi
          # A3: ensure .marketplace.{endpoint,endpointUrl} exist for both scopes
          # (upload-app's URL discovery prefers this over .mcp.json).
          printf '%s\n' "$merged" > "$target"
          log "[write] $target (reconfigure merge)"
        fi
      else
        log "[skip] .seamos-workspace.json already present"
      fi
      return 0
    fi

    # schemaVersion mismatch → back up + write fresh.
    local backup_path
    backup_path="${target}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "[dry-run] would backup $target → $backup_path and write fresh"
    else
      mv "$target" "$backup_path"
      log "[backup] $backup_path"
      printf '%s\n' "$new_json" > "$target"
      log "[write] $target (schemaVersion upgrade)"
    fi
    return 0
  fi

  # Fresh write.
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would write $target"
  else
    printf '%s\n' "$new_json" > "$target"
    log "[write] $target"
  fi
}

write_workspace_json

# ─── Step 6 — Preflight (non-blocking) ─────────────────────────────────────
PREFLIGHT_MISSING=()

install_hint() {
  local tool="$1"
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  case "$uname_s" in
    Darwin)
      case "$tool" in
        docker)               echo "brew install --cask docker" ;;
        jq)                   echo "brew install jq" ;;
        shasum|sha256sum)     echo "shasum (built-in on macOS); for Linux parity: brew install coreutils" ;;
        timeout|gtimeout)     echo "brew install coreutils (provides gtimeout)" ;;
        *)                    echo "brew install $tool" ;;
      esac
      ;;
    Linux)
      case "$tool" in
        docker)               echo "follow https://docs.docker.com/engine/install/ for your distro" ;;
        jq)                   echo "apt install jq  # or  dnf install jq" ;;
        shasum|sha256sum)     echo "apt install coreutils  # provides sha256sum" ;;
        timeout|gtimeout)     echo "apt install coreutils  # provides timeout" ;;
        *)                    echo "apt install $tool  # or your distro equivalent" ;;
      esac
      ;;
    *)
      echo "install $tool via your platform's package manager"
      ;;
  esac
}

check_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    PREFLIGHT_MISSING+=("$tool")
    warn "$tool not found — install: $(install_hint "$tool")"
  fi
}

check_tool docker
check_tool jq

# shasum or sha256sum (either is fine).
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  PREFLIGHT_MISSING+=("shasum")
  warn "shasum / sha256sum not found — install: $(install_hint shasum)"
fi

# timeout or gtimeout (either is fine).
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
  PREFLIGHT_MISSING+=("timeout")
  warn "timeout / gtimeout not found — install: $(install_hint timeout)"
fi

# ─── Step 7 — User-scope MCP guidance ──────────────────────────────────────
# As of v0.7.5 the plugin's mcp-servers.json embeds the dev marketplace URL
# directly (no userConfig dependency). Plugin install is zero-config:
# the seamos-marketplace MCP server registers and works on first launch
# regardless of scope. setup writes a project-scope .mcp.json only when the
# user picked an endpoint other than dev, so the project-scope entry can
# override the plugin's default.
if [[ "$SCOPE" == "user" ]]; then
  log "[user-scope] MCP server registered by plugin (mcp-servers.json, dev URL embedded)."
  log "[user-scope] Verify with /mcp in Claude Code. The first marketplace tool call opens a browser for one-time SeamOS login (OAuth)."
fi

# ─── Step 8 — Final status ─────────────────────────────────────────────────
WARN_REASONS=()
if [[ ${#PREFLIGHT_MISSING[@]} -gt 0 ]]; then
  WARN_REASONS+=("preflight tools missing (${PREFLIGHT_MISSING[*]})")
fi
if [[ $STALE_TEMPLATE_REF_DETECTED -eq 1 ]]; then
  WARN_REASONS+=("stale .seamos-workspace.json templateRef='main' — re-run with --reconfigure to migrate")
fi

if [[ ${#WARN_REASONS[@]} -gt 0 ]]; then
  # Join with '; ' for one machine-parseable line.
  IFS='; ' joined="${WARN_REASONS[*]}"
  log "STATUS_WARN: ${joined}"
  exit 0
fi

log "STATUS_OK"
exit 0
