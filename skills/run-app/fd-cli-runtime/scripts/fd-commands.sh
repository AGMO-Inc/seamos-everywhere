#!/bin/bash
set -e

COMMAND=${1:-help}
PROJECT=${2:-}

WORKSPACE="/workspace"

usage() {
  cat <<'EOF'
FeatureDesigner CLI Commands:

  create <name> [opts]  Create new project (--plugins GPSPlugin,CanGenericIO --port 1456 --type java|cpp)
  open                  Start FeatureDesigner GUI (use via docker compose)
  build <project>       Build project (Maven for Java, CMake for C++)
  run <project>         Run application
  test <project>        Run TestSimulator
  list-plugins          List available plugins
  info <project>        Show project info (.fsp, Manifest.xml)
  help                  Show this help message

Examples:
  fd-commands.sh create myapp --plugins GPSPlugin
  fd-commands.sh build myapp
  fd-commands.sh run myapp
  fd-commands.sh test myapp
EOF
}

require_project() {
  if [ -z "$PROJECT" ]; then
    echo "Error: project name required"
    echo "Usage: fd-commands.sh $COMMAND <project>"
    exit 1
  fi
  if [ ! -d "$WORKSPACE/$PROJECT" ]; then
    echo "Error: project '$PROJECT' not found in $WORKSPACE/"
    echo "Available projects:"
    ls -1 "$WORKSPACE/" 2>/dev/null | grep -v '^IDT_OFFLINE_DATA$' || echo "  (none)"
    exit 1
  fi
}

# 프로젝트 타입 감지: java 또는 cpp
detect_project_type() {
  local proj_dir="$WORKSPACE/$PROJECT"
  if [ -d "$proj_dir/${PROJECT}_CPP_SDK" ] || [ -d "$proj_dir/${PROJECT}_${PROJECT}" ]; then
    echo "cpp"
  elif [ -d "$proj_dir/$PROJECT" ] && [ -f "$proj_dir/$PROJECT/pom.xml" ]; then
    echo "java"
  else
    echo "unknown"
  fi
}

# Java 앱 디렉토리
java_app_dir() {
  echo "$WORKSPACE/$PROJECT/$PROJECT"
}

# C++ 앱 디렉토리
cpp_app_dir() {
  echo "$WORKSPACE/$PROJECT/${PROJECT}_${PROJECT}"
}

# C++ SDK 디렉토리
cpp_sdk_dir() {
  echo "$WORKSPACE/$PROJECT/${PROJECT}_CPP_SDK"
}

# Eclipse Plugin layout (no pom.xml, just src/ + bin/ + lib-or-testlib/) compiler.
# FD Headless emits *.gen and *.gen.tests as PDE plugins, not Maven modules,
# so when there's no pom.xml we must compile manually with javac.
# Args: $1 = plugin dir, $2 = comma-separated extra cp dirs (e.g. sibling gen/bin)
compile_eclipse_plugin() {
  local PLUGIN_DIR="$1"
  local EXTRA_CP="${2:-}"
  local SRC_DIR="$PLUGIN_DIR/src"
  local BIN_DIR="$PLUGIN_DIR/bin"

  if [ ! -d "$SRC_DIR" ]; then
    return 0
  fi
  # Skip if bin/ already populated AND newer than every src file (Eclipse-cached).
  if [ -d "$BIN_DIR" ] && [ -n "$(find "$BIN_DIR" -name '*.class' -print -quit 2>/dev/null)" ]; then
    local NEW_SRC
    NEW_SRC=$(find "$SRC_DIR" -name '*.java' -newer "$BIN_DIR" -print -quit 2>/dev/null || true)
    if [ -z "$NEW_SRC" ]; then
      echo "[compile_eclipse_plugin] $(basename "$PLUGIN_DIR"): bin/ up-to-date, skipping"
      return 0
    fi
  fi

  echo "[compile_eclipse_plugin] javac $(basename "$PLUGIN_DIR") src/ → bin/"
  mkdir -p "$BIN_DIR"

  local CP=""
  for jar in "$PLUGIN_DIR"/lib/*.jar "$PLUGIN_DIR"/testlib/*.jar; do
    [ -f "$jar" ] && CP="${CP:+$CP:}$jar"
  done
  if [ -n "$EXTRA_CP" ]; then
    CP="${CP:+$CP:}$EXTRA_CP"
  fi

  local SRC_LIST
  SRC_LIST=$(mktemp)
  find "$SRC_DIR" -name '*.java' >"$SRC_LIST"
  if [ ! -s "$SRC_LIST" ]; then
    rm -f "$SRC_LIST"
    return 0
  fi
  # -source/-target 1.8 matches Bundle-RequiredExecutionEnvironment in the manifests.
  if ! javac -encoding UTF-8 -source 1.8 -target 1.8 \
         ${CP:+-cp "$CP"} -d "$BIN_DIR" "@$SRC_LIST" 2>&1; then
    rm -f "$SRC_LIST"
    echo "[compile_eclipse_plugin] WARNING: javac failed for $PLUGIN_DIR"
    return 1
  fi
  rm -f "$SRC_LIST"

  # Copy resources (non-.java) so Class.getResource() lookups work from bin/.
  (cd "$SRC_DIR" && find . -type f ! -name '*.java' -exec cp --parents {} "$BIN_DIR"/ \; 2>/dev/null || true)
}

# mosquitto가 1883 포트에서 수신 중인지 확인, 아니면 시작
ensure_mosquitto() {
  if pgrep -x mosquitto > /dev/null 2>&1; then
    return 0
  fi

  echo "Starting MQTT broker (mosquitto)..."
  mkdir -p /run/mosquitto /var/log/mosquitto /var/lib/mosquitto 2>/dev/null || true
  chown mosquitto:mosquitto /run/mosquitto /var/log/mosquitto /var/lib/mosquitto 2>/dev/null || true

  # 시스템 설정으로 시작 시도, 실패 시 최소 설정으로 재시도
  mosquitto -d -c /etc/mosquitto/mosquitto.conf 2>/dev/null \
    || mosquitto -d -p 1883 2>/dev/null \
    || true

  # 프로세스 대기 (최대 3초)
  for i in $(seq 1 6); do
    if pgrep -x mosquitto > /dev/null 2>&1; then
      echo "MQTT broker started on port 1883."
      return 0
    fi
    sleep 0.5
  done

  echo "Warning: MQTT broker may not have started. Check mosquitto logs."
}

case "$COMMAND" in
  create)
    shift
    exec python3 /opt/fd-cli/scripts/fd-create.py create "$@"
    ;;

  build)
    require_project
    PROJECT_TYPE=$(detect_project_type)

    if [ "$PROJECT_TYPE" = "java" ]; then
      GEN_DIR="$WORKSPACE/$PROJECT/com.bosch.fsp.${PROJECT}.gen"
      APP_DIR=$(java_app_dir)

      # SDK gen 모듈 빌드 (존재하는 경우 — Maven 우선, 없으면 Eclipse Plugin javac 폴백)
      if [ -d "$GEN_DIR" ]; then
        if [ -f "$GEN_DIR/pom.xml" ]; then
          echo "=== Building SDK gen module (Maven) ==="
          cd "$GEN_DIR"
          mvn install -q
          echo "SDK gen module built successfully."
        else
          echo "=== Building SDK gen module (Eclipse Plugin / javac) ==="
          compile_eclipse_plugin "$GEN_DIR"
        fi
      fi

      # 앱 빌드
      if [ -d "$APP_DIR" ]; then
        echo "=== Building application (Maven) ==="
        cd "$APP_DIR"
        mvn package -q
        echo "Application built successfully."
      else
        echo "Error: application directory not found: $APP_DIR"
        exit 1
      fi

      # Build gen.tests if present (Maven 우선, 없으면 javac 폴백)
      GEN_TESTS_DIR="$WORKSPACE/$PROJECT/com.bosch.fsp.${PROJECT}.gen.tests"
      if [ -d "$GEN_TESTS_DIR" ]; then
        if [ -f "$GEN_TESTS_DIR/pom.xml" ]; then
          echo "=== Building test module (Maven) ==="
          cd "$GEN_TESTS_DIR"
          mvn package -q -DskipTests
          mvn dependency:copy-dependencies -q -DoutputDirectory=target/dependency
          echo "Test module built successfully."
        else
          echo "=== Building test module (Eclipse Plugin / javac) ==="
          compile_eclipse_plugin "$GEN_TESTS_DIR" "$GEN_DIR/bin"
        fi
      fi

    elif [ "$PROJECT_TYPE" = "cpp" ]; then
      SDK_DIR=$(cpp_sdk_dir)
      APP_DIR=$(cpp_app_dir)
      BUILD_DIR="$WORKSPACE/$PROJECT/build"
      INSTALL_DIR="$WORKSPACE/$PROJECT/install"

      # C++ 의존성 추출 (Boost, EMF4CPP, FCAL 등 — 아카이브에 포함)
      # Archive may live in (a) SDK/dependencies/ (legacy FD Headless), or
      # (b) inside the fd-cli image at /opt/nevonex/configuration/org.eclipse.osgi/<id>/.cp/dependencies/
      # (fd-cli ≥ 2026-02-26 — FD no longer ships it via SDK).
      BUILD_NUMBER=$(cat "$SDK_DIR/CMakeLists.txt" 2>/dev/null | grep -oP 'set\(LIB_BUILD_NUMBER "\K[^"]+' | head -1)
      DEPS_DIR="/workspace/.nevonex/dependencies/${BUILD_NUMBER}"
      DEPS_ARCHIVE=""
      for cand in \
        "$SDK_DIR/dependencies/INSTALL_x86_64.tar.xz" \
        "$SDK_DIR/dependencies/x86_64.tar.xz"; do
        if [ -f "$cand" ]; then DEPS_ARCHIVE="$cand"; break; fi
      done
      if [ -z "$DEPS_ARCHIVE" ]; then
        DEPS_ARCHIVE=$(find /opt/nevonex/configuration/org.eclipse.osgi -path '*/dependencies/INSTALL_x86_64.tar.xz' -print -quit 2>/dev/null || true)
      fi
      if [ ! -d "$DEPS_DIR/lib" ] && [ -n "$DEPS_ARCHIVE" ] && [ -f "$DEPS_ARCHIVE" ]; then
        echo "=== Extracting C++ dependencies ==="
        echo "Source: $DEPS_ARCHIVE"
        mkdir -p "$DEPS_DIR"
        xz -dc "$DEPS_ARCHIVE" | tar xf - -C "$DEPS_DIR"
        echo "Dependencies extracted to $DEPS_DIR"
      fi

      # SDK 빌드
      if [ -d "$SDK_DIR" ]; then
        echo "=== Building C++ SDK ==="
        mkdir -p "$BUILD_DIR/sdk_release"
        cmake -B "$BUILD_DIR/sdk_release" -S "$SDK_DIR" \
          -G 'Eclipse CDT4 - Unix Makefiles' \
          -DCMAKE_ECLIPSE_GENERATE_LINKED_RESOURCES=FALSE \
          -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
          -DCMAKE_PREFIX_PATH="$DEPS_DIR" \
          -DCMAKE_BUILD_TYPE=Release
        cd "$BUILD_DIR/sdk_release"
        make -j"$(nproc --ignore=1)" all
        make install
        echo "C++ SDK built successfully."
      fi

      # 앱 빌드
      if [ -d "$APP_DIR" ]; then
        echo "=== Building C++ application ==="
        mkdir -p "$BUILD_DIR/${PROJECT}_debug"
        cmake -B "$BUILD_DIR/${PROJECT}_debug" -S "$APP_DIR" \
          -G 'Eclipse CDT4 - Unix Makefiles' \
          -DCMAKE_ECLIPSE_GENERATE_LINKED_RESOURCES=FALSE \
          -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
          -DCMAKE_PREFIX_PATH="${DEPS_DIR};$INSTALL_DIR" \
          -DCMAKE_BUILD_TYPE=Debug
        cd "$BUILD_DIR/${PROJECT}_debug"
        make -j"$(nproc --ignore=1)" all
        # SDK shared lib 복사
        SDK_LIB=$(find "$BUILD_DIR/sdk_release" -name "lib*-nevonex.so.*" 2>/dev/null | head -1)
        if [ -n "$SDK_LIB" ]; then
          cp "$SDK_LIB" "$BUILD_DIR/${PROJECT}_debug/src-gen/$(basename "$SDK_LIB" | sed 's/\.so\..*/\.so/')"
        fi
        echo "C++ application built successfully."
      else
        echo "Error: C++ application directory not found: $APP_DIR"
        exit 1
      fi

      # Build Java gen SDK (gen.tests의 의존성으로 필요)
      # FD Headless emits two layouts depending on the project: Maven (pom.xml)
      # or Eclipse Plugin (META-INF/MANIFEST.MF + build.properties). Try Maven
      # first, fall back to javac for the plugin layout.
      GEN_DIR="$WORKSPACE/$PROJECT/com.bosch.fsp.${PROJECT}.gen"
      if [ -d "$GEN_DIR" ]; then
        if [ -f "$GEN_DIR/pom.xml" ]; then
          echo "=== Building SDK gen module for tests (Maven) ==="
          cd "$GEN_DIR"
          mvn install -q
          echo "SDK gen module built successfully."
        else
          echo "=== Building SDK gen module for tests (Eclipse Plugin / javac) ==="
          compile_eclipse_plugin "$GEN_DIR"
        fi
      fi

      # Build gen.tests if present (Java-based, common to both project types)
      GEN_TESTS_DIR="$WORKSPACE/$PROJECT/com.bosch.fsp.${PROJECT}.gen.tests"
      if [ -d "$GEN_TESTS_DIR" ]; then
        if [ -f "$GEN_TESTS_DIR/pom.xml" ]; then
          echo "=== Building test module (Maven) ==="
          cd "$GEN_TESTS_DIR"
          mvn package -q -DskipTests
          mvn dependency:copy-dependencies -q -DoutputDirectory=target/dependency
          echo "Test module built successfully."
        else
          echo "=== Building test module (Eclipse Plugin / javac) ==="
          compile_eclipse_plugin "$GEN_TESTS_DIR" "$GEN_DIR/bin"
        fi
      fi

    else
      echo "Error: cannot detect project type for '$PROJECT'"
      echo "Expected Java (pom.xml) or C++ (CMakeLists.txt) project structure."
      exit 1
    fi
    ;;

  run)
    require_project
    ensure_mosquitto
    PROJECT_TYPE=$(detect_project_type)

    if [ "$PROJECT_TYPE" = "java" ]; then
      APP_DIR=$(java_app_dir)
      JAR=$(find "$APP_DIR/target" -name "*-jar-with-dependencies.jar" 2>/dev/null | head -1)
      if [ -z "$JAR" ]; then
        echo "Error: JAR not found. Run 'build $PROJECT' first."
        exit 1
      fi

      # 이전 인스턴스 종료
      OLD_PID=$(pgrep -f "jar.*${PROJECT}.*jar-with-dependencies" 2>/dev/null || true)
      if [ -n "$OLD_PID" ]; then
        echo "Stopping previous $PROJECT instance (PID: $OLD_PID)..."
        kill $OLD_PID 2>/dev/null || true
        sleep 1
      fi

      echo "=== Running $PROJECT (Java) ==="
      echo "JAR: $JAR"
      cd "$APP_DIR"
      java $JAVA_OPTS -jar "$JAR"

    elif [ "$PROJECT_TYPE" = "cpp" ]; then
      BUILD_DIR="$WORKSPACE/$PROJECT/build/${PROJECT}_debug"
      BINARY=$(find "$BUILD_DIR/src-gen" -maxdepth 1 -type f -executable -name "${PROJECT,,}_app" 2>/dev/null | head -1)
      if [ -z "$BINARY" ]; then
        # 실행 가능한 파일 중 아무거나 찾기
        BINARY=$(find "$BUILD_DIR/src-gen" -maxdepth 1 -type f -executable ! -name "*.so*" 2>/dev/null | head -1)
      fi
      if [ -z "$BINARY" ]; then
        echo "Error: C++ binary not found. Run 'build $PROJECT' first."
        echo "Expected at: $BUILD_DIR/src-gen/"
        exit 1
      fi

      # 이전 인스턴스 종료
      OLD_PID=$(pgrep -f "$(basename "$BINARY")" 2>/dev/null || true)
      if [ -n "$OLD_PID" ]; then
        echo "Stopping previous $PROJECT instance (PID: $OLD_PID)..."
        kill $OLD_PID 2>/dev/null || true
        sleep 1
      fi

      echo "=== Running $PROJECT (C++) ==="
      echo "Binary: $BINARY"

      # 환경변수 설정 (Eclipse launch 파일 기준)
      APP_DIR=$(cpp_app_dir)
      NEVONEX_LIB=$(find /workspace/.nevonex/dependencies -maxdepth 2 -name "lib" -type d 2>/dev/null | head -1)
      INSTALL_LIB="$WORKSPACE/$PROJECT/install/lib"
      export LD_LIBRARY_PATH="${NEVONEX_LIB:+$NEVONEX_LIB:}${INSTALL_LIB}:$BUILD_DIR/src-gen:$BUILD_DIR/sdk/lib:${LD_LIBRARY_PATH:-}"
      export FEATURE_CONFIG="$APP_DIR/config/feature.config"

      cd "$BUILD_DIR/src-gen"
      "$BINARY"

    else
      echo "Error: cannot detect project type for '$PROJECT'"
      exit 1
    fi
    ;;

  test)
    require_project
    ensure_mosquitto

    # gen.tests: Java/C++ 공통 테스트 프로젝트
    TEST_DIR="$WORKSPACE/$PROJECT/com.bosch.fsp.${PROJECT}.gen.tests"
    if [ ! -d "$TEST_DIR" ]; then
      echo "Error: test directory not found: $TEST_DIR"
      exit 1
    fi

    # 클래스패스 구성: bin/ (컴파일된 클래스) + testlib/*.jar + resources/
    CP="$TEST_DIR/bin"
    for jar in "$TEST_DIR"/testlib/*.jar; do
      [ -f "$jar" ] && CP="$CP:$jar"
    done
    [ -d "$TEST_DIR/resources" ] && CP="$CP:$TEST_DIR/resources"

    # Maven 빌드 프로젝트인 경우 target/도 포함
    if [ -d "$TEST_DIR/target/classes" ]; then
      CP="$TEST_DIR/target/classes:$CP"
    fi
    TEST_JAR=$(find "$TEST_DIR/target" -maxdepth 1 -name "*.jar" ! -name "*sources*" ! -name "*javadoc*" 2>/dev/null | head -1)
    [ -n "$TEST_JAR" ] && CP="$TEST_JAR:$CP"
    # Maven 의존성
    for jar in "$TEST_DIR"/target/dependency/*.jar; do
      [ -f "$jar" ] && CP="$CP:$jar"
    done

    echo "=== Running TestSimulator for $PROJECT ==="
    cd "$TEST_DIR"
    java -cp "$CP" com.bosch.nevonex.sdk.test.TestSimulator
    ;;

  list-plugins)
    exec python3 /opt/fd-cli/scripts/fd-create.py list-plugins
    ;;

  info)
    require_project
    PROJECT_TYPE=$(detect_project_type)

    echo "=== Project Info: $PROJECT ==="
    echo "Type: $PROJECT_TYPE"
    echo ""

    # .fsp 파일 검색
    FSP=$(find "$WORKSPACE/$PROJECT" -name "*.fsp" 2>/dev/null | head -1)
    if [ -n "$FSP" ]; then
      echo "FSP file: $FSP"
      echo "---"
      cat "$FSP" 2>/dev/null
      echo ""
    fi

    # Manifest.xml 검색
    MANIFEST=$(find "$WORKSPACE/$PROJECT" -name "Manifest.xml" 2>/dev/null | head -1)
    if [ -n "$MANIFEST" ]; then
      echo "Manifest: $MANIFEST"
      echo "---"
      cat "$MANIFEST" 2>/dev/null
      echo ""
    fi

    if [ "$PROJECT_TYPE" = "java" ]; then
      # pom.xml 정보
      POM="$(java_app_dir)/pom.xml"
      if [ -f "$POM" ]; then
        echo "Maven POM: $POM"
        echo "---"
        grep -E '<(groupId|artifactId|version|name)>' "$POM" | head -10
        echo ""
      fi
    elif [ "$PROJECT_TYPE" = "cpp" ]; then
      # CMakeLists.txt 정보
      CMAKE="$(cpp_app_dir)/CMakeLists.txt"
      if [ -f "$CMAKE" ]; then
        echo "CMakeLists: $CMAKE"
        echo "---"
        grep -E '(PROJECT|VERSION|set\(LIB_)' "$CMAKE" | head -10
        echo ""
      fi
      # 빌드 결과물 확인
      BUILD_DIR="$WORKSPACE/$PROJECT/build/${PROJECT}_debug"
      BINARY=$(find "$BUILD_DIR/src-gen" -maxdepth 1 -type f -executable ! -name "*.so*" 2>/dev/null | head -1)
      if [ -n "$BINARY" ]; then
        echo "Binary: $BINARY"
      fi
    fi
    ;;

  help|--help|-h)
    usage
    ;;

  *)
    echo "Error: unknown command '$COMMAND'"
    usage
    exit 1
    ;;
esac
