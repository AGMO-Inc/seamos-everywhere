---
name: build-fif
description: Build a deployable FIF (Feature Installation File) package using Docker. Supports both Java (Maven) and C++ (CMake) SeamOS projects with auto-detection. Use when the user wants to build, package, or generate a FIF file for SeamOS app deployment. Triggers on "build fif", "fif 빌드", "배포 빌드", "fif build", "FIF 생성", "앱 빌드", "패키지 빌드". Also use when the user has a SeamOS project and wants to create the final deployment artifact (.fif).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[project-root] [--type java|cpp] [--arch aarch64|arm32|x86_64] [--image <docker-image>]"
---

# FIF Build

Run the build script immediately. Do not explain — just execute.

```bash
SKILL_DIR="$(find "$(pwd)" -path "*/skills/build-fif" -type d 2>/dev/null | head -1)"
[ -z "$SKILL_DIR" ] && SKILL_DIR="$(find ~/.claude -path "*/skills/build-fif" -type d 2>/dev/null | head -1)"
bash "$SKILL_DIR/scripts/build-fif.sh" "${PROJECT_ROOT:-$PWD}"
```

Map user arguments to env vars before the command: `APP_TYPE=cpp|java`, `ARCH_TYPE=aarch64|arm32|x86_64`, `NVX_DOCKER_IMAGE=<url>`.

Output: `seamos-assets/builds/*.fif`. On error, read [build-details.md](references/build-details.md) for troubleshooting.
