#!/bin/bash
# Linux-native entrypoint for FD Headless.
# NOTE: xvfb-run fallback will be added here if CI prototype run reports
#   GTK initialization failure (IMPORTANT-1, conditional).
set -euo pipefail

# Eclipse RCP state determinism
export HOME=/tmp/fd-home
export TMPDIR=/tmp
export FD_CONFIG_DIR=/tmp/fd-config
mkdir -p "${HOME}" "${FD_CONFIG_DIR}"

# Defaults
: "${FD_WORKSPACE:=/workspace}"
: "${FD_OPERATION:=GENERATE_FSP}"

# Operation-aware required variable check
case "${FD_OPERATION}" in
  GENERATE_FSP)
    : "${FD_INTERFACE_JSON:?FD_INTERFACE_JSON environment variable is required for GENERATE_FSP}"
    : "${FD_PROJECT_NAME:=PrototypeProject}"
    : "${FD_UI_TYPE:=Custom UI}"
    ;;
  GENERATE_SDK_APP|UPDATE_SDK_APP)
    : "${FD_CONFIG_PROP:?FD_CONFIG_PROP environment variable is required for ${FD_OPERATION}}"
    ;;
esac

# Load single-source-of-truth FD CLI args
# fd-args.sh populates the FD_ARGS bash array using the env vars above
# (including FD_CONFIG_DIR for -configuration).
# shellcheck disable=SC1091
source /opt/fd/fd-args.sh

echo "=== FD Headless (Linux) ==="
echo "Workspace       : ${FD_WORKSPACE}"
echo "Operation       : ${FD_OPERATION}"
case "${FD_OPERATION}" in
  GENERATE_FSP)
    echo "Interface JSON  : ${FD_INTERFACE_JSON}"
    echo "Project Name    : ${FD_PROJECT_NAME}"
    echo "UI Type         : ${FD_UI_TYPE}"
    ;;
  GENERATE_SDK_APP|UPDATE_SDK_APP)
    echo "Config Prop     : ${FD_CONFIG_PROP}"
    ;;
esac
echo "Config Dir      : ${FD_CONFIG_DIR}"
echo "FD_ARGS         : ${FD_ARGS[*]}"
echo "==========================="

exec /opt/fd/FD_Headless "${FD_ARGS[@]}"
