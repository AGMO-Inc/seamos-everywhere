#!/usr/bin/env bash
# resolve-marketplace-url.sh — multi-source marketplace URL discovery for upload-app.
#
# Used by the upload-app skill (Step 1B). Resolves the seamos-marketplace
# base URL (no trailing /mcp) from the first available source in this order:
#
#   1. .seamos-workspace.json -> .marketplace.endpointUrl   (preferred)
#   2. .mcp.json              -> .mcpServers["seamos-marketplace"].url
#   3. CLAUDE_MCP_SEAMOS_URL env var (set by Claude Code when the plugin's
#      mcp-servers.json + userConfig is registered at runtime)
#   4. None of the above → exit 64 with a clear remediation message
#
# All retrieved URLs have any trailing /mcp stripped to yield a base URL like
# "http://localhost:8088" or "https://dev.marketplace-api.seamos.io".
#
# Usage:
#   resolve-marketplace-url.sh <USER_ROOT>
#
# Exit codes:
#   0   resolved successfully — base URL printed to stdout, single line
#   64  no source available — actionable hint printed to stderr
#   65  data fault — workspace file existed but URL field malformed/missing
set -uo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") <USER_ROOT>

Resolve the seamos-marketplace base URL from workspace markers. See header
comment for source priority.
EOF
  exit 64
}

[[ $# -eq 1 ]] || usage
USER_ROOT="$1"
[[ -d "$USER_ROOT" ]] || { echo "ERROR: USER_ROOT not a directory: $USER_ROOT" >&2; exit 64; }

strip_mcp_suffix() {
  # Strip a trailing /mcp (with or without trailing slash) to yield base URL.
  local url="$1"
  url="${url%/}"           # strip trailing /
  url="${url%/mcp}"        # strip /mcp
  printf '%s\n' "$url"
}

# 1) .seamos-workspace.json
WS="$USER_ROOT/.seamos-workspace.json"
if [[ -f "$WS" ]] && command -v jq >/dev/null 2>&1; then
  url="$(jq -r '.marketplace.endpointUrl // empty' "$WS" 2>/dev/null || echo "")"
  if [[ -n "$url" && "$url" != "null" ]]; then
    strip_mcp_suffix "$url"
    exit 0
  fi
fi

# 2) .mcp.json
MJ="$USER_ROOT/.mcp.json"
if [[ -f "$MJ" ]] && command -v jq >/dev/null 2>&1; then
  url="$(jq -r '.mcpServers["seamos-marketplace"].url // empty' "$MJ" 2>/dev/null || echo "")"
  if [[ -n "$url" && "$url" != "null" ]]; then
    strip_mcp_suffix "$url"
    exit 0
  fi
  # Older 0.7.x .mcp.json templates use stdio + npx mcp-remote <URL>; pull the
  # last positional arg from `args` as a best-effort fallback.
  url="$(jq -r '.mcpServers["seamos-marketplace"].args[-1] // empty' "$MJ" 2>/dev/null || echo "")"
  if [[ -n "$url" && "$url" != "null" && "$url" =~ ^https?:// ]]; then
    strip_mcp_suffix "$url"
    exit 0
  fi
fi

# 3) Env var (set by Claude Code when MCP server registered via plugin userConfig)
if [[ -n "${CLAUDE_MCP_SEAMOS_URL:-}" ]]; then
  strip_mcp_suffix "$CLAUDE_MCP_SEAMOS_URL"
  exit 0
fi

# 4) None of the above
cat <<EOF >&2
ERROR: cannot resolve seamos-marketplace URL.

Searched:
  1) $WS (.marketplace.endpointUrl)
  2) $MJ (.mcpServers."seamos-marketplace".url)
  3) \$CLAUDE_MCP_SEAMOS_URL env var

Remediation:
  - If you have not run setup yet:    invoke the \`setup\` skill.
  - If your workspace was created on 0.7.1 (no marketplace.endpointUrl):
                                       invoke \`setup --reconfigure\`.
  - Do NOT hand-author .mcp.json — \`setup\` is the supported entry point.
EOF
exit 64
