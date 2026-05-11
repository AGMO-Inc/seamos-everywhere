---
name: build-fif
description: Build a deployable FIF (Feature Installation File) package using Docker. Supports both Java (Maven) and C++ (CMake) SeamOS projects with auto-detection. Use when the user wants to build, package, or generate a FIF file for SeamOS app deployment. Triggers on "build fif", "fif 빌드", "배포 빌드", "fif build", "FIF 생성", "앱 빌드", "패키지 빌드". Also use when the user has a SeamOS project and wants to create the final deployment artifact (.fif).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[project-root] [--type java|cpp] [--arch aarch64|arm32|x86_64] [--image <docker-image>]"
---

# FIF Build

For end-to-end app coordination, follow the shared playbook:
[`vibe-seamos-app-agent.md`](../../shared-references/vibe-seamos-app-agent.md).

Run the build script immediately. Do not explain — just execute.

```bash
SKILL_DIR="$(find "$(pwd)" -path "*/skills/build-fif" -type d 2>/dev/null | head -1)"
[ -z "$SKILL_DIR" ] && SKILL_DIR="$(find ~/.claude -path "*/skills/build-fif" -type d 2>/dev/null | head -1)"
bash "$SKILL_DIR/scripts/build-fif.sh" "${USER_ROOT:-$PWD}"
```

The first positional argument is **USER_ROOT** (directory containing `.mcp.json`). When omitted, `build-fif.sh` walks upward from `$PWD` to locate it (v4 CIMP-1). The script then resolves `FD_APP_ROOT` internally via `$USER_ROOT/.seamos-context.json` `last_project.app_project_path` (preferred) or the convention `$USER_ROOT/<PROJECT>/<PROJECT>`.

Map user arguments to env vars before the command: `APP_TYPE=cpp|java`, `ARCH_TYPE=aarch64|arm32|x86_64`, `NVX_DOCKER_IMAGE=<url>`. `--project-name <NAME>` flag disambiguates when multiple FSP projects live under a single USER_ROOT.

Output: `$USER_ROOT/seamos-assets/builds/*.fif` — consumed directly by the upload-app skill. On error, read [build-details.md](references/build-details.md) for troubleshooting.

## Disk packaging policy

`disk/` 하위는 기본적으로 패키징에서 제외된다. 단 `disk/seed/` 하위는 allowlist 로 그대로 패키징된다 — 앱이 의도적으로 동봉하는 시드 데이터(초기값) 를 위한 경로다. working DB(`./db/`) 는 항상 제외되며, 디바이스 영속 영역(`disk/<feature>/...`) 은 디바이스 측에서 런타임에 생성되므로 빌드 산출물에 포함되지 않는다. 자세한 정책은 `references/build-details.md` 의 "Disk Packaging Policy" 참고.
