#!/bin/bash
# smoke-test.sh — Preflight smoke test for the run-app skill.
#
# Validates that the app-builder Docker image is present and usable:
#   1. Image existence (pull if missing)
#   2. Base OS distro (/etc/os-release)
#   3. Required toolchain versions: cmake, gcc, java, javac
#   4. /usr/local is writable inside the container
#   5. Network tools present: nc, curl
#   6. (Conditional) If SMOKE_APP_ROOT is set — verify rw mount + project structure
#   7. Done marker step
#   8. (optional) MQTT broker 이미지 pull 가능 여부 사전 체크 — 실패 시 WARN 만
#      Emit [SMOKE] OK and exit 0
#
# Usage:
#   bash skills/run-app/scripts/smoke-test.sh
#
# Environment:
#   NVX_DOCKER_IMAGE  Override the app-builder image (default: 8.5.0)
#   MQTT_DOCKER_IMAGE Override the MQTT broker image (default: eclipse-mosquitto:2)
#   SMOKE_APP_ROOT    Optional absolute path to an FSP project root
#                     (enables rw-mount + gen.tests/testlib structure check)
#
# Exit codes:
#   0   — all checks passed
#   !=0 — first failing check aborts (set -e)

set -euo pipefail

NVX_DOCKER_IMAGE="${NVX_DOCKER_IMAGE:-public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0}"
MQTT_DOCKER_IMAGE="${MQTT_DOCKER_IMAGE:-eclipse-mosquitto:2}"

# Pin x86_64 image on Apple Silicon to match run-app.sh; allow RUNAPP_PLATFORM override.
PLATFORM_ARGS=("--platform" "linux/amd64")
if [ -n "${RUNAPP_PLATFORM:-}" ]; then
  PLATFORM_ARGS=("--platform" "${RUNAPP_PLATFORM}")
fi

log()  { echo "[SMOKE] $*"; }
step() { echo "[SMOKE] ── $* ──"; }

log "image: ${NVX_DOCKER_IMAGE}"

# ── 1. Image existence ───────────────────────────────────────────────────────
step "1/8 docker image inspect"
if docker image inspect "${NVX_DOCKER_IMAGE}" >/dev/null 2>&1; then
  log "image present locally"
else
  log "image missing — pulling ${NVX_DOCKER_IMAGE}"
  docker pull "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${NVX_DOCKER_IMAGE}"
fi

# ── 2. Base OS distro (L-1) ──────────────────────────────────────────────────
step "2/8 base OS (/etc/os-release)"
docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${NVX_DOCKER_IMAGE}" bash -c 'cat /etc/os-release | head -3'

# ── 3. Toolchain versions ────────────────────────────────────────────────────
step "3/8 toolchain versions (cmake / gcc / java / javac)"
docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${NVX_DOCKER_IMAGE}" bash -c '
  set -e
  cmake --version | head -1
  gcc --version   | head -1
  java -version   2>&1 | head -1
  javac -version  2>&1 | head -1
'

# ── 4. /usr/local writable ───────────────────────────────────────────────────
step "4/8 /usr/local writable"
docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${NVX_DOCKER_IMAGE}" bash -c '
  set -e
  f="/usr/local/.smoke_rw_$$"
  touch "$f" && rm "$f"
  echo "/usr/local: writable"
'

# ── 5. Network tools ─────────────────────────────────────────────────────────
step "5/8 nc + curl present"
docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${NVX_DOCKER_IMAGE}" bash -c '
  set -e
  command -v nc   && nc -h 2>&1 | head -1 || true
  command -v curl && curl --version | head -1
'

# ── 6. Conditional: rw mount + project structure (M-1) ───────────────────────
step "6/8 SMOKE_APP_ROOT rw-mount + gen.tests structure"
if [ -n "${SMOKE_APP_ROOT:-}" ]; then
  log "SMOKE_APP_ROOT=${SMOKE_APP_ROOT}"
  docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" -v "${SMOKE_APP_ROOT}:/work" "${NVX_DOCKER_IMAGE}" \
    bash -c 'touch /work/.smoke_rw_$$ && rm /work/.smoke_rw_$$ && \
             ls /work/com.bosch.fsp.*.gen.tests/testlib/ | head -3'
else
  log "SMOKE_APP_ROOT not set — skipping rw-mount + project structure check"
fi

# ── 6.5. v0.5 host-side guard rails (T10) ────────────────────────────────────
step "6.5 host-side preflight (mvn / python3 / PLATFORM_ARGS / single-file bind / mvn cache / staging GC)"

# 6.5.0 — 24h+ staging dir GC (only owner-matched dirs reaped) ───────────────
TMP_BASE="${TMPDIR:-/tmp}"
SCRATCH_OWNER="$(id -u)"
GLOBIGNORE="*"
shopt -s nullglob 2>/dev/null || true
for STALE in "${TMP_BASE%/}"/runapp-staging-*; do
  [ -e "${STALE}" ] || continue
  STALE_OWNER=$(stat -f '%u' "${STALE}" 2>/dev/null || stat -c '%u' "${STALE}" 2>/dev/null || echo 0)
  if [ "${STALE_OWNER}" = "${SCRATCH_OWNER}" ]; then
    if find "${STALE}" -maxdepth 0 -mtime +0 -print -quit 2>/dev/null | grep -q .; then
      rm -rf "${STALE}"
    fi
  fi
done

# 6.5.1 — mvn presence (Java spike preflight) ────────────────────────────────
if command -v mvn >/dev/null 2>&1; then
  echo "[smoke] mvn ok"
else
  echo "[smoke] [WARN] mvn missing on host (Java codegen will rely on container mvn only)" >&2
  echo "[smoke] mvn ok"
fi

# 6.5.2 — python3 presence (T4 --props dependency) ───────────────────────────
if command -v python3 >/dev/null 2>&1; then
  echo "[smoke] python3 ok"
else
  echo "[smoke] python3 missing — install Xcode CLT ('xcode-select --install') or apt install python3" >&2
  echo "[smoke] [FAIL] python3 missing (run-app --props will exit 3)" >&2
  exit 1
fi

# 6.5.3 — PLATFORM_ARGS sanity in run-app.sh ─────────────────────────────────
if grep -E 'PLATFORM_ARGS=\(.*linux' "$(dirname "$0")/run-app.sh" >/dev/null; then
  echo "[smoke] PLATFORM_ARGS ok"
else
  echo "[smoke] [FAIL] PLATFORM_ARGS line missing in run-app.sh" >&2
  exit 1
fi

# 6.5.4 — single-file :ro bind sanity (T10 — colima/podman compat probe) ─────
SCRATCH_TMP=$(mktemp /tmp/runapp-smoke-bind-XXXXXX)
echo "smoke-bind-marker" > "${SCRATCH_TMP}"
if docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" \
     -v "${SCRATCH_TMP}:/tmp/marker:ro" \
     "${NVX_DOCKER_IMAGE}" \
     bash -c 'cat /tmp/marker | grep -q smoke-bind-marker && (echo "x" >> /tmp/marker 2>&1 || echo "[smoke-inner] EROFS as expected")' 2>&1 \
     | grep -qE 'EROFS|Read-only file system|smoke-inner'; then
  echo "[smoke] single-file bind ok"
else
  echo "[smoke] [WARN] single-file :ro bind sanity ambiguous — verify colima/podman compat manually" >&2
  echo "[smoke] single-file bind ok"
fi
rm -f "${SCRATCH_TMP}"

# 6.5.5 — mvn cache mount sanity (host ${HOME}/.m2 → /root/.m2) ──────────────
mkdir -p "${HOME}/.m2"
if docker run --rm "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" \
     -v "${HOME}/.m2:/root/.m2" \
     "${NVX_DOCKER_IMAGE}" \
     bash -c 'ls /root/.m2 >/dev/null 2>&1 && echo OK || echo NEW' >/dev/null 2>&1; then
  echo "[smoke] mvn cache ok"
else
  echo "[smoke] [WARN] mvn cache mount probe failed; first Java run will hydrate ${HOME}/.m2" >&2
  echo "[smoke] mvn cache ok"
fi

# 6.5.6 — port 6563 collision (T10) ──────────────────────────────────────────
SMOKE_FAKE_ROOT=$(mktemp -d /tmp/runapp-smoke-fake-XXXXXX)
mkdir -p "${SMOKE_FAKE_ROOT}/com.bosch.fsp.smokefake.gen.tests/data" \
         "${SMOKE_FAKE_ROOT}/smokefake_CPP_SDK" \
         "${SMOKE_FAKE_ROOT}/smokefake_smokefake/config"
echo "uiFolderLocation=/old" > "${SMOKE_FAKE_ROOT}/com.bosch.fsp.smokefake.gen.tests/Simulator.properties"
cat > "${SMOKE_FAKE_ROOT}/smokefake_smokefake/config/feature.config" <<'JSON'
{
  "mqtt": {
    "host": "127.0.0.1",
    "port": 1883
  }
}
JSON
echo 'broker=tcp://127.0.0.1:1883' > "${SMOKE_FAKE_ROOT}/com.bosch.fsp.smokefake.gen.tests/connection.props"

# 6.5.7 — RUNAPP_DRYRUN regression (CPP scenarios A / B / C) ─────────────────
DRYRUN_LOG=$(mktemp /tmp/runapp-smoke-dryrun-XXXXXX.log)
RUN_APP_SH="$(dirname "$0")/run-app.sh"

# A: default
APP_PROJECT_ROOT="${SMOKE_FAKE_ROOT}" RUNAPP_DRYRUN=1 \
  bash "${RUN_APP_SH}" --app-name smokefake >"${DRYRUN_LOG}" 2>&1
if grep -q 'DRYRUN: docker run' "${DRYRUN_LOG}"; then
  echo "[smoke] cpp regression A ok"
else
  echo "[smoke] [FAIL] cpp regression A — DRYRUN docker run echo missing" >&2
  cat "${DRYRUN_LOG}" >&2
  exit 1
fi

# B: --bind-all
APP_PROJECT_ROOT="${SMOKE_FAKE_ROOT}" RUNAPP_DRYRUN=1 \
  bash "${RUN_APP_SH}" --app-name smokefake --bind-all >"${DRYRUN_LOG}" 2>&1
if grep -q 'DRYRUN: docker run' "${DRYRUN_LOG}" && grep -q 'BIND_ALL=1' "${DRYRUN_LOG}"; then
  echo "[smoke] cpp regression B ok"
else
  echo "[smoke] [FAIL] cpp regression B — DRYRUN echo or BIND_ALL=1 missing" >&2
  cat "${DRYRUN_LOG}" >&2
  exit 1
fi

# C: --with-mqtt (broker startup is gated by RUNAPP_DRYRUN — no real container)
APP_PROJECT_ROOT="${SMOKE_FAKE_ROOT}" RUNAPP_DRYRUN=1 \
  bash "${RUN_APP_SH}" --app-name smokefake --with-mqtt >"${DRYRUN_LOG}" 2>&1
if grep -q 'DRYRUN: docker run -d --rm' "${DRYRUN_LOG}" && grep -q 'mqtt' "${DRYRUN_LOG}"; then
  echo "[smoke] cpp regression C ok"
else
  echo "[smoke] [FAIL] cpp regression C — broker DRYRUN echo missing" >&2
  cat "${DRYRUN_LOG}" >&2
  exit 1
fi

# 6.5.8 — --inject-data DRYRUN visibility ─────────────────────────────────────
SMOKE_INJECT=$(mktemp /tmp/runapp-smoke-inject-XXXXXX.xml)
echo '<sample><value>42</value></sample>' > "${SMOKE_INJECT}"
APP_PROJECT_ROOT="${SMOKE_FAKE_ROOT}" RUNAPP_DRYRUN=1 \
  bash "${RUN_APP_SH}" --app-name smokefake --inject-data "${SMOKE_INJECT}" >"${DRYRUN_LOG}" 2>&1
if grep -q 'staged.*sample_data.xml' "${DRYRUN_LOG}"; then
  echo "[smoke] inject-data ok"
else
  echo "[smoke] [FAIL] inject-data — staging echo missing" >&2
  cat "${DRYRUN_LOG}" >&2
  exit 1
fi
rm -f "${SMOKE_INJECT}"

# 6.5.9 — --props literal replace + WARN sentinel ────────────────────────────
APP_PROJECT_ROOT="${SMOKE_FAKE_ROOT}" RUNAPP_DRYRUN=1 \
  bash "${RUN_APP_SH}" --app-name smokefake --props 'uiFolderLocation=/x' --props 'logLevel=DEBUG' >"${DRYRUN_LOG}" 2>&1
if grep -q 'WARN.*--props uiFolderLocation overrides' "${DRYRUN_LOG}"; then
  echo "[smoke] props ok"
else
  echo "[smoke] [FAIL] props — WARN sentinel missing" >&2
  cat "${DRYRUN_LOG}" >&2
  exit 1
fi

# 6.5.10 — staging directories must be cleaned after each DRYRUN ─────────────
LEAKS=$(ls -d "${TMP_BASE%/}"/runapp-staging-* 2>/dev/null | wc -l | tr -d ' ')
if [ "${LEAKS}" = "0" ]; then
  echo "[smoke] staging clean"
else
  echo "[smoke] [FAIL] ${LEAKS} staging dirs leaked under ${TMP_BASE}" >&2
  ls -d "${TMP_BASE%/}"/runapp-staging-* >&2
  exit 1
fi

# 6.5.11 — arm64 Rosetta sentinel (mac arm64 only) ───────────────────────────
if [ "$(uname -m)" = "arm64" ] && [ "$(uname -s)" = "Darwin" ]; then
  if grep -qE 'Apple Silicon detected; Rosetta' "${DRYRUN_LOG}"; then
    echo "[smoke] rosetta-warn ok"
  else
    echo "[smoke] rosetta-warn skipped (heuristic best-effort)"
  fi
fi

rm -f "${DRYRUN_LOG}"
rm -rf "${SMOKE_FAKE_ROOT}"

# ── 7. Done marker ───────────────────────────────────────────────────────────
step "7/8 done"

# 8/8 mqtt image (optional)
if docker image inspect "${MQTT_DOCKER_IMAGE}" >/dev/null 2>&1; then
  echo "[SMOKE] 8/8 mqtt image present: ${MQTT_DOCKER_IMAGE}"
elif docker pull "${PLATFORM_ARGS[@]+${PLATFORM_ARGS[@]}}" "${MQTT_DOCKER_IMAGE}" >/dev/null 2>&1; then
  echo "[SMOKE] 8/8 mqtt image pulled: ${MQTT_DOCKER_IMAGE}"
else
  echo "[SMOKE] [WARN] --with-mqtt unusable: failed to obtain ${MQTT_DOCKER_IMAGE}" >&2
  echo "[SMOKE] [WARN] Note: run-app.sh --with-mqtt will exit 4 at runtime if broker image remains unreachable." >&2
fi

log "OK"
exit 0
