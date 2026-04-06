#!/usr/bin/env bash
#
# build-fif.sh — Build a deployable FIF package for SeamOS apps (Java & C++)
#
# Usage:
#   ./build-fif.sh [project_root]
#
# Environment:
#   NVX_DOCKER_IMAGE - Docker registry image (default: public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0)
#   FEATURE_NAME     - Override feature name (default: basename of project root)
#   APP_TYPE         - Force app type: "java" or "cpp" (default: auto-detect)
#   ARCH_TYPE        - Target architecture: "aarch64", "arm32", "x86_64" (default: aarch64)
#
set -euo pipefail

PROJ_ROOT="${1:-$PWD}"
cd "$PROJ_ROOT"

FEATURE_NAME="${FEATURE_NAME:-$(basename "$PROJ_ROOT")}"
FSP_PATH="$PROJ_ROOT/com.bosch.fsp.$FEATURE_NAME"
CONTAINER="nvx-fif-gen-cntr"
NVX_DOCKER_IMAGE="${NVX_DOCKER_IMAGE:-public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0}"
NVX_VERSION="${NVX_DOCKER_IMAGE##*:}"
ARCH_TYPE="${ARCH_TYPE:-aarch64}"

# ── Step 1: Docker check ──────────────────────────────────
echo "[1/7] Checking Docker..."

DOCKER_BIN=""
for p in /usr/bin/docker /usr/local/bin/docker /snap/bin/docker; do
    [ -x "$p" ] && DOCKER_BIN="$p" && break
done
[ -z "$DOCKER_BIN" ] && DOCKER_BIN=$(command -v docker 2>/dev/null || true)

if [ -z "$DOCKER_BIN" ]; then
    echo "ERROR: Docker is not installed."
    echo "  Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y docker.io"
    echo "  macOS: brew install --cask docker"
    echo "  Official docs: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running."
    echo "  Linux: sudo systemctl start docker"
    echo "  macOS: open -a Docker"
    exit 1
fi

echo "[1/7] Docker OK ($DOCKER_BIN)"

# ── Step 2: Project validation + app type detection ────────
echo "[2/7] Validating project..."

if [ ! -d "$FSP_PATH" ]; then
    echo "ERROR: FSP directory not found: $FSP_PATH"
    echo "  Expected: com.bosch.fsp.$FEATURE_NAME/"
    exit 1
fi

# Auto-detect app type if not forced
if [ -z "${APP_TYPE:-}" ]; then
    FDPROPS="$FSP_PATH/FDProject.props"
    if [ -f "$FDPROPS" ]; then
        if grep -q "^JAVA_APP_PATH=" "$FDPROPS" 2>/dev/null; then
            APP_TYPE="java"
        elif grep -q "^CPP_APP_PATH=" "$FDPROPS" 2>/dev/null; then
            APP_TYPE="cpp"
        fi
    fi
    # Fallback: check for CPP_SDK directory
    if [ -z "${APP_TYPE:-}" ]; then
        if [ -d "$PROJ_ROOT/${FEATURE_NAME}_CPP_SDK" ] || [ -f "$PROJ_ROOT/${FEATURE_NAME}_CPP_SDK.zip" ]; then
            APP_TYPE="cpp"
        else
            APP_TYPE="java"
        fi
    fi
fi

# Resolve paths based on app type
SDK_PATH="$PROJ_ROOT/${FEATURE_NAME}_CPP_SDK"

if [ "$APP_TYPE" = "cpp" ]; then
    # Parse APP_PATH from FDProject.props: CPP_APP_PATH="cmake|<dir_name>"
    CPP_APP_DIR=""
    FDPROPS="$FSP_PATH/FDProject.props"
    if [ -f "$FDPROPS" ]; then
        CPP_APP_DIR=$(grep "^CPP_APP_PATH=" "$FDPROPS" 2>/dev/null | sed 's/^CPP_APP_PATH="\{0,1\}cmake|\{0,1\}//' | sed 's/"\{0,1\}$//')
    fi
    if [ -n "$CPP_APP_DIR" ]; then
        APP_PATH="$PROJ_ROOT/$CPP_APP_DIR"
    else
        # Fallback: find first directory with CMakeLists.txt that isn't the SDK
        APP_PATH=""
        for d in "$PROJ_ROOT"/*/; do
            dname=$(basename "$d")
            [ "$dname" = "com.bosch.fsp.$FEATURE_NAME" ] && continue
            [ "$dname" = "${FEATURE_NAME}_CPP_SDK" ] && continue
            [ "$dname" = "output" ] && continue
            if [ -f "$d/CMakeLists.txt" ]; then
                APP_PATH="${d%/}"
                break
            fi
        done
        if [ -z "$APP_PATH" ]; then
            echo "ERROR: C++ app directory not found. Expected a directory with CMakeLists.txt."
            echo "  Set CPP_APP_PATH in FDProject.props or check project structure."
            exit 1
        fi
    fi

    # Validate SDK
    if [ ! -d "$SDK_PATH" ] && [ ! -f "${SDK_PATH}.zip" ]; then
        echo "ERROR: C++ SDK not found: $SDK_PATH (or ${SDK_PATH}.zip)"
        echo "  Expected: ${FEATURE_NAME}_CPP_SDK/"
        exit 1
    fi

    # Validate app directory
    if [ ! -d "$APP_PATH" ]; then
        echo "ERROR: C++ app directory not found: $APP_PATH"
        exit 1
    fi
else
    # Parse APP_PATH from FDProject.props: JAVA_APP_PATH="mvn|<dir_name>"
    JAVA_APP_DIR=""
    FDPROPS="$FSP_PATH/FDProject.props"
    if [ -f "$FDPROPS" ]; then
        JAVA_APP_DIR=$(grep "^JAVA_APP_PATH=" "$FDPROPS" 2>/dev/null | sed 's/^JAVA_APP_PATH="\{0,1\}mvn|\{0,1\}//' | sed 's/"\{0,1\}$//')
    fi
    if [ -n "$JAVA_APP_DIR" ]; then
        APP_PATH="$PROJ_ROOT/$JAVA_APP_DIR"
    else
        # Fallback: use FEATURE_NAME as app directory
        APP_PATH="$PROJ_ROOT/$FEATURE_NAME"
    fi

    if [ ! -f "$APP_PATH/pom.xml" ]; then
        echo "ERROR: pom.xml not found: $APP_PATH/pom.xml"
        echo "  Expected: $(basename "$APP_PATH")/pom.xml"
        echo "  Check JAVA_APP_PATH in FDProject.props or verify project structure."
        exit 1
    fi
fi

echo "[2/7] Project validated"
echo "  Feature: $FEATURE_NAME"
echo "  Type: $APP_TYPE"
echo "  FSP: $FSP_PATH"
echo "  App: $APP_PATH"
[ "$APP_TYPE" = "cpp" ] && echo "  SDK: $SDK_PATH"
echo "  Arch: $ARCH_TYPE"
echo "  Docker Image: $NVX_DOCKER_IMAGE"

# Auto-cleanup on exit
cleanup() {
    docker rm -f "$CONTAINER" 2>/dev/null
    rm -rf /tmp/nvx
}
trap cleanup EXIT

# ── Step 3: Pre-build (Java only) ─────────────────────────
if [ "$APP_TYPE" = "java" ]; then
    echo "[3/7] Installing gen JAR and building app..."

    GEN_PATH="$PROJ_ROOT/com.bosch.fsp.$FEATURE_NAME.gen"
    GEN_JAR="$GEN_PATH/target/${FEATURE_NAME}-1.0.0.jar"
    GEN_POM="$GEN_PATH/pom.xml"

    if [ ! -f "$GEN_JAR" ]; then
        echo "ERROR: gen JAR not found: $GEN_JAR"
        echo "  Build the gen project first: cd com.bosch.fsp.$FEATURE_NAME.gen && mvn package"
        exit 1
    fi

    # Install gen JAR + POM to local Maven repo (-DpomFile required for transitive deps)
    mvn install:install-file \
        -Dfile="$GEN_JAR" \
        -DpomFile="$GEN_POM" \
        -q
    echo "  gen JAR installed to local Maven repo"

    cd "$APP_PATH" && mvn package -q -DskipTests
    cd "$PROJ_ROOT"

    JAR_FILE=$(ls "$APP_PATH"/target/*-jar-with-dependencies.jar 2>/dev/null | head -1)
    if [ -z "$JAR_FILE" ]; then
        echo "ERROR: jar-with-dependencies JAR not found in $APP_PATH/target/"
        echo "  Check maven-assembly-plugin configuration in pom.xml"
        exit 1
    fi
    JAR_BASENAME=$(basename "$JAR_FILE")
    echo "[3/7] JAR build complete: $JAR_BASENAME"
else
    echo "[3/7] C++ project — no pre-build needed (built inside container)"
    JAR_FILE=""
    JAR_BASENAME=""
fi

# ── Step 4: Docker image pull ──────────────────────────────
echo "[4/7] Checking Docker image..."

if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "nvx-fif-gen:${NVX_VERSION}"; then
    echo "[4/7] Pulling Docker image... (this may take a while)"
    docker pull "$NVX_DOCKER_IMAGE"
    docker tag "$NVX_DOCKER_IMAGE" "nvx-fif-gen:${NVX_VERSION}"
    echo "[4/7] Docker image ready: nvx-fif-gen:${NVX_VERSION}"
else
    echo "[4/7] Docker image cached (skip pull)"
fi

# ── Step 5: Prepare build files ────────────────────────────
echo "[5/7] Preparing build files..."

rm -rf /tmp/nvx

if [ "$APP_TYPE" = "java" ]; then
    mkdir -p /tmp/nvx/{fsp_proj,app_proj,java_app_jar}

    cp -r "$FSP_PATH" /tmp/nvx/fsp_proj/
    cp -r "$APP_PATH" /tmp/nvx/app_proj/
    # Remove target/ to prevent duplicate JAR glob match in container's package_java.sh
    rm -rf "/tmp/nvx/app_proj/$(basename "$APP_PATH")/target"
    # Exclude DB files from FIF package
    rm -f /tmp/nvx/app_proj/*/disk/*.mv.db /tmp/nvx/app_proj/*/disk/*.trace.db /tmp/nvx/app_proj/*/disk/*.mv.db.backup_*
    cp "$JAR_FILE" /tmp/nvx/java_app_jar/
else
    mkdir -p /tmp/nvx/{fsp_proj,app_proj,sdk_proj}

    # Handle SDK ZIP for 9.0.0+
    if [ ! -d "$SDK_PATH" ] && [ -f "${SDK_PATH}.zip" ]; then
        echo "  Extracting SDK ZIP..."
        unzip -q "${SDK_PATH}.zip" -d "$SDK_PATH"
        SDK_EXTRACTED=1
    else
        SDK_EXTRACTED=0
    fi

    cp -r "$FSP_PATH" /tmp/nvx/fsp_proj/
    cp -r "$APP_PATH" /tmp/nvx/app_proj/
    cp -r "$SDK_PATH" /tmp/nvx/sdk_proj/

    # Clean up extracted SDK if we unzipped it
    if [ "$SDK_EXTRACTED" = "1" ]; then
        rm -rf "$SDK_PATH"
    fi
fi

echo "[5/7] Build files ready"

# ── Step 6: Docker container FIF build ─────────────────────
echo "[6/7] Starting FIF build..."

docker rm -f "$CONTAINER" 2>/dev/null || true

docker run -d --name "$CONTAINER" "nvx-fif-gen:${NVX_VERSION}" tail -f /dev/null

echo "[6/7] Copying files to container..."
docker cp /tmp/nvx/fsp_proj/. "$CONTAINER":/usr/nvx/tmp-workspace/
docker cp /tmp/nvx/app_proj/. "$CONTAINER":/usr/nvx/tmp-workspace/

if [ "$APP_TYPE" = "java" ]; then
    docker cp /tmp/nvx/java_app_jar/. "$CONTAINER":/usr/nvx/tmp-workspace/
else
    docker cp /tmp/nvx/sdk_proj/. "$CONTAINER":/usr/nvx/tmp-workspace/
fi

echo "[6/7] Generating FIF... (this may take a while)"
docker exec "$CONTAINER" /usr/share/build.sh \
    "$FEATURE_NAME" \
    "$(basename "$APP_PATH")" \
    "$(basename "$FSP_PATH")" \
    "$APP_TYPE" \
    "/usr/nvx/workspace/$FEATURE_NAME/$(basename "$SDK_PATH")" \
    "/usr/nvx/workspace/$FEATURE_NAME/$JAR_BASENAME" \
    "$ARCH_TYPE"

# ── Step 7: Copy results to seamos-assets/builds/ ─────────
echo "[7/7] Copying results..."

# Extract from container to temp location first
docker cp "$CONTAINER":/fif_output /tmp/nvx/fif_output

# Copy .fif files to seamos-assets/builds/ for skill chaining (upload-app, update-app)
BUILD_DIR="$PROJ_ROOT/seamos-assets/builds"
mkdir -p "$BUILD_DIR"
cp /tmp/nvx/fif_output/*.fif "$BUILD_DIR/" 2>/dev/null

FIF_FILE=$(ls "$BUILD_DIR"/*.fif 2>/dev/null | head -1)
if [ -n "$FIF_FILE" ]; then
    FIF_SIZE=$(du -h "$FIF_FILE" | cut -f1)
    echo ""
    echo "[7/7] FIF build complete!"
    echo "  Type: $APP_TYPE"
    echo "  File: $FIF_FILE"
    echo "  Size: $FIF_SIZE"
    echo "  Output: $BUILD_DIR/"
else
    echo ""
    echo "WARNING: FIF file not found. Check container logs: docker logs $CONTAINER"
    exit 1
fi
