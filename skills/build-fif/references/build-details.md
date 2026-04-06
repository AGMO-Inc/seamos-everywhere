# FIF Build Details

## Table of Contents

- [Project Directory Structure](#project-directory-structure)
- [App Type Auto-Detection](#app-type-auto-detection)
- [Java: gen JAR Dependency Handling](#java-gen-jar-dependency-handling)
- [C++: SDK and CMake](#c-sdk-and-cmake)
- [Docker Image Management](#docker-image-management)
- [invoke_offline_util.sh Mapping](#invoke_offline_utilsh-mapping)
- [build.sh Arguments](#buildsh-arguments)
- [Troubleshooting](#troubleshooting)

---

## Project Directory Structure

### Java Project
```
<FEATURE_NAME>/                  <- PROJ_ROOT
├── com.bosch.fsp.<name>/        <- FSP_PATH (FSP project)
│   └── FDProject.props          <- Contains JAVA_APP_PATH="mvn|<app_name>"
├── com.bosch.fsp.<name>.gen/    <- GEN_PATH (gen project, JAR source)
│   └── pom.xml
├── <name>/                      <- APP_PATH (app project)
│   └── pom.xml
└── seamos-assets/builds/           <- Build output
```

### C++ Project
```
<FEATURE_NAME>/                  <- PROJ_ROOT
├── com.bosch.fsp.<name>/        <- FSP_PATH (FSP project)
│   └── FDProject.props          <- Contains CPP_APP_PATH="cmake|<app_dir_name>"
├── <name>_CPP_SDK/              <- SDK_PATH (C++ SDK, CMake-based)
│   ├── CMakeLists.txt
│   └── src-gen/
├── <app_dir_name>/              <- APP_PATH (C++ app, CMake-based)
│   ├── CMakeLists.txt
│   └── src-gen/
└── seamos-assets/builds/           <- Build output
```

## App Type Auto-Detection

Detection order:
1. `APP_TYPE` env var — if set, skip detection
2. `FDProject.props` in FSP dir:
   - `JAVA_APP_PATH=` present → Java
   - `CPP_APP_PATH=` present → C++
3. Fallback: `<name>_CPP_SDK/` or `<name>_CPP_SDK.zip` exists → C++, else Java

`APP_PATH` is parsed from `FDProject.props` for both types:
```properties
# Java
JAVA_APP_PATH="mvn|apiTest"
# C++
CPP_APP_PATH="cmake|reference_cpp_2_reference_cpp_two"
```
The part after `mvn|` or `cmake|` is the app directory name.

Fallbacks when `FDProject.props` field is missing:
- **Java**: uses `$FEATURE_NAME/` as app directory (common convention)
- **C++**: scans for first directory with `CMakeLists.txt` (excluding FSP, SDK, output)

## Java: gen JAR Dependency Handling

When installing the gen project JAR to the local Maven repo, `-DpomFile` is **mandatory**.

### Why?

Using only `-Dfile` installs the JAR without its POM:
- Transitive dependencies (EMF, Spark, etc.) are missing from Maven's dependency graph
- App project `mvn package` fails with compile errors

With `-DpomFile`, all dependencies declared in the gen project's `pom.xml` are registered for proper transitive resolution.

### JAR Build

The app project uses `maven-assembly-plugin` with `jar-with-dependencies` to produce a runnable JAR. Detected via `target/*-jar-with-dependencies.jar` glob.

## C++: SDK and CMake

C++ projects consist of an SDK project and an app project, both CMake-based.

### SDK Project (`<name>_CPP_SDK/`)
- CMake-based with C++17 standard
- Dependencies: Boost, NEVONEX-FCAL-PLATFORM, FCAL, curlpp, PahoMqttCpp, jsoncpp
- Built inside the Docker container (no pre-build needed on host)

### App Project
- Links against the SDK project via `FIND_PACKAGE`
- Directory name varies — parsed from `FDProject.props`

### SDK ZIP (9.0.0+)
For Docker image version 9.0.0+, the SDK may be distributed as `<name>_CPP_SDK.zip` instead of a directory. The script auto-detects and extracts it.

## Docker Image Management

- Default image: `public.ecr.aws/g0j5z0m9/seamos/app-builder:8.5.0` (AWS Public ECR)
- Override via `NVX_DOCKER_IMAGE` environment variable
- After pull, tagged locally as `nvx-fif-gen:<version>` for caching
- Subsequent runs skip pull if local tag exists

## invoke_offline_util.sh Mapping

Each script step maps to the original `invoke_offline_util.sh` logic (non-interactive):

| Script Step | invoke_offline_util.sh Lines | Description |
|---|---|---|
| Step 5 (temp dir) | 73-99 | /tmp/nvx setup and file copy |
| Step 6 (container) | 106-125 | Docker run/cp/exec |

### Why target/ is removed (Java, Step 5)

After copying to `/tmp/nvx/app_proj/`, `target/` is deleted because the container's `package_java.sh` detects JAR files via glob — leftover `target/` causes duplicate matches and build failure.

### C++ file copy (Step 5)

C++ copies `sdk_proj/` instead of `java_app_jar/`. The SDK source is needed inside the container for CMake build.

## build.sh Arguments

```
docker exec $CONTAINER /usr/share/build.sh \
    $1: FEATURE_NAME    - Feature name
    $2: APP_DIR_NAME    - App directory basename
    $3: FSP_DIR_NAME    - FSP directory basename
    $4: APP_TYPE        - "java" or "cpp"
    $5: SDK_PATH        - C++ SDK path (used for C++, compatibility placeholder for Java)
    $6: JAR_PATH        - JAR file path (used for Java, empty for C++)
    $7: ARCH_TYPE       - Target architecture: "aarch64", "arm32", "x86_64"
```

## Troubleshooting

### Docker

| Symptom | Cause | Fix |
|---|---|---|
| `Docker is not installed` | Docker not installed | Ubuntu: `sudo apt-get install -y docker.io`, macOS: `brew install --cask docker` |
| `Docker daemon is not running` | Daemon not started | Linux: `sudo systemctl start docker`, macOS: `open -a Docker` |
| `permission denied` | Insufficient permissions | `sudo usermod -aG docker $USER` then re-login |

### Java Build

| Symptom | Cause | Fix |
|---|---|---|
| `gen JAR not found` | gen project not built | Build `com.bosch.fsp.<name>.gen` first |
| EMF/Spark compile errors | Missing `-DpomFile` | Script handles automatically; check if running manually |
| `jar-with-dependencies JAR not found` | assembly plugin missing | Check `maven-assembly-plugin` in pom.xml |

### C++ Build

| Symptom | Cause | Fix |
|---|---|---|
| `C++ SDK not found` | SDK directory missing | Check `<name>_CPP_SDK/` exists or `<name>_CPP_SDK.zip` for 9.0.0+ |
| `C++ app directory not found` | App path detection failed | Set `CPP_APP_PATH` in `FDProject.props` or check project structure |
| CMake errors inside container | Missing dependencies | Check Docker image version matches project requirements |

### FIF Output

| Symptom | Cause | Fix |
|---|---|---|
| `FIF file not found` | build.sh failed | Check Docker logs: `docker logs nvx-fif-gen-cntr` |
| Empty output directory | Container internal error | Inspect: `docker exec nvx-fif-gen-cntr ls /fif_output/` |
