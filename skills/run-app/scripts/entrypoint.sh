#!/usr/bin/env bash
set -euo pipefail
APP_PID=""
MQTT_OK=0  # 0=absent/unreachable → app-only wait mode; 1=broker reachable → TestSimulator mode

# -----------------------------------------------------------------------------
# cleanup + trap (T6)
# -----------------------------------------------------------------------------
cleanup() {
  [ -n "${APP_PID:-}" ] && kill "${APP_PID}" 2>/dev/null || true
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# prepare_hamcrest (T4)
# -----------------------------------------------------------------------------
prepare_hamcrest() {
  echo "[STEP] prepare_hamcrest: start"
  TESTLIB="/work/com.bosch.fsp.${APP_NAME}.gen.tests/testlib"
  TARGET_JAR="${TESTLIB}/hamcrest-core-1.3.jar"

  # 1) already present → skip
  if [ -f "${TARGET_JAR}" ]; then
    echo "[STEP] hamcrest already present, skip"
    return
  fi

  mkdir -p "${TESTLIB}"

  # 2) container-local cache
  for CACHED in /opt/jars/hamcrest-core-1.3.jar /usr/share/java/hamcrest-core.jar; do
    if [ -f "${CACHED}" ]; then
      cp "${CACHED}" "${TARGET_JAR}"
      echo "[STEP] hamcrest copied from ${CACHED}"
      return
    fi
  done

  # 3) fixed-URL download (sha1: 42a25dc3219429f0e5d060061f71acb49bf010a0 — optional verify)
  curl -fsSL -o "${TARGET_JAR}" \
    https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar
  echo "[STEP] hamcrest downloaded from maven central"
}

# -----------------------------------------------------------------------------
# prepare_workspace (T4)
# -----------------------------------------------------------------------------
prepare_workspace() {
  echo "[STEP] prepare_workspace: start"
  mkdir -p /workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/{config,disk,logs,temp/{download,upload},ui}
  cp /work/${APP_NAME}_${APP_NAME}/config/feature.config \
     /workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/config/
  # UI static assets must be physically present at the path Java Spark reads from
  # Simulator.properties::uiFolderLocation; mkdir alone leaves Spark serving 404s.
  if [ -d "/work/${APP_NAME}_${APP_NAME}/ui" ]; then
    cp -a /work/${APP_NAME}_${APP_NAME}/ui/. \
          /workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/ui/ 2>/dev/null || true
  fi
  echo "[STEP] prepare_workspace: done"
}

# -----------------------------------------------------------------------------
# check_mqtt_availability (T3)
# -----------------------------------------------------------------------------
check_mqtt_availability() {
  echo "[STEP] check_mqtt_availability: start"
  MQTT_OK=0
  CONFIG="/workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/config/feature.config"
  if ! grep -q '"mqtt"' "${CONFIG}" 2>/dev/null; then
    echo "[WARN] MQTT section absent in feature.config — UI will render but data feed idle. See references/run-app-details.md#mqtt" >&2
    return
  fi
  MQTT_HOST=$(grep -A5 '"mqtt"' "${CONFIG}" | grep '"host"' | head -1 | sed 's/.*"host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  MQTT_PORT=$(grep -A5 '"mqtt"' "${CONFIG}" | grep '"port"' | head -1 | sed 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
  # bash /dev/tcp is a built-in — no external nc needed
  if (exec 3<>/dev/tcp/"${MQTT_HOST:-127.0.0.1}"/"${MQTT_PORT:-1883}") 2>/dev/null; then
    MQTT_OK=1
    echo "[STEP] MQTT broker ${MQTT_HOST:-127.0.0.1}:${MQTT_PORT:-1883} reachable"
  else
    echo "[WARN] MQTT broker ${MQTT_HOST:-127.0.0.1}:${MQTT_PORT:-1883} unreachable — UI will render but data feed idle. See references/run-app-details.md#mqtt" >&2
  fi
}

# -----------------------------------------------------------------------------
# run_cpp_build (T3) — 5 steps, out-of-tree build under /tmp
# -----------------------------------------------------------------------------
run_cpp_build() {
  echo "[STEP] run_cpp_build: start"

  # 1) expand deps into /usr/local
  cd /usr/local
  tar xJf /work/${APP_NAME}_CPP_SDK/dependencies/x86_64.tar.xz \
    || { echo "[STEP] deps extract failed"; exit 1; }

  # 2) SDK configure + build + install (out-of-tree under /tmp)
  cd /work/${APP_NAME}_CPP_SDK
  cmake -B /tmp/sdk_build -DCMAKE_BUILD_TYPE=Release -H. \
    || { echo "[STEP] cmake SDK configure failed"; exit 1; }
  cmake --build /tmp/sdk_build --target install -- -j4 \
    || { echo "[STEP] cmake SDK install failed"; exit 1; }

  # 3) runtime .so workaround — copy into /usr/local/bin for dlopen lookup
  cp -L /usr/local/lib/lib${APP_NAME_LOWER}-nevonex.so /usr/local/bin/ \
    || { echo "[STEP] runtime .so workaround failed"; exit 1; }

  # 4) App configure + build + install (out-of-tree under /tmp)
  cd /work/${APP_NAME}_${APP_NAME}
  cmake -B /tmp/app_build -DCMAKE_BUILD_TYPE=Release -H. \
    || { echo "[STEP] cmake APP configure failed"; exit 1; }
  cmake --build /tmp/app_build --target install -- -j4 \
    || { echo "[STEP] cmake APP install failed"; exit 1; }

  # 5) verify installed binary
  test -x /usr/local/bin/${APP_NAME_LOWER}_app \
    || { echo "[ERROR] app binary not installed"; exit 1; }
  echo "[STEP] run_cpp_build: done"
}

# -----------------------------------------------------------------------------
# run_app_bg (T5)
# -----------------------------------------------------------------------------
run_app_bg() {
  echo "[STEP] run_app_bg: start"
  export LD_LIBRARY_PATH=/usr/local/lib
  export FEATURE_CONFIG=/workspace/${APP_NAME}/${APP_NAME}_${APP_NAME}/config/feature.config
  test -f "${FEATURE_CONFIG}" || { echo "[ERROR] FEATURE_CONFIG missing at ${FEATURE_CONFIG}"; exit 1; }
  mkdir -p /workspace/${APP_NAME}/logs
  /usr/local/bin/${APP_NAME_LOWER}_app > /workspace/${APP_NAME}/logs/app.log 2>&1 &
  APP_PID=$!
  echo "[RUN] app PID=${APP_PID}"
  sleep 5
  kill -0 "${APP_PID}" 2>/dev/null || {
    echo "[ERROR] app died within 5s"
    tail -50 /workspace/${APP_NAME}/logs/app.log
    exit 1
  }
}

# -----------------------------------------------------------------------------
# run_test_simulator_fg (T5) — main class: TestSimulator (NOT UIWebServiceProvider)
# -----------------------------------------------------------------------------
run_test_simulator_fg() {
  echo "[STEP] run_test_simulator_fg: start"
  cd /work/com.bosch.fsp.${APP_NAME}.gen.tests
  mkdir -p bin
  javac -d bin -cp "testlib/*" $(find src -name "*.java")
  export FEATURE_CONFIG=$(pwd)/feature.config
  echo "[TEST] launching TestSimulator"
  java -cp "bin:testlib/*" com.bosch.nevonex.sdk.test.TestSimulator
}

# -----------------------------------------------------------------------------
# run_ui_bootstrap_fg — MQTT-less UI path
#
# FD's local simulation flow puts a Java Spark server (TestCustomUI +
# UIWebServiceProvider in com.bosch.fsp.*.gen.tests) on port 6563 to serve the
# UI and bridge MQTT to WebSocket. TestFilClient.main() normally boots that
# server, then immediately tries to publish over MQTT — without a broker the
# publish call throws and the JVM exits, taking the UI down with it.
#
# This bootstrap runs only the Spark side: loadFeatureConfiguration +
# TestCustomUI.mockServices(), then blocks forever. The C++ app still runs in
# the background; the IMU data feed is simply empty (no broker), but the UI
# renders. Generated into /tmp/ui_boot so we do not mutate the user's src/.
# -----------------------------------------------------------------------------
run_ui_bootstrap_fg() {
  echo "[STEP] run_ui_bootstrap_fg: start (no MQTT broker — static UI only)"
  cd /work/com.bosch.fsp.${APP_NAME}.gen.tests
  mkdir -p bin
  javac -d bin -cp "testlib/*" $(find src -name "*.java")

  mkdir -p /tmp/ui_boot/com/bosch/nevonex/sdk/test
  cat > /tmp/ui_boot/com/bosch/nevonex/sdk/test/LocalUIBootstrap.java <<'EOF'
package com.bosch.nevonex.sdk.test;

public class LocalUIBootstrap {
  public static void main(String[] args) throws Exception {
    com.bosch.fsp.runtime.util.internal.FeatureConfig.getInstance().loadFeatureConfiguration();
    TestCustomUI ui = new TestCustomUI();
    ui.mockServices();
    System.out.println("[RUN] UI bootstrap ready on :6563 (MQTT-less mode). Ctrl+C to stop.");
    Thread.currentThread().join();
  }
}
EOF
  javac -d /tmp/ui_boot -cp "bin:testlib/*" /tmp/ui_boot/com/bosch/nevonex/sdk/test/LocalUIBootstrap.java

  export FEATURE_CONFIG=$(pwd)/feature.config
  java -cp "bin:testlib/*:/tmp/ui_boot" com.bosch.nevonex.sdk.test.LocalUIBootstrap
}

# -----------------------------------------------------------------------------
# run_java_app_fg (T2 spike) — Java codegen-type build + jar + 6563 bind WARN
#
# Scope: build Maven app, launch the manifest Main-Class jar, and check whether
# port 6563 binds within 20s. Full UI integration (TestSimulator wiring,
# ApplicationMain ↔ Spark, ipAddress reslove) lives in v0.5.1 — here a missing
# bind is a [WARN] only, not a failure. Java sources are read-only; only
# target/ artifacts are written.
# -----------------------------------------------------------------------------
run_java_app_fg() {
  local jar="target/${APP_NAME}-1.0.0-jar-with-dependencies.jar"
  local app_dir="/work/${APP_NAME}_${APP_NAME}/${APP_NAME}"

  echo "[STEP] run_java_app_fg: build"
  cd "${app_dir}"
  mvn -B -q -DskipTests package

  if [ ! -f "${jar}" ]; then
    echo "[ERROR] run_java_app_fg: jar not found at ${app_dir}/${jar}"
    exit 1
  fi
  echo "[STEP] run_java_app_fg: jar=${jar}"

  java -jar "${jar}" &
  APP_PID=$!
  echo "[RUN] java app PID=${APP_PID}"

  # 20s × 1s — port 6563 bind probe (WARN-level: missing bind is non-fatal in v0.5)
  local bound=0
  for i in $(seq 1 20); do
    if (exec 3<>/dev/tcp/127.0.0.1/6563) 2>/dev/null; then
      bound=1
      break
    fi
    if ! kill -0 "${APP_PID}" 2>/dev/null; then
      echo "[ERROR] run_java_app_fg: java process died before 6563 bind"
      exit 1
    fi
    sleep 1
  done
  if [ "${bound}" = "1" ]; then
    echo "[STEP] run_java_app_fg: 6563 bound"
  else
    echo "[WARN] run_java_app_fg: 6563 not bound within 20s (Java UI integration deferred to v0.5.1)"
  fi

  wait "${APP_PID}"
}

# -----------------------------------------------------------------------------
# main (exact order)
# -----------------------------------------------------------------------------
main() {
  case "${APP_TYPE:-cpp}" in
    java)
      run_java_app_fg
      ;;
    cpp|*)
      prepare_hamcrest
      prepare_workspace
      check_mqtt_availability
      run_cpp_build
      run_app_bg
      # Java Spark (UIWebServiceProvider, port 6563) is the UI owner in local mode.
      # It always runs foreground; the MQTT side (TestFilClient publisher) is only
      # attached when a broker is reachable.
      if [ "${MQTT_OK:-0}" = "1" ]; then
        run_test_simulator_fg
      else
        run_ui_bootstrap_fg
      fi
      ;;
  esac
}

main "$@"
