#!/bin/bash
# FD Headless CLI args — single source of truth
# Source this file from entrypoint.sh.
# Consumers must define before sourcing:
#   FD_WORKSPACE    (path to -data workspace inside container)
#   FD_OPERATION    (GENERATE_FSP | GENERATE_SDK_APP | UPDATE_SDK_APP)
#
# For GENERATE_FSP:
#   FD_INTERFACE_JSON  (path to interface JSON inside container)
#   FD_PROJECT_NAME
#   FD_UI_TYPE         (always "Custom UI" for this skill)
#
# For GENERATE_SDK_APP | UPDATE_SDK_APP:
#   FD_CONFIG_PROP  (path to config.prop inside container)
#
# Optional (set by entrypoint for Eclipse RCP state determinism):
#   FD_CONFIG_DIR (defaults to /tmp/fd-config)
#
# NOTE: -configuration flag inclusion is based on Windows FD CLI (reference implementation) spec parity.
# A.2 Linux verification timed out (Rosetta 2 amd64 emulation) — could not confirm acceptance.
# If FD errors on -configuration, remove that line and use HOME-based determinism instead:
#   entrypoint sets HOME=/tmp/fd-home

: "${FD_CONFIG_DIR:=/tmp/fd-config}"

FD_ARGS_COMMON=(
  -nosplash
  -data "${FD_WORKSPACE}"
  -consolelog
  -configuration "${FD_CONFIG_DIR}"
  -application com.bosch.fsp.fcal.fd.headless.product.FD_Headless
)

case "${FD_OPERATION}" in
  GENERATE_FSP)
    FD_ARGS=("${FD_ARGS_COMMON[@]}" "${FD_INTERFACE_JSON}" "${FD_OPERATION}" "${FD_PROJECT_NAME}" "${FD_UI_TYPE}")
    ;;
  GENERATE_SDK_APP|UPDATE_SDK_APP)
    FD_ARGS=("${FD_ARGS_COMMON[@]}" "${FD_CONFIG_PROP}" "${FD_OPERATION}")
    ;;
  *)
    echo "ERROR: unsupported FD_OPERATION: ${FD_OPERATION}" >&2
    exit 64
    ;;
esac
