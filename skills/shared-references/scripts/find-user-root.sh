#!/usr/bin/env bash
# find-user-root.sh — Resolve USER_ROOT by walking up from $PWD looking for a
# project marker file. Prefers .seamos-workspace.json over .mcp.json (back-compat).
#
# Usage:
#   - Source it:   source find-user-root.sh; USER_ROOT="$(find_user_root)"
#   - Execute it:  bash find-user-root.sh
#
# Exit / return codes:
#   0  — USER_ROOT printed to stdout
#   64 — no marker found and SEAMOS_ALLOW_PWD_FALLBACK!=1; error on stderr
set -euo pipefail

# find_user_root — walk up from $PWD looking for .seamos-workspace.json (preferred)
# or .mcp.json (back-compat). Prints USER_ROOT to stdout on success.
find_user_root() {
  local dir
  dir="$(pwd -P)"
  while true; do
    if [[ -f "$dir/.seamos-workspace.json" ]]; then
      echo "$dir"
      return 0
    fi
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
    echo "WARN: no .mcp.json or .seamos-workspace.json found from $PWD upward — using \$PWD as USER_ROOT (SEAMOS_ALLOW_PWD_FALLBACK=1)" >&2
    pwd -P
    return 0
  fi
  echo "ERROR: no .mcp.json or .seamos-workspace.json found from $PWD upward — run 'setup' first or run inside a project that has either marker at its root" >&2
  return 64
}

# CLI mode — only run when this script is executed directly (not sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if find_user_root; then
    exit 0
  else
    exit 64
  fi
fi
