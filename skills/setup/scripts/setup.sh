#!/usr/bin/env bash
# setup.sh — SeamOS workspace bootstrap (idempotent).
# Implements Execution Flow described in skills/setup/SKILL.md (8 steps).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SHARED_FIND_USER_ROOT="$SCRIPT_DIR/../../shared-references/scripts/find-user-root.sh"
TEMPLATE_MCP_JSON="$SKILL_DIR/assets/.mcp.json.template"

# ─── Defaults / args ───────────────────────────────────────────────────────
WORKSPACE_DIR=""
ENDPOINT_INPUT="dev"
RECONFIGURE=0
NON_INTERACTIVE=0
DRY_RUN=0

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
  --reconfigure                 Allow overwrite/merge prompts when files differ
  --non-interactive             Never prompt; defaults applied (skip on conflict)
  --dry-run                     Print intended writes without mutating anything
  --help                        Show this help and exit 0

Exit codes:
  0   OK / no-op (idempotent re-run, dry-run, preflight warnings only)
  64  usage error (bad args / unresolvable workspace dir)
  65  data fault (existing workspace JSON malformed)
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
    --help|-h)         usage; exit 0 ;;
    *) err "unknown argument: $1"; usage >&2; exit 64 ;;
  esac
done

# ─── Step 1 — Resolve scope ────────────────────────────────────────────────
case "${BASH_SOURCE[0]}" in
  */.claude/plugins/*) SCOPE=user ;;
  *)                   SCOPE=project ;;
esac
log "[scope] $SCOPE"

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

  # API key prompt.
  local api_key=""
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    log "[skip] api key not provided — placeholder kept"
  else
    # POSIX read; macOS bash 3.2 compatible.
    if [[ -t 0 ]]; then
      printf 'Enter SeamOS marketplace API key (leave blank to keep placeholder): '
      read -r api_key || api_key=""
    else
      log "[skip] non-tty — api key prompt skipped, placeholder kept"
    fi
  fi

  # Build the substituted JSON. Use python-free sed; URLs may contain '/', so use '|'.
  local rendered
  if [[ -z "$api_key" ]]; then
    rendered="$(sed -e "s|{ENDPOINT_URL}|$ENDPOINT_URL|g" "$TEMPLATE_MCP_JSON")"
  else
    rendered="$(sed -e "s|{ENDPOINT_URL}|$ENDPOINT_URL|g" \
                    -e "s|{API_KEY}|$api_key|g" "$TEMPLATE_MCP_JSON")"
  fi

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
          react:{templateRepo:"https://github.com/AGMO-Inc/custom-ui-react-template", templateRef:"main"}},
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
      if [[ $RECONFIGURE -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          log "[dry-run] would merge new endpoint values into $target"
        else
          local merged
          merged="$(jq --arg endpoint "$ENDPOINT_NAME" --arg endpointUrl "$ENDPOINT_URL" \
            '.marketplace.endpoint=$endpoint | .marketplace.endpointUrl=$endpointUrl' \
            "$target")"
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
if [[ "$SCOPE" == "user" ]]; then
  log "[user-scope] MCP server is auto-registered via plugin mcp-servers.json + userConfig."
  log "[user-scope] If 'mcp__seamos-marketplace__*' tools are not visible, run /mcp in Claude Code to verify, or set seamos_api_key in plugin settings."
fi

# ─── Step 8 — Final status ─────────────────────────────────────────────────
if [[ ${#PREFLIGHT_MISSING[@]} -gt 0 && $NON_INTERACTIVE -eq 1 ]]; then
  log "STATUS_WARN: preflight tools missing (${PREFLIGHT_MISSING[*]})"
  exit 0
fi

if [[ ${#PREFLIGHT_MISSING[@]} -gt 0 ]]; then
  log "STATUS_WARN: preflight tools missing (${PREFLIGHT_MISSING[*]})"
  exit 0
fi

log "STATUS_OK"
exit 0
