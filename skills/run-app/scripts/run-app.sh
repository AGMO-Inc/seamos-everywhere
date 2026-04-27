#!/usr/bin/env bash
set -euo pipefail

# ─── run-app host-side driver (v4.1 T2) ────────────────────────────────────
# Launches entrypoint.sh inside a seamos/app-builder container to run a
# SeamOS CPP app. Host-side responsibilities:
#   - argument/env parsing
#   - host-side variable derivation
#   - APP_PROJECT_ROOT existence check
#   - JAVA codegen block (CPP MVP only)
#   - single bind mount of APP_PROJECT_ROOT → /work
#   - entrypoint.sh injection via read-only bind (no copy into user project)
#   - cleanup trap on exit

LOG_PREFIX="[run-app]"

log()  { echo "${LOG_PREFIX} $*"; }
err()  { echo "${LOG_PREFIX} [ERROR] $*" >&2; }

# ─── --diagnose / --via-fd-cli dispatch ────────────────────────────────────
# Both short-circuit the app-builder docker pipeline and hand control to a
# sibling script. All other flags are forwarded verbatim.
#
# --diagnose:    probes a running app (5-layer broker→topic→WS→UI). No build.
# --via-fd-cli:  builds + runs + tests via the fd-cli image (Platform Service
#                runtime baked into /workspace/.nevonex/dependencies/<ver>/lib),
#                so cpp_app's IMUProvider register succeeds and WS frames flow.
#                Use this instead of --with-mqtt when the app-builder image's
#                missing Platform Service was hitting layer-4 silence.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for arg in "$@"; do
  case "${arg}" in
    --diagnose|--via-fd-cli)
      DISPATCH_FLAG="${arg}"
      DELEGATE_SCRIPT=""
      case "${DISPATCH_FLAG}" in
        --diagnose)    DELEGATE_SCRIPT="${SCRIPT_DIR}/diagnose.sh" ;;
        --via-fd-cli)  DELEGATE_SCRIPT="${SCRIPT_DIR}/run-via-fd-cli.sh" ;;
      esac
      DELEGATE_ARGS=()
      seen=0
      for a in "$@"; do
        if [ "${seen}" = "0" ] && [ "${a}" = "${DISPATCH_FLAG}" ]; then
          seen=1
          continue
        fi
        DELEGATE_ARGS+=("${a}")
      done
      exec bash "${DELEGATE_SCRIPT}" "${DELEGATE_ARGS[@]+${DELEGATE_ARGS[@]}}"
      ;;
  esac
done

# ─── docker PATH resolver ──────────────────────────────────────────────────
# Shell aliases (e.g. `alias docker=/Applications/Docker.app/.../bin/docker`)
# are invisible to non-interactive bash, and a default PATH often omits the
# Docker Desktop CLI location. Without this probe, every docker call fails
# with 'command not found' and surfaces as confusing downstream errors
# (e.g. 'broker image unreachable').
if ! command -v docker >/dev/null 2>&1; then
  for CAND in \
    /Applications/Docker.app/Contents/Resources/bin \
    /usr/local/bin \
    /opt/homebrew/bin; do
    if [ -x "${CAND}/docker" ]; then
      export PATH="${CAND}:${PATH}"
      break
    fi
  done
fi
if ! command -v docker >/dev/null 2>&1; then
  err "docker binary not found in PATH. Install Docker Desktop / Docker Engine, or ensure 'docker' is on PATH for non-interactive shells."
  exit 127
fi

# ─── PLATFORM_ARGS — pin x86_64 image on Apple Silicon, override via env ───
# All docker run/pull calls expand "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" so
# `set -u` stays safe when the array is unset on non-Mac platforms.
PLATFORM_ARGS=("--platform" "linux/amd64")
if [ -n "${RUNAPP_PLATFORM:-}" ]; then
  PLATFORM_ARGS=("--platform" "${RUNAPP_PLATFORM}")
fi
if [ "$(uname -m)" = "arm64" ] && [ "$(uname -s)" = "Darwin" ]; then
  if ! sysctl -n sysctl.proc_translated 2>/dev/null | grep -q '^[01]$'; then
    echo "[run-app] WARN: Apple Silicon detected; Rosetta 2 emulation must be enabled (Docker Desktop → Settings → Features in Development → Use Rosetta for x86_64/amd64 emulation). See docker/fd-headless/README.md:24,28,105,114" >&2
  fi
fi

# ─── Parse flags / env overrides ───────────────────────────────────────────
APP_NAME="${APP_NAME:-}"
BIND_ALL="${BIND_ALL:-0}"
APP_PORT="${APP_PORT:-6563}"
WITH_MQTT="${WITH_MQTT:-0}"
MQTT_DOCKER_IMAGE="${MQTT_DOCKER_IMAGE:-eclipse-mosquitto:2}"
INJECT_DATA_FILE=""
PROPS_OVERRIDES=()
# `--use-app-builder` forces the legacy app-builder pipeline even for CPP
# apps, where it's known to fail at Provider register (Platform Service
# runtime absent). Useful for Java-parity tests on a borked CPP setup, or
# debugging the app-builder image itself. Default 0 → CPP auto-routes to
# the fd-cli image (see APP_TYPE branch below).
USE_APP_BUILDER="${USE_APP_BUILDER:-0}"
APP_PORT_EXPLICIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="${2:-}"
      shift 2
      ;;
    --bind-all)
      BIND_ALL=1
      shift
      ;;
    --app-port)
      APP_PORT="${2:-}"
      APP_PORT_EXPLICIT=1
      shift 2
      ;;
    --use-app-builder)
      USE_APP_BUILDER=1
      shift
      ;;
    --with-mqtt)
      WITH_MQTT=1
      shift
      ;;
    --inject-data)
      INJECT_DATA_FILE="${2:-}"
      if [ -z "${INJECT_DATA_FILE}" ]; then
        err "--inject-data requires a file path"
        exit 2
      fi
      shift 2
      ;;
    --props)
      if [ -z "${2:-}" ] || [[ "${2}" != *=* ]]; then
        err "--props requires KEY=VALUE (got: '${2:-}')"
        exit 2
      fi
      PROPS_OVERRIDES+=("${2}")
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: run-app.sh --app-name <NAME> [--bind-all] [--app-port <PORT>] [--with-mqtt] [--inject-data <file>] [--props <key=val>]... [--use-app-builder]
       run-app.sh --via-fd-cli --app-name <NAME> [--image <IMG>] [--skip-build] [--ws-port N] [--ui-port N] [--mqtt-port N]
       run-app.sh --diagnose [--host H] [--ws-port N] [--mqtt-port N] [--ui-port N|0] [--sample-secs N] [--skip-broker]

CPP apps auto-route to --via-fd-cli (app-builder lacks Platform Service runtime).
Java apps stay on app-builder. Set --use-app-builder (or USE_APP_BUILDER=1) to
force the legacy pipeline for CPP — fails Layer 4 by design.

Environment overrides: APP_NAME, APP_PROJECT_ROOT, BIND_ALL, APP_PORT, NVX_DOCKER_IMAGE, WITH_MQTT, MQTT_DOCKER_IMAGE, RUNAPP_BUILD_CACHE, RUNAPP_PLATFORM, RUNAPP_DRYRUN, USE_APP_BUILDER, FD_CLI_IMAGE

APP_PROJECT_ROOT defaults to \$USER_ROOT/\$APP_NAME/\$APP_NAME (plugin root convention).
Set APP_PROJECT_ROOT explicitly to run against a project outside the plugin tree
without creating a symlink (e.g. APP_PROJECT_ROOT=/path/to/MyApp/MyApp).

PLATFORM: ${PLATFORM_ARGS[*]} (override via RUNAPP_PLATFORM=linux/arm64).
EOF
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      exit 64
      ;;
  esac
done

# ─── Host-side variable derivation (plan-exact) ────────────────────────────
# SCRIPT_DIR was already computed at the top for --diagnose dispatch; reuse it.
USER_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"    # 플러그인 루트
APP_NAME="${APP_NAME:?APP_NAME required}"
APP_NAME_LOWER="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')"
APP_PROJECT_ROOT="${APP_PROJECT_ROOT:-${USER_ROOT}/${APP_NAME}/${APP_NAME}}"
CONTAINER_NAME="seamos-run-app-${APP_NAME_LOWER}"
APP_PORT="${APP_PORT:-6563}"
BIND_ALL="${BIND_ALL:-0}"
NVX_DOCKER_IMAGE="${NVX_DOCKER_IMAGE:-public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0}"

# ─── Artifact paths ────────────────────────────────────────────────────────
# Simulator.properties::uiFolderLocation is read by the Java Spark UI server
# on every run regardless of WITH_MQTT — it is not MQTT-specific.
MQTT_NETWORK="seamos-run-app-${APP_NAME_LOWER}-net"
MQTT_CONTAINER="seamos-run-app-${APP_NAME_LOWER}-mqtt"
FEATURE_CONFIG_HOST="${APP_PROJECT_ROOT}/${APP_NAME}_${APP_NAME}/config/feature.config"
SIMULATOR_PROPS_HOST="${APP_PROJECT_ROOT}/com.bosch.fsp.${APP_NAME}.gen.tests/Simulator.properties"
CONNECTION_PROPS_HOST="${APP_PROJECT_ROOT}/com.bosch.fsp.${APP_NAME}.gen.tests/connection.props"
UI_FOLDER_TARGET="/workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/ui"
HOST_LOGS_DIR="${APP_PROJECT_ROOT}/logs"

# Named volume for /tmp — keeps /tmp/sdk_build and /tmp/app_build alive between runs
# so cmake incremental builds kick in from the 2nd invocation onwards.
# Override via RUNAPP_BUILD_CACHE env (e.g. shared across APP_NAMEs) or drop the
# volume with `docker volume rm ${BUILD_CACHE_VOLUME}` for a clean rebuild.
BUILD_CACHE_VOLUME="${RUNAPP_BUILD_CACHE:-run-app-cache-${APP_NAME_LOWER}}"

log "APP_NAME=${APP_NAME}"
log "APP_NAME_LOWER=${APP_NAME_LOWER}"
log "APP_PROJECT_ROOT=${APP_PROJECT_ROOT}"
log "CONTAINER_NAME=${CONTAINER_NAME}"
log "APP_PORT=${APP_PORT} BIND_ALL=${BIND_ALL}"
log "NVX_DOCKER_IMAGE=${NVX_DOCKER_IMAGE}"
log "PLATFORM_ARGS=${PLATFORM_ARGS[*]}"

# ─── APP_PROJECT_ROOT existence check ──────────────────────────────────────
if [ ! -d "${APP_PROJECT_ROOT}" ]; then
  err "APP_PROJECT_ROOT not found: ${APP_PROJECT_ROOT}"
  err "Run the create-project skill first to scaffold '${APP_NAME}'."
  exit 2
fi

# ─── JAVA block (CPP MVP only) ─────────────────────────────────────────────
FSP_PATH="${APP_PROJECT_ROOT}/com.bosch.fsp.${APP_NAME}"
if [ -f "${FSP_PATH}/FDProject.props" ] && \
   grep -q "^JAVA_APP_PATH=" "${FSP_PATH}/FDProject.props"; then
  APP_TYPE="java"
elif [ -d "${APP_PROJECT_ROOT}/${APP_NAME}_CPP_SDK" ]; then
  APP_TYPE="cpp"
else
  APP_TYPE="java"
fi
export APP_TYPE
log "APP_TYPE=${APP_TYPE}"

# ─── CPP auto-routing → fd-cli image ──────────────────────────────────────
# The app-builder image lacks the NEVONEX Platform Service runtime, so
# cpp_app aborts at Provider register every time and Layer 4 of --diagnose
# stays silent (see SKILL.md, memory: project_seamos_provider_injection.md).
# CPP's only working local path is --via-fd-cli, so we route there
# automatically. Java apps stay on app-builder (pure JVM, no native runtime
# dependency). Set USE_APP_BUILDER=1 (or pass --use-app-builder) to override.
if [ "${APP_TYPE}" = "cpp" ] && [ "${USE_APP_BUILDER}" = "0" ]; then
  log "APP_TYPE=cpp → auto-routing to --via-fd-cli (fd-cli image bakes Platform Service runtime). Override with --use-app-builder."

  # Compose flags compatible with run-via-fd-cli.sh. Most app-builder-only
  # flags (--bind-all, --with-mqtt, --inject-data, --props) have no analog
  # in the fd-cli pipeline; we either map them or warn-and-drop.
  REROUTE_ARGS=("--app-name" "${APP_NAME}")
  if [ "${APP_PORT_EXPLICIT}" = "1" ]; then
    REROUTE_ARGS+=("--ui-port" "${APP_PORT}")
  fi
  for dropped_flag in BIND_ALL WITH_MQTT INJECT_DATA_FILE; do
    case "${dropped_flag}" in
      BIND_ALL)         [ "${BIND_ALL}" = "1" ] && echo "${LOG_PREFIX} [WARN] --bind-all is app-builder-only; dropped (fd-cli always binds 0.0.0.0)" >&2 || true;;
      WITH_MQTT)        [ "${WITH_MQTT}" = "1" ] && echo "${LOG_PREFIX} [WARN] --with-mqtt is app-builder-only; dropped (fd-cli runs broker in same container)" >&2 || true;;
      INJECT_DATA_FILE) [ -n "${INJECT_DATA_FILE}" ] && echo "${LOG_PREFIX} [WARN] --inject-data has no fd-cli analog; dropped" >&2 || true;;
    esac
  done
  if [ "${#PROPS_OVERRIDES[@]:-0}" -gt 0 ]; then
    echo "${LOG_PREFIX} [WARN] --props has no fd-cli analog; ${#PROPS_OVERRIDES[@]} override(s) dropped" >&2
  fi

  # Pass-through env so APP_PROJECT_ROOT, FD_CLI_IMAGE, RUNAPP_DRYRUN, etc.
  # propagate without re-derivation.
  exec bash "${SCRIPT_DIR}/run-via-fd-cli.sh" "${REROUTE_ARGS[@]}"
fi

# ─── Staging overlay (host originals are NEVER mutated) ───────────────────
# A mktemp directory holds the rewritten Simulator.properties / feature.config /
# connection.props / sample_data.xml. Each is bind-mounted read-only into the
# container as a single-file overlay over its target path inside /work, so the
# container sees the staged version while the host originals stay untouched.
# SIGKILL-leaked staging dirs are reaped by the 24h GC step in smoke-test.sh.
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/runapp-staging-XXXXXX")"
log "STAGING_DIR=${STAGING_DIR}"

STAGING_SIM_PROPS="${STAGING_DIR}/Simulator.properties"
STAGING_SIM_DATA_DIR="${STAGING_DIR}/data"
STAGING_SIM_DATA="${STAGING_SIM_DATA_DIR}/sample_data.xml"
STAGING_FEATURE_CONFIG="${STAGING_DIR}/feature.config"
STAGING_CONNECTION_PROPS="${STAGING_DIR}/connection.props"

# Container target paths the staging files mask (single-file ro bind mounts)
CT_SIM_PROPS="/work/com.bosch.fsp.${APP_NAME}.gen.tests/Simulator.properties"
CT_SIM_DATA="/work/com.bosch.fsp.${APP_NAME}.gen.tests/data/sample_data.xml"
CT_FEATURE_CONFIG="/work/${APP_NAME}_${APP_NAME}/config/feature.config"
CT_CONNECTION_PROPS="/work/com.bosch.fsp.${APP_NAME}.gen.tests/connection.props"

# ─── Cleanup trap ──────────────────────────────────────────────────────────
cleanup() {
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
  if [ "${WITH_MQTT:-0}" = "1" ]; then
    docker rm -f "${MQTT_CONTAINER}" 2>/dev/null || true
    docker network rm "${MQTT_NETWORK}" 2>/dev/null || true
  fi
  # Wipe staging overlay; SIGKILL leaks are reaped by smoke-test 24h GC.
  if [ -n "${STAGING_DIR:-}" ] && [ -d "${STAGING_DIR}" ]; then
    rm -rf "${STAGING_DIR}"
  fi
}
trap 'cleanup; rm -rf "${STAGING_DIR:-}" 2>/dev/null || true' EXIT INT TERM HUP

# ─── start_mqtt_broker (WITH_MQTT=1 only) ──────────────────────────────────
start_mqtt_broker() {
  if [ "${RUNAPP_DRYRUN:-0}" = "1" ]; then
    echo "[run-app] DRYRUN: docker run -d --rm ${PLATFORM_ARGS[*]} --name ${MQTT_CONTAINER} --network ${MQTT_NETWORK} --network-alias broker ${MQTT_DOCKER_IMAGE}"
    return 0
  fi

  # 1) Pre-flight image check
  if ! docker image inspect "${MQTT_DOCKER_IMAGE}" >/dev/null 2>&1; then
    if ! docker pull "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${MQTT_DOCKER_IMAGE}" >/dev/null 2>&1; then
      err "Broker image ${MQTT_DOCKER_IMAGE} unreachable. Run \`bash skills/run-app/scripts/smoke-test.sh\` first to pre-validate, or set MQTT_DOCKER_IMAGE to a cached tag / \`docker load -i mosquitto.tar\` a preloaded image."
      exit 4
    fi
  fi

  # 2) Multi-run guard — broker container
  if docker inspect "${MQTT_CONTAINER}" >/dev/null 2>&1; then
    err "Another run-app with APP_NAME=${APP_NAME} is already running (broker container ${MQTT_CONTAINER} detected). Stop it first or choose a different APP_NAME."
    exit 5
  fi

  # 3) Network (idempotent)
  docker network inspect "${MQTT_NETWORK}" >/dev/null 2>&1 || docker network create "${MQTT_NETWORK}" >/dev/null

  # 4) Broker launch (no host-port publishing; intra-network only)
  docker run -d --rm \
    "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" \
    --name "${MQTT_CONTAINER}" \
    --network "${MQTT_NETWORK}" \
    --network-alias broker \
    "${MQTT_DOCKER_IMAGE}" >/dev/null

  # 5) Readiness probe — up to 20 × 0.5s (total 10s)
  for i in $(seq 1 20); do
    if docker logs "${MQTT_CONTAINER}" 2>&1 | grep -q "Opening ipv4 listen socket on port 1883"; then
      echo "[RUN] broker ready after ${i} iterations"
      break
    fi
    sleep 0.5
    [ "$i" = 20 ] && { err "broker readiness timeout (${MQTT_CONTAINER})"; exit 4; }
  done
}

# ─── Staging-overlay rewrites ──────────────────────────────────────────────
# The container always reads from /work (a bind of APP_PROJECT_ROOT). To keep
# host originals untouched, we copy each file into ${STAGING_DIR}, mutate the
# staged copy, then bind-mount the staged file read-only over its target path
# inside the container. Apply order on the staged Simulator.properties:
#   (1) host → staging copy
#   (2) force uiFolderLocation
#   (3) (--with-mqtt) feature.config + connection.props rewrite (staging only)
#   (4) (--props) literal key=value last-win — installed by stage_apply_props
ensure_simulator_properties() {
  _stage_simulator_properties
}

rewrite_mqtt_artifacts() {
  _stage_feature_config
  _stage_connection_props
}

_apply_props_overrides() {
  # --props KEY=VALUE applies last-win on the staged Simulator.properties via
  # a python3 literal-replace loop (sed metacharacter risk avoided). Forced
  # keys (uiFolderLocation, applied by _stage_simulator_properties) are
  # detected and emit a [WARN] before being overridden by user input.
  local count=${#PROPS_OVERRIDES[@]:-0}
  if [ "${count}" = "0" ]; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 required for --props (install Xcode CLT: 'xcode-select --install', or apt install python3)"
    exit 3
  fi

  local entry key val
  for entry in "${PROPS_OVERRIDES[@]}"; do
    key="${entry%%=*}"
    val="${entry#*=}"
    case "${key}" in
      uiFolderLocation)
        echo "[run-app] [WARN] --props ${key} overrides forced value" >&2
        ;;
    esac
    PROP_KEY="${key}" PROP_VAL="${val}" PROP_FILE="${STAGING_SIM_PROPS}" \
      python3 - <<'PY'
import os, sys
key = os.environ['PROP_KEY']
val = os.environ['PROP_VAL']
path = os.environ['PROP_FILE']
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
out = []
seen = False
for line in lines:
    stripped = line.lstrip()
    if not stripped.startswith('#') and '=' in stripped:
        k = stripped.split('=', 1)[0].strip()
        if k == key:
            line = f"{key}={val}\n"
            seen = True
    out.append(line)
if not seen:
    if out and not out[-1].endswith('\n'):
        out[-1] = out[-1] + '\n'
    out.append(f"{key}={val}\n")
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(out)
PY
  done
}

_stage_simulator_properties() {
  local src="${SIMULATOR_PROPS_HOST}"
  if [ ! -f "${src}" ]; then
    err "Simulator.properties not found at ${src}"
    exit 3
  fi
  cp "${src}" "${STAGING_SIM_PROPS}"

  # Force uiFolderLocation on the staged copy.
  if grep -q '^uiFolderLocation=' "${STAGING_SIM_PROPS}"; then
    sed "s|^uiFolderLocation=.*|uiFolderLocation=${UI_FOLDER_TARGET}|" \
      "${STAGING_SIM_PROPS}" > "${STAGING_SIM_PROPS}.tmp" \
      && mv "${STAGING_SIM_PROPS}.tmp" "${STAGING_SIM_PROPS}"
  else
    printf '\nuiFolderLocation=%s\n' "${UI_FOLDER_TARGET}" >> "${STAGING_SIM_PROPS}"
  fi
  if ! grep -q "^uiFolderLocation=${UI_FOLDER_TARGET}$" "${STAGING_SIM_PROPS}"; then
    err "staging Simulator.properties uiFolderLocation rewrite verification failed"
    exit 3
  fi

  _apply_props_overrides
}

_stage_inject_data() {
  if [ -z "${INJECT_DATA_FILE}" ]; then
    return 0
  fi
  if [ ! -f "${INJECT_DATA_FILE}" ]; then
    err "--inject-data: file not found: ${INJECT_DATA_FILE}"
    exit 2
  fi
  mkdir -p "${STAGING_SIM_DATA_DIR}"
  cp "${INJECT_DATA_FILE}" "${STAGING_SIM_DATA}"
  log "[--inject-data] staged ${INJECT_DATA_FILE} → ${CT_SIM_DATA}"
}

_stage_feature_config() {
  local src="${FEATURE_CONFIG_HOST}"
  if [ ! -f "${src}" ]; then
    err "feature.config not found at ${src}"
    exit 3
  fi
  cp "${src}" "${STAGING_FEATURE_CONFIG}"

  # mqtt block — replace the first "host" field inside "mqtt": { ... }
  awk '
    /^[[:space:]]*"mqtt"[[:space:]]*:[[:space:]]*\{/ { in_mqtt=1 }
    in_mqtt && /"host"[[:space:]]*:[[:space:]]*"[^"]*"/ && !done {
      sub(/"host"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"host\": \"broker\"")
      done=1
    }
    in_mqtt && /^[[:space:]]*\}/ { in_mqtt=0 }
    { print }
  ' "${STAGING_FEATURE_CONFIG}" > "${STAGING_FEATURE_CONFIG}.tmp" \
    && mv "${STAGING_FEATURE_CONFIG}.tmp" "${STAGING_FEATURE_CONFIG}"

  if ! grep -q '"host"[[:space:]]*:[[:space:]]*"broker"' "${STAGING_FEATURE_CONFIG}"; then
    err "staging feature.config mqtt.host rewrite verification failed"
    exit 3
  fi
}

_stage_connection_props() {
  local src="${CONNECTION_PROPS_HOST}"
  if [ ! -f "${src}" ]; then
    err "connection.props not found at ${src}. TestSimulator loads it via ./connection.props (cwd=com.bosch.fsp.${APP_NAME}.gen.tests). Regenerate the FSP tree or create the file with content: broker=tcp://broker:1883"
    exit 3
  fi
  cp "${src}" "${STAGING_CONNECTION_PROPS}"

  if grep -q '^broker=' "${STAGING_CONNECTION_PROPS}"; then
    sed "s|^broker=.*|broker=tcp://broker:1883|" \
      "${STAGING_CONNECTION_PROPS}" > "${STAGING_CONNECTION_PROPS}.tmp" \
      && mv "${STAGING_CONNECTION_PROPS}.tmp" "${STAGING_CONNECTION_PROPS}"
  else
    printf '\nbroker=tcp://broker:1883\n' >> "${STAGING_CONNECTION_PROPS}"
  fi
  if ! grep -q '^broker=tcp://broker:1883$' "${STAGING_CONNECTION_PROPS}"; then
    err "staging connection.props broker rewrite verification failed"
    exit 3
  fi
}

# ─── Build the staging-overlay mount list ──────────────────────────────────
# All overlays are read-only single-file binds; the container reads the staged
# rewrite while the host original under APP_PROJECT_ROOT stays untouched.
# Java codegen also gets a host-shared mvn cache (~/.m2 → /root/.m2) so the
# 1st build hydrates and subsequent runs are warm. Tradeoff (the container
# sees host m2 state) is documented in SKILL.md.
build_overlay_mounts() {
  OVERLAY_MOUNTS=()
  OVERLAY_MOUNTS+=(-v "${STAGING_SIM_PROPS}:${CT_SIM_PROPS}:ro")
  if [ -n "${INJECT_DATA_FILE}" ]; then
    OVERLAY_MOUNTS+=(-v "${STAGING_SIM_DATA}:${CT_SIM_DATA}:ro")
  fi
  if [ "${WITH_MQTT:-0}" = "1" ]; then
    OVERLAY_MOUNTS+=(-v "${STAGING_FEATURE_CONFIG}:${CT_FEATURE_CONFIG}:ro")
    OVERLAY_MOUNTS+=(-v "${STAGING_CONNECTION_PROPS}:${CT_CONNECTION_PROPS}:ro")
  fi
  if [ "${APP_TYPE}" = "java" ]; then
    mkdir -p "${HOME}/.m2"
    OVERLAY_MOUNTS+=(-v "${HOME}/.m2:/root/.m2")
  fi
}

# ─── docker run (with duplicate-container retry) ───────────────────────────
run_container() {
  build_overlay_mounts
  if [ "${RUNAPP_DRYRUN:-0}" = "1" ]; then
    echo "[run-app] DRYRUN: docker run --rm ${PLATFORM_ARGS[*]} --name ${CONTAINER_NAME} -v ${APP_PROJECT_ROOT}:/work ${OVERLAY_MOUNTS[*]:-} -v ${BUILD_CACHE_VOLUME}:/tmp -v ${SCRIPT_DIR}/entrypoint.sh:/entrypoint.sh:ro -e APP_NAME=${APP_NAME} -e APP_TYPE=${APP_TYPE} -e BIND_ALL=${BIND_ALL} -e APP_PORT=${APP_PORT} -p ${APP_PORT}:${APP_PORT} -p 1456:1456 --entrypoint /entrypoint.sh ${NVX_DOCKER_IMAGE}"
    return 0
  fi
  if [ "${WITH_MQTT:-0}" = "1" ]; then
    # Multi-run guard — app container
    if docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
      err "Another run-app with APP_NAME=${APP_NAME} is already running (app container ${CONTAINER_NAME} detected). Stop it first or choose a different APP_NAME."
      exit 5
    fi
    docker run --rm \
      "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" \
      --name "${CONTAINER_NAME}" \
      --network "${MQTT_NETWORK}" \
      --network-alias app \
      -v "${APP_PROJECT_ROOT}:/work" \
      "${OVERLAY_MOUNTS[@]+${OVERLAY_MOUNTS[@]}}" \
      -v "${BUILD_CACHE_VOLUME}:/tmp" \
      -v "${HOST_LOGS_DIR}:/workspace/${APP_NAME}/logs" \
      -v "${SCRIPT_DIR}/entrypoint.sh:/entrypoint.sh:ro" \
      -e APP_NAME="${APP_NAME}" \
      -e APP_NAME_LOWER="${APP_NAME_LOWER}" \
      -e APP_TYPE="${APP_TYPE}" \
      -e BIND_ALL="${BIND_ALL}" \
      -e APP_PORT="${APP_PORT}" \
      -p "${APP_PORT}:${APP_PORT}" \
      -p 1456:1456 \
      --entrypoint /entrypoint.sh \
      "${NVX_DOCKER_IMAGE}"
  else
    docker run --rm \
      "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" \
      --name "${CONTAINER_NAME}" \
      -v "${APP_PROJECT_ROOT}:/work" \
      "${OVERLAY_MOUNTS[@]+${OVERLAY_MOUNTS[@]}}" \
      -v "${BUILD_CACHE_VOLUME}:/tmp" \
      -v "${HOST_LOGS_DIR}:/workspace/${APP_NAME}/logs" \
      -v "${SCRIPT_DIR}/entrypoint.sh:/entrypoint.sh:ro" \
      -e APP_NAME="${APP_NAME}" \
      -e APP_NAME_LOWER="${APP_NAME_LOWER}" \
      -e APP_TYPE="${APP_TYPE}" \
      -e BIND_ALL="${BIND_ALL}" \
      -e APP_PORT="${APP_PORT}" \
      -p "${APP_PORT}:${APP_PORT}" \
      -p 1456:1456 \
      --entrypoint /entrypoint.sh \
      "${NVX_DOCKER_IMAGE}"
  fi
}

mkdir -p "${HOST_LOGS_DIR}"
ensure_simulator_properties
_stage_inject_data

if [ "${WITH_MQTT:-0}" = "1" ]; then
  log "WITH_MQTT=1 — starting broker and staging MQTT artifacts"
  start_mqtt_broker
  rewrite_mqtt_artifacts
fi

log "Starting container ${CONTAINER_NAME}..."

if [ "${WITH_MQTT:-0}" = "1" ]; then
  # No silent retry in WITH_MQTT=1 path — multi-run guard already asserted uniqueness
  run_container
else
  if ! run_container; then
    log "docker run failed — attempting single cleanup + retry"
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    run_container
  fi
fi
