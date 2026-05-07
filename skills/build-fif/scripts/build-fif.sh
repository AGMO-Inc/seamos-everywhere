#!/usr/bin/env bash
#
# build-fif.sh — Build a deployable FIF package for SeamOS apps (Java & C++)
#
# Usage:
#   ./build-fif.sh [user_root] [--project-name <NAME>] [--dry-run]
#
# The first positional argument is USER_ROOT (directory containing .mcp.json).
# When omitted, USER_ROOT is discovered by walking upward from $PWD (v4 CIMP-1).
#
# Environment:
#   NVX_DOCKER_IMAGE - Docker registry image (default: public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0)
#   FEATURE_NAME     - Override feature/project name (legacy alias; --project-name preferred)
#   APP_TYPE         - Force app type: "java" or "cpp" (default: auto-detect)
#   ARCH_TYPE        - Target architecture: "aarch64", "arm32", "x86_64" (default: aarch64)
#   SEAMOS_ALLOW_PWD_FALLBACK=1 — allow running without .mcp.json (test fixture escape hatch)
#
set -euo pipefail

# ─── Shared utilities (v4 CIMP-1, CCR-1) ────────────────────────────────────

# find_user_root — walk up from $PWD looking for .mcp.json (v4 CIMP-1)
find_user_root() {
  local dir
  dir="$(pwd -P)"
  while true; do
    if [[ -f "$dir/.mcp.json" ]]; then
      echo "$dir"
      return 0
    fi
    if [[ "$dir" == "/" ]]; then
      break
    fi
    dir="$(dirname "$dir")"
  done
  if [[ "${SEAMOS_ALLOW_PWD_FALLBACK:-0}" == "1" ]]; then
    echo "WARN: no .mcp.json found from $PWD upward — using \$PWD as USER_ROOT (SEAMOS_ALLOW_PWD_FALLBACK=1)" >&2
    pwd -P
    return 0
  fi
  echo "ERROR: no .mcp.json found from $PWD upward — run inside a project that has .mcp.json at its root" >&2
  return 64
}

# Deterministic PROJECT_NAME resolution (v4 CCR-1)
#   1. Explicit --project-name flag (caller sets PROJECT_NAME_FLAG)
#   2. $USER_ROOT/.seamos-context.json .last_project.name
#   3. Single glob match under $USER_ROOT/*/*/com.bosch.fsp.*
#   4. Error — multiple FSP projects or none found
resolve_project_name() {
  local user_root="$1"
  local flag="${2:-}"

  # 2. explicit flag wins
  if [[ -n "$flag" ]]; then
    echo "$flag"
    return 0
  fi

  # 1. context — use last_project.name if set
  if [[ -f "$user_root/.seamos-context.json" ]]; then
    local ctx_name
    ctx_name="$(jq -r '.last_project.name // empty' "$user_root/.seamos-context.json" 2>/dev/null || true)"
    if [[ -n "$ctx_name" ]]; then
      echo "$ctx_name"
      return 0
    fi
  fi

  # 3. single glob match across FSP directories
  shopt -s nullglob
  local matches=()
  for fsp_dir in "$user_root"/*/*/com.bosch.fsp.*; do
    [[ -d "$fsp_dir" ]] || continue
    matches+=("$fsp_dir")
  done
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 1 ]]; then
    local base
    base="$(basename "${matches[0]}")"
    echo "${base#com.bosch.fsp.}"
    return 0
  fi

  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "ERROR: no FSP project found under $user_root — run create-project first or pass --project-name" >&2
    return 64
  fi

  # 4. multiple
  local list=""
  for m in "${matches[@]}"; do
    list+="$(basename "$m" | sed 's/^com\.bosch\.fsp\.//'), "
  done
  list="${list%, }"
  echo "ERROR: multiple FSP projects found under $user_root: $list — pass --project-name <NAME> to disambiguate" >&2
  return 64
}

# disk_packaging_policy — apply disk/ allowlist (keep only disk/seed/) on a build workspace copy.
# Usage:
#   disk_packaging_policy <APP_PATH>             # apply (rm files outside disk/seed/)
#   disk_packaging_policy --dry-run <APP_PATH>   # count only, no deletion
#
# Caller MUST pass the build temp workspace copy — never the user's source workspace.
# Always returns 0 (safe under set -e).
#
# Structural safety: dry-run returns BEFORE any mutation code is reached.
# Any future mutation logic added below the dry-run early-return cannot
# affect dry-run callers, even if a caller mistakenly passes a user path.
disk_packaging_policy() {
  local dry_run=0
  if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
    shift
  fi
  local app_path="${1:-}"
  local disk_dir="$app_path/disk"

  if [[ ! -d "$disk_dir" ]]; then
    echo "(no disk/ directory)"
    return 0
  fi

  local excluded=0
  local retained=0
  local f

  # ── Count phase (no mutation) ──────────────────────────────────────────
  # Count files outside disk/seed/.
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    excluded=$((excluded + 1))
  done < <(find "$disk_dir" -type f -not -path "$disk_dir/seed/*" 2>/dev/null)

  # Count files retained under disk/seed/.
  if [[ -d "$disk_dir/seed" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      retained=$((retained + 1))
    done < <(find "$disk_dir/seed" -type f 2>/dev/null)
  fi

  # Dry-run: report and return BEFORE the mutation phase.
  if [[ $dry_run -eq 1 ]]; then
    echo "would exclude $excluded files from disk/, would retain $retained files in disk/seed/"
    return 0
  fi

  # ── Mutation phase (apply mode only — never reached by dry-run) ───────
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rm -f "$f"
  done < <(find "$disk_dir" -type f -not -path "$disk_dir/seed/*" 2>/dev/null)

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    [[ "$d" == "$disk_dir" ]] && continue
    [[ "$d" == "$disk_dir/seed" ]] && continue
    case "$d" in
      "$disk_dir/seed"/*) continue ;;
    esac
    rm -rf "$d"
  done < <(find "$disk_dir" -mindepth 1 -type d -not -path "$disk_dir/seed" -not -path "$disk_dir/seed/*" 2>/dev/null)

  echo "Excluded $excluded files from disk/, retained $retained files in disk/seed/"
  return 0
}

# ─── Parse args ─────────────────────────────────────────────────────────────
POSITIONAL_USER_ROOT=""
PROJECT_NAME_FLAG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name) PROJECT_NAME_FLAG="${2:-}"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --help|-h)
      grep '^#' "${BASH_SOURCE[0]}" | head -30
      exit 0
      ;;
    --*)
      echo "ERROR: unknown flag: $1" >&2
      exit 64
      ;;
    *)
      if [[ -z "$POSITIONAL_USER_ROOT" ]]; then
        POSITIONAL_USER_ROOT="$1"
      else
        echo "ERROR: unexpected positional argument: $1" >&2
        exit 64
      fi
      shift
      ;;
  esac
done

# ─── Resolve USER_ROOT (v4 CIMP-1) ─────────────────────────────────────────
if [[ -n "$POSITIONAL_USER_ROOT" ]]; then
  if [[ ! -d "$POSITIONAL_USER_ROOT" ]]; then
    echo "ERROR: USER_ROOT not a directory: $POSITIONAL_USER_ROOT" >&2
    exit 64
  fi
  USER_ROOT="$(cd "$POSITIONAL_USER_ROOT" && pwd -P)"
else
  USER_ROOT="$(find_user_root)" || exit 64
  USER_ROOT="$(cd "$USER_ROOT" && pwd -P)"
fi

# ─── Deterministic PROJECT_NAME resolution (v4 CCR-1) ──────────────────────
# Deterministic PROJECT_NAME resolution (v4 CCR-1):
#   1. --project-name <X>  → use flag
#   2. $USER_ROOT/.seamos-context.json .last_project.name  → use context
#   3. glob "$USER_ROOT/*/*/com.bosch.fsp.*" → single match, use it
#   4. zero / multiple matches → error out with explicit guidance
#
# NOTE: "basename $USER_ROOT" fallback is intentionally removed — USER_ROOT
#       directory name may differ from PROJECT_NAME (e.g. /tmp/seamos-e2e with
#       com.bosch.fsp.MyApp). If user wishes to override via env FEATURE_NAME,
#       they can; but deterministic resolution never falls back to basename.
if [[ -n "${FEATURE_NAME:-}" ]]; then
  # Legacy env var support — treat as explicit flag equivalent
  PROJECT_NAME="$FEATURE_NAME"
else
  PROJECT_NAME="$(resolve_project_name "$USER_ROOT" "$PROJECT_NAME_FLAG")" || exit $?
fi
FEATURE_NAME="$PROJECT_NAME"

# ─── Resolve FD_APP_ROOT / FSP_PATH (v4 CCR-1, v2 I7) ──────────────────────
# Context-preferred FD_APP_ROOT: if $USER_ROOT/.seamos-context.json has
# .last_project.app_project_path, its grandparent is FD_APP_ROOT.
# Otherwise fall back to convention: $USER_ROOT/$PROJECT_NAME/$PROJECT_NAME.
FD_APP_ROOT=""
if [[ -f "$USER_ROOT/.seamos-context.json" ]]; then
  APP_PROJECT_PATH="$(jq -r '.last_project.app_project_path // empty' "$USER_ROOT/.seamos-context.json" 2>/dev/null || true)"
  if [[ -n "$APP_PROJECT_PATH" ]]; then
    FD_APP_ROOT="$(dirname "$(dirname "$APP_PROJECT_PATH")")/$PROJECT_NAME"
    # The above yields <USER_ROOT>/<PROJECT>/<PROJECT> which is what we want
    FD_APP_ROOT="$(dirname "$APP_PROJECT_PATH")"
  fi
fi
if [[ -z "$FD_APP_ROOT" ]]; then
  FD_APP_ROOT="$USER_ROOT/$PROJECT_NAME/$PROJECT_NAME"
fi

PROJ_ROOT="$FD_APP_ROOT"  # legacy alias used by the rest of the script
FSP_PATH="$FD_APP_ROOT/com.bosch.fsp.$FEATURE_NAME"

CONTAINER="nvx-fif-gen-cntr"
NVX_DOCKER_IMAGE="${NVX_DOCKER_IMAGE:-public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0}"
NVX_VERSION="${NVX_DOCKER_IMAGE##*:}"
ARCH_TYPE="${ARCH_TYPE:-aarch64}"
BUILD_DIR="$USER_ROOT/seamos-assets/builds"

cd "$PROJ_ROOT"

# ── Step 1: Docker check ──────────────────────────────────
echo "[1/7] Checking Docker..."

# Cross-platform Docker CLI resolver (Linux / macOS / Windows Git-Bash / WSL).
# Lookup order: $DOCKER override → PATH (docker / docker.exe) → common install locations.
resolve_docker() {
    if [ -n "${DOCKER:-}" ] && [ -x "$DOCKER" ]; then
        printf '%s' "$DOCKER"; return 0
    fi
    local found
    found=$(command -v docker 2>/dev/null || true)
    [ -z "$found" ] && found=$(command -v docker.exe 2>/dev/null || true)
    if [ -n "$found" ]; then
        printf '%s' "$found"; return 0
    fi
    local p
    for p in \
        /usr/bin/docker /usr/local/bin/docker /snap/bin/docker \
        /opt/homebrew/bin/docker /Applications/Docker.app/Contents/Resources/bin/docker \
        "/c/Program Files/Docker/Docker/resources/bin/docker.exe" \
        "/c/Program Files/Docker/Docker/resources/bin/docker" \
        "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
    do
        [ -x "$p" ] && { printf '%s' "$p"; return 0; }
    done
    return 1
}

DOCKER_BIN=""
DOCKER_BIN=$(resolve_docker || true)

if [ -z "$DOCKER_BIN" ]; then
    echo "ERROR: Docker CLI not found on this system."
    echo "  Linux:   sudo apt-get install -y docker.io   (then 'sudo systemctl start docker')"
    echo "  macOS:   brew install --cask docker          (then open Docker Desktop)"
    echo "  Windows: Install Docker Desktop — https://www.docker.com/products/docker-desktop"
    echo ""
    echo "If Docker is installed but not detected, set DOCKER=/path/to/docker and retry."
    echo "  Official docs: https://docs.docker.com/engine/install/"
    exit 1
fi

# Prepend docker's directory to PATH so `docker buildx`/`docker compose` plugins resolve.
DOCKER_DIR=$(dirname "$DOCKER_BIN")
case ":$PATH:" in
    *":$DOCKER_DIR:"*) ;;
    *) export PATH="$DOCKER_DIR:$PATH" ;;
esac

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running."
    echo "  Linux:   sudo systemctl start docker"
    echo "  macOS:   open -a Docker     (wait until the whale icon shows 'Docker Desktop is running')"
    echo "  Windows: Start Docker Desktop from the Start Menu and wait for status 'Running'"
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

    # Try the props-declared path first, then auto-search.
    # A2 (2026-05): 0.7.1 의 FD Headless 가 신규 프로젝트에 잘못된 'App' suffix 가
    #   붙은 CPP_APP_PATH 를 기록하는 회귀가 있어, props 의 CPP_APP_DIR 가 가리키는
    #   디렉토리가 실제로 부재하는 사례가 발견됨. 본 스킬은 이때 fail 하지 않고
    #   PROJ_ROOT 하위에서 CMakeLists.txt 보유 디렉토리를 자동 검색해 fallback 한다.
    APP_PATH=""
    if [ -n "$CPP_APP_DIR" ] && [ -d "$PROJ_ROOT/$CPP_APP_DIR" ] && [ -f "$PROJ_ROOT/$CPP_APP_DIR/CMakeLists.txt" ]; then
        APP_PATH="$PROJ_ROOT/$CPP_APP_DIR"
    fi

    if [ -z "$APP_PATH" ]; then
        # Auto-search: first directory with CMakeLists.txt that isn't the SDK / FSP / output.
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

        if [ -n "$APP_PATH" ]; then
            if [ -n "$CPP_APP_DIR" ]; then
                # Props pointed somewhere that doesn't exist; we recovered.
                echo "WARN: FDProject.props CPP_APP_PATH=\"cmake|$CPP_APP_DIR\" points to non-existent directory ($PROJ_ROOT/$CPP_APP_DIR)."
                echo "WARN: auto-resolved C++ app directory → $APP_PATH"
                echo "WARN: edit $FDPROPS and replace CPP_APP_PATH with \"cmake|$(basename "$APP_PATH")\" to silence this warning."
            fi
        else
            echo "ERROR: C++ app directory not found. Expected a directory with CMakeLists.txt under $PROJ_ROOT."
            if [ -n "$CPP_APP_DIR" ]; then
                echo "  FDProject.props CPP_APP_PATH points to: $CPP_APP_DIR (does not exist)"
            fi
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

# ─── Dry-run output (v4 CIMP-4: expose key paths) ──────────────────────────
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] USER_ROOT=$USER_ROOT"
  echo "[dry-run] PROJECT_NAME=$PROJECT_NAME"
  echo "[dry-run] FEATURE_NAME=$FEATURE_NAME"
  echo "[dry-run] FD_APP_ROOT=$FD_APP_ROOT"
  echo "[dry-run] FSP_PATH=$FSP_PATH"
  echo "[dry-run] BUILD_DIR=$BUILD_DIR"
  echo "[dry-run] CONTEXT_FILE=$USER_ROOT/.seamos-context.json"
  echo "[dry-run] NVX_DOCKER_IMAGE=$NVX_DOCKER_IMAGE"
  echo "[dry-run] ARCH_TYPE=$ARCH_TYPE"
  echo "[dry-run] APP_TYPE: $APP_TYPE"
  echo "[dry-run] APP_PATH: $APP_PATH"
  echo "[dry-run] SDK_PATH: $SDK_PATH"
  echo "[dry-run] DISK_POLICY: will exclude disk/* except disk/seed/"
  echo "[dry-run] DISK_SCAN_RESULT: $(disk_packaging_policy --dry-run "$APP_PATH")"
  exit 0
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
    # A1: defuse stale public.ecr.aws bearer tokens before pulling. Check
    # warns when stale entry exists; user can re-run with --clean-ecr-auth
    # to auto-clean. We do not auto-clean by default — the helper edits
    # ~/.docker/config.json which is shared with the user's other tooling.
    SHARED_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/shared-references/scripts/check-ecr-public-auth.sh"
    if [ -f "$SHARED_HELPER" ]; then
        if [ "${BUILD_FIF_CLEAN_ECR_AUTH:-0}" = "1" ]; then
            bash "$SHARED_HELPER" --auto-clean || true
        else
            bash "$SHARED_HELPER" || true
        fi
    fi
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
    # Apply disk/ allowlist (keep only disk/seed/, exclude all runtime DB state)
    [ -n "$APP_PATH" ] && disk_packaging_policy "/tmp/nvx/app_proj/$(basename "$APP_PATH")"
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
    [ -n "$APP_PATH" ] && disk_packaging_policy "/tmp/nvx/app_proj/$(basename "$APP_PATH")"
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

# ── Step 7: Copy results to USER_ROOT/seamos-assets/builds/ ─────
# BUILD_DIR is fixed at USER_ROOT/seamos-assets/builds (v4 CCR-1 / TODO 14)
# so upload-app finds the FIF regardless of where the project workspace lives.
echo "[7/7] Copying results..."

# Extract from container to temp location first
docker cp "$CONTAINER":/fif_output /tmp/nvx/fif_output

# Copy .fif files to $BUILD_DIR for skill chaining (upload-app, update-app)
mkdir -p "$BUILD_DIR"
BUILD_DIR_FIFS=()
while IFS= read -r -d '' src; do
  cp "$src" "$BUILD_DIR/"
  BUILD_DIR_FIFS+=("$BUILD_DIR/$(basename "$src")")
done < <(find /tmp/nvx/fif_output -maxdepth 1 -name '*.fif' -type f -print0 | sort -z)

if [[ ${#BUILD_DIR_FIFS[@]} -eq 0 ]]; then
  echo "No FIF artifact produced" >&2
  exit 1
fi

echo "Built FIF artifacts (${#BUILD_DIR_FIFS[@]}):"
for f in "${BUILD_DIR_FIFS[@]}"; do
  echo "  - $f"
done
PRIMARY_FIF="${BUILD_DIR_FIFS[0]}"
FIF_FILE="$PRIMARY_FIF"

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
