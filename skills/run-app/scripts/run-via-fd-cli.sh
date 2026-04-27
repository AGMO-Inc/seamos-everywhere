#!/usr/bin/env bash
set -euo pipefail

# ─── run-via-fd-cli.sh — host-side wrapper around fd-cli image ────────────
# Delegates build/run/test to the fd-cli Docker image, which (unlike
# app-builder) bakes the NEVONEX Platform Service runtime libs at
# `/workspace/.nevonex/dependencies/<ver>/lib/` and an unmodified GUI FD
# binary at `/opt/nevonex/FeatureDesigner`. The image's
# `/opt/fd-cli/scripts/fd-commands.sh` knows how to:
#
#   build  → cmake + make (C++) or mvn (Java)
#   run    → spawn cpp_app / java JAR with LD_LIBRARY_PATH from .nevonex
#   test   → spawn `com.bosch.nevonex.sdk.test.TestSimulator`
#
# Because the runtime libs live INSIDE the image (not the host or app-builder),
# the cpp_app's IMUProvider register succeeds → ProcessTimer sets up →
# MainController::run() publishes WS frames → diagnose layer 4 PASS.
#
# This script does NOT bake a new image. It assumes `fd-cli` is already
# pullable from FD_CLI_IMAGE (default public.ecr.aws/g0j5z0m9/fd-cli:stable).

LOG_PREFIX="[run-via-fd-cli]"
log() { echo "${LOG_PREFIX} $*"; }
err() { echo "${LOG_PREFIX} [ERROR] $*" >&2; }

# ─── docker PATH resolver (cross-platform; same heuristic as run-app.sh) ───
if [ -n "${DOCKER:-}" ] && [ -x "${DOCKER}" ]; then
  export PATH="$(dirname "${DOCKER}"):${PATH}"
fi
if ! command -v docker >/dev/null 2>&1 && ! command -v docker.exe >/dev/null 2>&1; then
  for CAND in \
    /usr/bin \
    /usr/local/bin \
    /snap/bin \
    /opt/homebrew/bin \
    /Applications/Docker.app/Contents/Resources/bin \
    "/c/Program Files/Docker/Docker/resources/bin" \
    "/mnt/c/Program Files/Docker/Docker/resources/bin"; do
    if [ -x "${CAND}/docker" ] || [ -x "${CAND}/docker.exe" ]; then
      export PATH="${CAND}:${PATH}"
      break
    fi
  done
fi
if ! command -v docker >/dev/null 2>&1 && ! command -v docker.exe >/dev/null 2>&1; then
  err "Docker CLI not found. Install Docker Desktop (macOS/Windows) or docker.io (Linux), or set DOCKER=/path/to/docker."
  exit 127
fi

# ─── Args / env ────────────────────────────────────────────────────────────
APP_NAME="${APP_NAME:-}"
APP_PROJECT_ROOT="${APP_PROJECT_ROOT:-}"
FD_CLI_IMAGE="${FD_CLI_IMAGE:-public.ecr.aws/g0j5z0m9/fd-cli:stable}"
WS_PORT="${WS_PORT:-1456}"
UI_PORT="${UI_PORT:-6563}"
MQTT_PORT="${MQTT_PORT:-1883}"
SKIP_BUILD="${SKIP_BUILD:-0}"
RUNAPP_DRYRUN="${RUNAPP_DRYRUN:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name) APP_NAME="${2:?}"; shift 2;;
    --image)    FD_CLI_IMAGE="${2:?}"; shift 2;;
    --skip-build) SKIP_BUILD=1; shift;;
    --ws-port)  WS_PORT="${2:?}"; shift 2;;
    --ui-port)  UI_PORT="${2:?}"; shift 2;;
    --mqtt-port) MQTT_PORT="${2:?}"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: run-via-fd-cli.sh --app-name <NAME> [--image <IMG>] [--skip-build]
                         [--ws-port N] [--ui-port N] [--mqtt-port N]

Wraps the fd-cli image to build + run + test a SeamOS project locally,
exposing broker (1883), cpp_app WebSocket (1456), and Java UI gateway (6563)
to the host. Unlike run-app.sh's --with-mqtt mode (uses app-builder),
this path includes Platform Service runtime → cpp_app provider register
succeeds → diagnose layer 4 PASS.

Environment overrides: APP_NAME, APP_PROJECT_ROOT, FD_CLI_IMAGE, RUNAPP_DRYRUN

APP_PROJECT_ROOT defaults to \$USER_ROOT/\$APP_NAME/\$APP_NAME.
EOF
      exit 0;;
    *) err "Unknown flag: $1"; exit 64;;
  esac
done

if [ -z "${APP_NAME}" ]; then
  err "APP_NAME required (--app-name <NAME>)"
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
USER_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
APP_PROJECT_ROOT="${APP_PROJECT_ROOT:-${USER_ROOT}/${APP_NAME}/${APP_NAME}}"
APP_NAME_LOWER="$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]')"
CONTAINER_NAME="seamos-fdcli-${APP_NAME_LOWER}"

# fd-cli image bundles only /opt/nevonex/ (FD GUI distro). Its docker-compose
# overlay supplies fd-commands.sh and config via host bind-mounts. We mirror
# that — the canonical scripts live at fd-cli-runtime/scripts/ next to this
# script (scp'd from the upstream fd-cli repo) so we never edit upstream.
FD_CLI_SCRIPTS_HOST="${SKILL_ROOT}/fd-cli-runtime/scripts"
FD_CLI_CONFIG_HOST="${SKILL_ROOT}/fd-cli-runtime/config"
if [ ! -f "${FD_CLI_SCRIPTS_HOST}/fd-commands.sh" ]; then
  err "fd-commands.sh missing at ${FD_CLI_SCRIPTS_HOST}/. Restore from upstream fd-cli repo."
  exit 3
fi

if [ ! -d "${APP_PROJECT_ROOT}" ]; then
  err "APP_PROJECT_ROOT not found: ${APP_PROJECT_ROOT}"
  exit 2
fi

# ─── PLATFORM_ARGS — fd-cli image is linux/amd64 only ─────────────────────
PLATFORM_ARGS=("--platform" "linux/amd64")
if [ -n "${RUNAPP_PLATFORM:-}" ]; then
  PLATFORM_ARGS=("--platform" "${RUNAPP_PLATFORM}")
fi

log "APP_NAME=${APP_NAME}"
log "APP_PROJECT_ROOT=${APP_PROJECT_ROOT}"
log "FD_CLI_IMAGE=${FD_CLI_IMAGE}"
log "CONTAINER_NAME=${CONTAINER_NAME}"
log "PLATFORM_ARGS=${PLATFORM_ARGS[*]}"

# ─── Image pre-flight ──────────────────────────────────────────────────────
if ! docker image inspect "${FD_CLI_IMAGE}" >/dev/null 2>&1; then
  log "Image ${FD_CLI_IMAGE} not present; pulling…"
  if ! docker pull "${PLATFORM_ARGS[@]}" "${FD_CLI_IMAGE}" >/dev/null 2>&1; then
    err "Failed to pull ${FD_CLI_IMAGE}. Check ECR auth (aws ecr-public get-login-password) or set FD_CLI_IMAGE to a local tag."
    exit 4
  fi
fi

# ─── Multi-run guard ───────────────────────────────────────────────────────
if docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  err "Container ${CONTAINER_NAME} already exists. Stop it: docker rm -f ${CONTAINER_NAME}"
  exit 5
fi

# ─── Cleanup trap ──────────────────────────────────────────────────────────
cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap 'cleanup' EXIT INT TERM HUP

# ─── DRYRUN ────────────────────────────────────────────────────────────────
if [ "${RUNAPP_DRYRUN}" = "1" ]; then
  echo "[run-via-fd-cli] DRYRUN: docker run -d --rm ${PLATFORM_ARGS[*]} --name ${CONTAINER_NAME} -v ${APP_PROJECT_ROOT}:/workspace/${APP_NAME} -v ${FD_CLI_SCRIPTS_HOST}:/opt/fd-cli/scripts:ro -v ${FD_CLI_CONFIG_HOST}:/opt/fd-cli/config:ro -p ${WS_PORT}:1456 -p ${UI_PORT}:6563 -p ${MQTT_PORT}:1883 ${FD_CLI_IMAGE} sleep infinity"
  exit 0
fi

# ─── Run container in detached mode ────────────────────────────────────────
# `sleep infinity` keeps the container alive so we can `docker exec` for each
# fd-commands.sh invocation in series (build → run-bg → test-bg). Logs from
# each step are tee'd to host-visible per-step files via /workspace/logs.
log "Starting fd-cli container ${CONTAINER_NAME}…"
# --add-host broker:127.0.0.1 — fd-cli's docker-compose.yml relied on a multi-
# service network alias for the broker. We collapse the broker into the same
# container (single-container model), so feature.config's mqtt:host=tcp://broker
# and connection.props broker=tcp://broker:1883 must resolve to 127.0.0.1.
docker run -d --rm \
  "${PLATFORM_ARGS[@]}" \
  --name "${CONTAINER_NAME}" \
  --add-host "broker:127.0.0.1" \
  -v "${APP_PROJECT_ROOT}:/workspace/${APP_NAME}" \
  -v "${FD_CLI_SCRIPTS_HOST}:/opt/fd-cli/scripts:ro" \
  -v "${FD_CLI_CONFIG_HOST}:/opt/fd-cli/config:ro" \
  -p "${WS_PORT}:1456" \
  -p "${UI_PORT}:6563" \
  -p "${MQTT_PORT}:1883" \
  --entrypoint sleep \
  "${FD_CLI_IMAGE}" \
  infinity >/dev/null

# Readiness probe — wait for image's startup overhead to settle.
for i in $(seq 1 10); do
  if docker exec "${CONTAINER_NAME}" true 2>/dev/null; then
    break
  fi
  sleep 0.3
done

# ─── Pre-extract Platform Service runtime deps ─────────────────────────────
# fd-commands.sh expects ${SDK_DIR}/dependencies/INSTALL_x86_64.tar.xz, but
# SampleImu2's FD-emitted tree uses x86_64.tar.xz (no INSTALL_ prefix). To
# avoid forking upstream, we pre-populate /workspace/.nevonex/dependencies/
# <LIB_BUILD_NUMBER>/lib ourselves — fd-commands.sh's existence check then
# skips its own extraction step.
log "prep: extracting Platform Service runtime deps to /workspace/.nevonex/"
docker exec "${CONTAINER_NAME}" bash -c "
  set -e
  SDK_DIR=/workspace/${APP_NAME}/${APP_NAME}_CPP_SDK
  if [ ! -d \"\$SDK_DIR\" ]; then
    echo '[prep] no CPP_SDK directory; assuming Java project (no native deps)'
    exit 0
  fi
  BN=\$(grep -oP 'set\(LIB_BUILD_NUMBER \"\K[^\"]+' \"\$SDK_DIR/CMakeLists.txt\" 2>/dev/null | head -1)
  if [ -z \"\$BN\" ]; then
    echo '[prep] could not parse LIB_BUILD_NUMBER from CMakeLists.txt'
    exit 0
  fi
  DEPS=/workspace/.nevonex/dependencies/\$BN
  if [ -d \"\$DEPS/lib\" ]; then
    echo \"[prep] deps already extracted at \$DEPS\"
    exit 0
  fi
  mkdir -p \"\$DEPS\"
  for f in \"\$SDK_DIR/dependencies/INSTALL_x86_64.tar.xz\" \"\$SDK_DIR/dependencies/x86_64.tar.xz\"; do
    if [ -f \"\$f\" ]; then
      echo \"[prep] extracting \$f → \$DEPS\"
      xz -dc \"\$f\" | tar xf - -C \"\$DEPS\"
      break
    fi
  done
  if [ ! -d \"\$DEPS/lib\" ]; then
    echo \"[prep] FATAL: extracted but \$DEPS/lib missing — archive layout unexpected\"
    exit 3
  fi
"

# ─── Build (skippable) ─────────────────────────────────────────────────────
if [ "${SKIP_BUILD}" = "0" ]; then
  log "build: docker exec → fd-commands.sh build ${APP_NAME}"
  if ! docker exec "${CONTAINER_NAME}" /opt/fd-cli/scripts/fd-commands.sh build "${APP_NAME}"; then
    err "build failed for ${APP_NAME}"
    exit 6
  fi
fi

# ─── Pre-create directories cpp_app creates lazily ─────────────────────────
# cpp_app's bootstrap calls `boost::filesystem::create_directory("../temp/download/")`
# (relative to its WORKING_DIRECTORY src-gen). The intermediate `temp/` parent
# must already exist or boost throws. fd-commands.sh `run` doesn't pre-create
# this — pre-creating it here matches what the FD GUI launch implicitly does
# by virtue of its "build before launch" hook materializing the project tree.
docker exec "${CONTAINER_NAME}" bash -c "
  mkdir -p /workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/temp/download
"

# ─── Run (background inside container) ─────────────────────────────────────
log "run: spawning cpp_app / Java app in background"
docker exec -d "${CONTAINER_NAME}" bash -c \
  "/opt/fd-cli/scripts/fd-commands.sh run ${APP_NAME} > /workspace/${APP_NAME}-run.log 2>&1"

# Wait for cpp_app to bind WS port (up to 60s; image lacks `ss`/`netstat` so
# probe via `/proc/net/tcp` for hex 0x05B0 = 1456). On Apple Silicon under
# Rosetta the cpp_app cold start can take 30–45s; the 60s ceiling absorbs that.
for i in $(seq 1 120); do
  if docker exec "${CONTAINER_NAME}" bash -c "grep -q ': 0000:05B0 ' /proc/net/tcp 2>/dev/null"; then
    log "cpp_app WS listening on container :1456 (host :${WS_PORT})"
    break
  fi
  sleep 0.5
  if [ "$i" = "120" ]; then
    err "cpp_app WS port 1456 did not open within 60s — see: docker exec ${CONTAINER_NAME} tail /workspace/${APP_NAME}-run.log"
  fi
done

# ─── Test (background inside container) ────────────────────────────────────
log "test: spawning TestSimulator in background"
docker exec -d "${CONTAINER_NAME}" bash -c \
  "/opt/fd-cli/scripts/fd-commands.sh test ${APP_NAME} > /workspace/${APP_NAME}-test.log 2>&1"

# Detach: the orchestrator is now responsible for the container lifetime.
# Suppress the EXIT trap so cleanup runs ONLY on signal — not on normal
# script return (which would kill the user's just-launched container).
trap - EXIT

cat <<EOF

[run-via-fd-cli] Container ${CONTAINER_NAME} is running.
[run-via-fd-cli] Host ports: ws=${WS_PORT}  ui=${UI_PORT}  mqtt=${MQTT_PORT}

Verify with:
  bash skills/run-app/scripts/run-app.sh --diagnose

Live logs:
  docker exec ${CONTAINER_NAME} tail -f /workspace/${APP_NAME}-run.log
  docker exec ${CONTAINER_NAME} tail -f /workspace/${APP_NAME}-test.log

Stop:
  docker rm -f ${CONTAINER_NAME}
EOF
