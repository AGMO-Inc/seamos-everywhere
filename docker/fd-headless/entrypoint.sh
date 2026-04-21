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

# Required: FD_INTERFACE_JSON
: "${FD_INTERFACE_JSON:?FD_INTERFACE_JSON environment variable is required}"

# Defaults
: "${FD_WORKSPACE:=/workspace}"
: "${FD_PROJECT_NAME:=PrototypeProject}"
: "${FD_UI_TYPE:=Custom UI}"
: "${FD_OPERATION:=GENERATE_FSP}"

# Load single-source-of-truth FD CLI args
# fd-args.sh populates the FD_ARGS bash array using the env vars above
# (including FD_CONFIG_DIR for -configuration).
# shellcheck disable=SC1091
source /opt/fd/fd-args.sh

echo "=== FD Headless (Linux) ==="
echo "Workspace       : ${FD_WORKSPACE}"
echo "Interface JSON  : ${FD_INTERFACE_JSON}"
echo "Operation       : ${FD_OPERATION}"
echo "Project Name    : ${FD_PROJECT_NAME}"
echo "UI Type         : ${FD_UI_TYPE}"
echo "Config Dir      : ${FD_CONFIG_DIR}"
echo "FD_ARGS         : ${FD_ARGS[*]}"
echo "==========================="

exec /opt/fd/FD_Headless "${FD_ARGS[@]}"
