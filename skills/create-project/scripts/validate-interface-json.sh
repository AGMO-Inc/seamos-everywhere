#!/bin/bash
# validate-interface-json.sh — Preflight validation for fd_user_selected_interface.json
# before the full FD Headless docker run.
#
# Usage:
#   bash validate-interface-json.sh <interface.json> <offlineDB.json>
#
# Accepts interface.json via path or /dev/stdin (pass "-" as first arg).

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <interface.json> <offlineDB.json>" >&2
  exit 64
fi

IFACE_JSON="$1"
OFFLINEDB_JSON="$2"

if [[ ! -r "$OFFLINEDB_JSON" ]]; then
  echo "ERROR: offlineDB.json not readable: $OFFLINEDB_JSON" >&2
  exit 1
fi

# Load interface JSON (supports /dev/stdin or "-")
if [[ "$IFACE_JSON" == "/dev/stdin" || "$IFACE_JSON" == "-" ]]; then
  IFACE_CONTENT="$(cat)"
else
  [[ -r "$IFACE_JSON" ]] || { echo "ERROR: interface JSON not readable: $IFACE_JSON" >&2; exit 1; }
  IFACE_CONTENT="$(cat "$IFACE_JSON")"
fi

# Validate root is array
if ! echo "$IFACE_CONTENT" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "ERROR: interface JSON root must be an array of {branch,config} objects." >&2
  exit 1
fi

# Collect valid element names from offlineDB top-level elements
ELEMENT_NAMES="$(jq -r '.elements[]?.name // empty' "$OFFLINEDB_JSON" | sort -u)"

# All interfaceName tokens anywhere in the tree (recursive, including childelements)
ALL_IFACE_NAMES="$(jq -r '.. | objects | select(has("interfaceName")) | .interfaceName' "$OFFLINEDB_JSON" | sort -u)"

FAIL=0
N=$(echo "$IFACE_CONTENT" | jq 'length')

for ((i=0; i<N; i++)); do
  BRANCH=$(echo "$IFACE_CONTENT" | jq -r ".[$i].branch // \"\"")
  CONFIG=$(echo "$IFACE_CONTENT" | jq -r ".[$i].config // \"\"")

  if [[ -z "$BRANCH" ]]; then
    echo "branch=<empty> config=\"$CONFIG\" reason=missing_branch" >&2
    FAIL=1
    continue
  fi

  # Split on '/'
  FIRST_TOKEN="${BRANCH%%/*}"
  LAST_TOKEN="${BRANCH##*/}"

  # Check element name (first token) against top-level elements
  if ! grep -qxF "$FIRST_TOKEN" <<<"$ELEMENT_NAMES"; then
    echo "branch=\"$BRANCH\" config=\"$CONFIG\" reason=unknown_element:$FIRST_TOKEN" >&2
    FAIL=1
    continue
  fi

  # Check interfaceName (last token) exists anywhere in the offlineDB tree
  if ! grep -qxF "$LAST_TOKEN" <<<"$ALL_IFACE_NAMES"; then
    echo "branch=\"$BRANCH\" config=\"$CONFIG\" reason=unknown_interface:$LAST_TOKEN" >&2
    FAIL=1
    continue
  fi

  # Config validation
  case "$CONFIG" in
    "" | "Adhoc" | "Adhoc/Cyclic" | "Cyclic" | "Process")
      # Fixed allowed values — pass
      ;;
    *)
      # Allow Cyclic/<N>ms pattern where N is one or more digits
      if ! [[ "$CONFIG" =~ ^Cyclic/[0-9]+ms$ ]]; then
        echo "branch=\"$BRANCH\" config=\"$CONFIG\" reason=invalid_config" >&2
        FAIL=1
        continue
      fi
      ;;
  esac
done

if [[ $FAIL -ne 0 ]]; then
  echo "[validate-interface-json] FAILED ($N entries, errors above)" >&2
  exit 1
fi

echo "[validate-interface-json] OK ($N entries validated)"
exit 0
