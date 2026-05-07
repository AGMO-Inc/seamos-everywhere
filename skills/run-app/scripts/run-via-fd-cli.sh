#!/usr/bin/env bash
set -euo pipefail

# ─── run-via-fd-cli.sh — host-side wrapper around fd-cli image ────────────
# Delegates build/run/test to the fd-cli Docker image, which (unlike
# app-builder) ships the NEVONEX Platform Service runtime archive inside
# the image. Two known archive locations are searched at prep time:
#   1. ${SDK_DIR}/dependencies/INSTALL_x86_64.tar.xz  (legacy FD Headless SDK)
#   2. /opt/nevonex/configuration/org.eclipse.osgi/<id>/.cp/dependencies/INSTALL_x86_64.tar.xz
#      (fd-cli ≥ 2026-02-26 — FD no longer ships archive via SDK, only via image)
# Whichever is found is extracted to /workspace/.nevonex/dependencies/<ver>/lib/.
# An unmodified GUI FD binary lives at `/opt/nevonex/FeatureDesigner`.
# fd-commands.sh is bind-mounted from fd-cli-runtime/scripts/ on the host
# (the image itself does NOT carry it), and knows how to:
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

# UI forwarder: TestSimulator/Spark inside the container binds to 127.0.0.1:6563
# (lo only), which docker port-publish cannot reach. We always publish the host
# UI port to a sidecar listener at 0.0.0.0:UI_FWD_INTERNAL inside the container,
# which forwards to 127.0.0.1:6563. Set RUNAPP_NO_UI_FORWARDER=1 to disable.
UI_FWD_INTERNAL="${UI_FWD_INTERNAL:-16563}"
RUNAPP_NO_UI_FORWARDER="${RUNAPP_NO_UI_FORWARDER:-0}"

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

# APP_PROJECT_ROOT auto-resolution.
# FD Headless emits the project as <workspace>/<APP>/<APP>/ — the inner <APP>
# is the project root that contains com.bosch.fsp.<APP>, <APP>_CPP_SDK, etc.
# Search candidates in priority order:
#   1. caller-supplied APP_PROJECT_ROOT (env or CLI)
#   2. plugin tree:           ${USER_ROOT}/${APP_NAME}/${APP_NAME}
#   3. current working dir:   ${PWD}/${APP_NAME}/${APP_NAME}, ${PWD}/${APP_NAME}, ${PWD}
#   4. SEAMOS_WORKSPACE env:  ${SEAMOS_WORKSPACE}/${APP_NAME}/${APP_NAME}
# A candidate is accepted only if it actually looks like an FD project
# (has com.bosch.fsp.<APP_NAME> alongside).
if [ -z "${APP_PROJECT_ROOT}" ]; then
  CANDIDATES=(
    "${USER_ROOT}/${APP_NAME}/${APP_NAME}"
    "${PWD}/${APP_NAME}/${APP_NAME}"
    "${PWD}/${APP_NAME}"
    "${PWD}"
  )
  if [ -n "${SEAMOS_WORKSPACE:-}" ]; then
    CANDIDATES+=("${SEAMOS_WORKSPACE}/${APP_NAME}/${APP_NAME}")
  fi
  for cand in "${CANDIDATES[@]}"; do
    if [ -d "${cand}/com.bosch.fsp.${APP_NAME}" ]; then
      APP_PROJECT_ROOT="${cand}"
      log "auto-resolved APP_PROJECT_ROOT=${APP_PROJECT_ROOT}"
      break
    fi
  done
fi
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
  err "Searched: plugin tree, \$PWD, \$PWD/${APP_NAME}, \$PWD/${APP_NAME}/${APP_NAME}${SEAMOS_WORKSPACE:+, \$SEAMOS_WORKSPACE}"
  err "Set APP_PROJECT_ROOT=/path/to/${APP_NAME}/${APP_NAME} explicitly, or cd into the workspace that contains '${APP_NAME}/'."
  exit 2
fi
if [ ! -d "${APP_PROJECT_ROOT}/com.bosch.fsp.${APP_NAME}" ]; then
  err "APP_PROJECT_ROOT=${APP_PROJECT_ROOT} does not look like an FD project root."
  err ""
  err "Expected layout (the inner '<APP>' directory inside <USER_ROOT>/<APP>/):"
  err ""
  err "  \$APP_PROJECT_ROOT/"
  err "  ├── com.bosch.fsp.${APP_NAME}/         <- FSP definition (FDProject.props lives here)"
  err "  ├── ${APP_NAME}_CPP_SDK/               <- generated C++ SDK"
  err "  └── ${APP_NAME}_${APP_NAME}/           <- C++ app code (CMakeLists.txt, src-gen/, etc.)"
  err ""
  err "Common mistakes:"
  err "  - Pointing at <USER_ROOT>/${APP_NAME}     -> one level too shallow (no com.bosch.fsp.* sibling)"
  err "  - Pointing at <USER_ROOT>/${APP_NAME}/${APP_NAME}/${APP_NAME}_${APP_NAME}  -> one level too deep (the app code dir, not the project root)"
  err ""
  err "Fix: APP_PROJECT_ROOT=<USER_ROOT>/${APP_NAME}/${APP_NAME}"
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
  # A1: defuse stale public.ecr.aws bearer tokens (only relevant if the image
  # is a public.ecr.aws/* path; helper is a no-op otherwise).
  SHARED_HELPER="$(cd "${SCRIPT_DIR}/../.." 2>/dev/null && pwd)/shared-references/scripts/check-ecr-public-auth.sh"
  if [ -f "$SHARED_HELPER" ]; then
    if [ "${RUNAPP_CLEAN_ECR_AUTH:-0}" = "1" ]; then
      bash "$SHARED_HELPER" --auto-clean || true
    else
      bash "$SHARED_HELPER" || true
    fi
  fi
  log "Image ${FD_CLI_IMAGE} not present; pulling…"
  if ! docker pull "${PLATFORM_ARGS[@]}" "${FD_CLI_IMAGE}" >/dev/null 2>&1; then
    err "Failed to pull ${FD_CLI_IMAGE}. If the image is public.ecr.aws/* and you got 403, the helper above will have flagged a stale entry — re-run with RUNAPP_CLEAN_ECR_AUTH=1 to auto-clean ~/.docker/config.json."
    err "Otherwise check ECR auth (aws ecr-public get-login-password) or set FD_CLI_IMAGE to a local tag."
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
  if [ "${UI_PORT}" = "0" ]; then
    UI_PUBLISH=""
  elif [ "${RUNAPP_NO_UI_FORWARDER}" = "1" ]; then
    UI_PUBLISH="-p ${UI_PORT}:6563"
  else
    UI_PUBLISH="-p ${UI_PORT}:${UI_FWD_INTERNAL}"
  fi
  echo "[run-via-fd-cli] DRYRUN: docker run -d --rm ${PLATFORM_ARGS[*]} --name ${CONTAINER_NAME} -v ${APP_PROJECT_ROOT}:/workspace/${APP_NAME} -v ${FD_CLI_SCRIPTS_HOST}:/opt/fd-cli/scripts:ro -v ${FD_CLI_CONFIG_HOST}:/opt/fd-cli/config:ro -p ${WS_PORT}:1456 ${UI_PUBLISH} -p ${MQTT_PORT}:1883 ${FD_CLI_IMAGE} sleep infinity"
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
PORT_PUBLISH=( -p "${WS_PORT}:1456" -p "${MQTT_PORT}:1883" )
if [ "${UI_PORT}" != "0" ]; then
  if [ "${RUNAPP_NO_UI_FORWARDER}" = "1" ]; then
    PORT_PUBLISH+=( -p "${UI_PORT}:6563" )
  else
    # Map host UI_PORT to the sidecar forwarder's listener port. The forwarder
    # itself relays to 127.0.0.1:6563 inside the container. See ui-forwarder.py.
    PORT_PUBLISH+=( -p "${UI_PORT}:${UI_FWD_INTERNAL}" )
  fi
fi

docker run -d --rm \
  "${PLATFORM_ARGS[@]}" \
  --name "${CONTAINER_NAME}" \
  --add-host "broker:127.0.0.1" \
  -v "${APP_PROJECT_ROOT}:/workspace/${APP_NAME}" \
  -v "${FD_CLI_SCRIPTS_HOST}:/opt/fd-cli/scripts:ro" \
  -v "${FD_CLI_CONFIG_HOST}:/opt/fd-cli/config:ro" \
  "${PORT_PUBLISH[@]}" \
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
# Archive search order:
#   1. ${SDK_DIR}/dependencies/INSTALL_x86_64.tar.xz  — old FD Headless layout
#   2. ${SDK_DIR}/dependencies/x86_64.tar.xz          — older variant (no prefix)
#   3. /opt/nevonex/configuration/org.eclipse.osgi/*/.cp/dependencies/INSTALL_x86_64.tar.xz
#                                                     — fd-cli ≥ 2026-02-26: archive
#                                                       baked into the image (FD no
#                                                       longer ships it via SDK).
# OSGi bundle id under org.eclipse.osgi (e.g. 15/0/.cp) varies per image build,
# so we resolve it dynamically with `find -quit`.
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
  CANDIDATES=(
    \"\$SDK_DIR/dependencies/INSTALL_x86_64.tar.xz\"
    \"\$SDK_DIR/dependencies/x86_64.tar.xz\"
  )
  IMAGE_ARCHIVE=\$(find /opt/nevonex/configuration/org.eclipse.osgi -path '*/dependencies/INSTALL_x86_64.tar.xz' -print -quit 2>/dev/null || true)
  if [ -n \"\$IMAGE_ARCHIVE\" ]; then
    CANDIDATES+=(\"\$IMAGE_ARCHIVE\")
  fi
  EXTRACTED=0
  for f in \"\${CANDIDATES[@]}\"; do
    if [ -f \"\$f\" ]; then
      echo \"[prep] extracting \$f → \$DEPS\"
      xz -dc \"\$f\" | tar xf - -C \"\$DEPS\"
      EXTRACTED=1
      break
    fi
  done
  if [ \"\$EXTRACTED\" = \"0\" ]; then
    echo \"[prep] FATAL: no Platform Service archive found. Tried:\"
    printf '  - %s\n' \"\${CANDIDATES[@]}\"
    echo \"  Image layout may have changed; inspect /opt/nevonex/configuration/org.eclipse.osgi/ for the archive path.\"
    exit 3
  fi
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

# Wait for cpp_app to bind WS port (up to 90s).
# Three independent signals — first one to fire wins:
#   (a) /proc/net/tcp   — IPv4 listening on hex 0x05B0 (=1456)
#   (b) /proc/net/tcp6  — IPv6 listening on hex 0x05B0 (some Poco builds bind ::)
#   (c) run.log marker  — "CustomUI server port:1456 started." (definitive log
#                          line emitted right after the bind succeeds)
# Past versions only checked (a) and false-FAILed under qemu/Rosetta where the
# bind goes via ::ffff:0.0.0.0 and shows up in tcp6 only.
WS_READY=0
for i in $(seq 1 180); do
  if docker exec "${CONTAINER_NAME}" bash -c "
       grep -qE ': 0000:05B0 .* 0A ' /proc/net/tcp  2>/dev/null ||
       grep -qE ': 00000000000000000000000000000000:05B0 .* 0A ' /proc/net/tcp6 2>/dev/null ||
       grep -q   'CustomUI server port:1456 started' /workspace/${APP_NAME}-run.log 2>/dev/null
     "; then
    WS_READY=1
    log "cpp_app WS listening on container :1456 (host :${WS_PORT})"
    break
  fi
  sleep 0.5
done
if [ "${WS_READY}" = "0" ]; then
  err "cpp_app WS port 1456 did not open within 90s — see: docker exec ${CONTAINER_NAME} tail /workspace/${APP_NAME}-run.log"
fi

# ─── Test (background inside container) ────────────────────────────────────
log "test: spawning TestSimulator in background"
docker exec -d "${CONTAINER_NAME}" bash -c \
  "/opt/fd-cli/scripts/fd-commands.sh test ${APP_NAME} > /workspace/${APP_NAME}-test.log 2>&1"

# ─── UI forwarder (sidecar) ────────────────────────────────────────────────
# TestSimulator's Spark/Jetty binds to 127.0.0.1:6563 inside the container,
# which docker port-publish cannot reach. Run a tiny TCP forwarder bound to
# 0.0.0.0:UI_FWD_INTERNAL that relays to 127.0.0.1:6563. The host port
# publish maps UI_PORT -> UI_FWD_INTERNAL (see PORT_PUBLISH above), so the
# user hits http://localhost:UI_PORT and reaches Jetty transparently.
if [ "${UI_PORT}" != "0" ] && [ "${RUNAPP_NO_UI_FORWARDER}" != "1" ]; then
  log "ui-forwarder: starting 0.0.0.0:${UI_FWD_INTERNAL} -> 127.0.0.1:6563"
  docker exec -d "${CONTAINER_NAME}" bash -c \
    "python3 /opt/fd-cli/scripts/ui-forwarder.py ${UI_FWD_INTERNAL} 127.0.0.1 6563 > /workspace/${APP_NAME}-ui-forwarder.log 2>&1"
fi

# Detach: the orchestrator is now responsible for the container lifetime.
# Suppress the EXIT trap so cleanup runs ONLY on signal — not on normal
# script return (which would kill the user's just-launched container).
trap - EXIT

cat <<EOF

[run-via-fd-cli] Container ${CONTAINER_NAME} is running.
[run-via-fd-cli] Host ports: ws=${WS_PORT}  ui=${UI_PORT}  mqtt=${MQTT_PORT}
[run-via-fd-cli] UI forwarder: $([ "${UI_PORT}" = "0" ] && echo "disabled (--ui-port 0)" \
  || ([ "${RUNAPP_NO_UI_FORWARDER}" = "1" ] && echo "disabled (RUNAPP_NO_UI_FORWARDER=1)" \
      || echo "host:${UI_PORT} -> container:${UI_FWD_INTERNAL} -> 127.0.0.1:6563"))

Verify with:
  bash skills/run-app/scripts/run-app.sh --diagnose
  # cpp_app-only project (no Java UI gateway running): add --ui-port 0 to skip layer 5
  bash skills/run-app/scripts/run-app.sh --diagnose --ui-port 0

Live logs:
  docker exec ${CONTAINER_NAME} tail -f /workspace/${APP_NAME}-run.log
  docker exec ${CONTAINER_NAME} tail -f /workspace/${APP_NAME}-test.log

Stop:
  docker rm -f ${CONTAINER_NAME}
EOF
