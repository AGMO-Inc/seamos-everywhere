#!/bin/bash
# build-config-prop.sh — Write config.prop for FD Headless GENERATE_SDK_APP / UPDATE_SDK_APP.
# Paths written into config.prop are container-internal (/workspace/...).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-config-prop.sh [options]

Options:
  --project-name <name>         FSP project name (required)
  --app-project-name <name>     App project name (default: same as --project-name)
  --codegen-type JAVA|CPP       Code generation type (default: JAVA)
  --process-timer <duration>    app.process.timer value (default: 1s)
  --mvn-args <string>           Maven extra args (default: empty)
  --app-project-path <path>     Existing app project path (UPDATE_SDK_APP only).
                                When set, a `app.project.path=<value>` line is
                                emitted. Omit for GENERATE_SDK_APP.
  --output <path>               Output file path (required)
  --help                        Show this help

Output format for GENERATE_SDK_APP (PDF §3):
  fd.project.path=/workspace/<ProjectName>/com.bosch.fsp.<ProjectName>
  codegen.type=JAVA
  mvn.args=
  app.project.name=<AppName>
  app.skeleton.name=<AppName>
  app.process.timer=1s

Output format for UPDATE_SDK_APP (PDF §4) adds one line:
  fd.project.path=/workspace/<ProjectName>/com.bosch.fsp.<ProjectName>
  app.project.path=/workspace/<ProjectName>/<ProjectName>_<AppName>
  codegen.type=CPP
  ... (rest identical)
EOF
}

PROJECT_NAME=""
APP_PROJECT_NAME=""
CODEGEN_TYPE="JAVA"
PROCESS_TIMER="1s"
MVN_ARGS=""
APP_PROJECT_PATH=""
OUTPUT=""

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 64
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)      PROJECT_NAME="${2:-}"; shift 2 ;;
    --app-project-name)  APP_PROJECT_NAME="${2:-}"; shift 2 ;;
    --codegen-type)      CODEGEN_TYPE="${2:-}"; shift 2 ;;
    --process-timer)     PROCESS_TIMER="${2:-}"; shift 2 ;;
    --mvn-args)          MVN_ARGS="${2:-}"; shift 2 ;;
    --app-project-path)  APP_PROJECT_PATH="${2:-}"; shift 2 ;;
    --output)            OUTPUT="${2:-}"; shift 2 ;;
    --help|-h)           usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: --project-name is required" >&2
  exit 64
fi

if [[ -z "$OUTPUT" ]]; then
  echo "ERROR: --output is required" >&2
  exit 64
fi

# Default app name to project name
[[ -z "$APP_PROJECT_NAME" ]] && APP_PROJECT_NAME="$PROJECT_NAME"

# Validate codegen type
case "$CODEGEN_TYPE" in
  JAVA|CPP) ;;
  *) echo "ERROR: --codegen-type must be JAVA or CPP (got: $CODEGEN_TYPE)" >&2; exit 64 ;;
esac

# Write config.prop — container paths only (fd.project.path uses /workspace/...)
# UPDATE_SDK_APP (PDF §4) requires an extra `app.project.path` line pointing at
# the existing app project; GENERATE_SDK_APP (PDF §3) omits it. We keep a single
# script and switch on --app-project-path.
{
  echo "fd.project.path=/workspace/${PROJECT_NAME}/com.bosch.fsp.${PROJECT_NAME}"
  if [[ -n "$APP_PROJECT_PATH" ]]; then
    echo "app.project.path=${APP_PROJECT_PATH}"
  fi
  echo "codegen.type=${CODEGEN_TYPE}"
  echo "mvn.args=${MVN_ARGS}"
  echo "app.project.name=${APP_PROJECT_NAME}"
  echo "app.skeleton.name=${APP_PROJECT_NAME}"
  echo "app.process.timer=${PROCESS_TIMER}"
} > "$OUTPUT"

echo "[build-config-prop] written: $OUTPUT"
