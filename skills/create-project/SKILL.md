---
name: create-project
description: Create a new SeamOS project (FSP) via FD Headless. Triggers: "프로젝트 생성", "create project", "FSP 생성", "skeleton generate", "SeamOS 프로젝트 만들어", "create-project".
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "--project-name <NAME> [--interface-json <PATH>] [--operation GENERATE_FSP] [--workspace <PATH>] [--force-clean] [--resume]"
---

# Create SeamOS Project (FSP)

SeamOS 앱 개발의 첫 단계 — FD Headless 8.6.0 Docker 이미지를 사용해 새 FSP 프로젝트를 생성한다. UI type 은 "Custom UI" 로 고정되며, 지원 OS 는 Windows (WSL2 / Git Bash) / Linux / macOS (Apple Silicon 포함, Rosetta 2 필요) 이다.

## Prerequisites

- **Docker Desktop** (macOS/Windows) 또는 Docker Engine (Linux)
- **macOS Apple Silicon 사용자**: Rosetta 2 활성화 필수
  ```bash
  softwareupdate --install-rosetta --agree-to-license
  ```
  Docker Desktop → Settings → Features in Development → **Use Rosetta for x86/amd64 emulation** 옵션 활성화 권장.
- **Windows 사용자**: WSL2 또는 Git Bash 필수 — PowerShell / cmd 단독 실행 불가 (Bash / jq / shasum 의존).
- **필수 호스트 도구**: `docker`, `jq`, `shasum` (또는 `sha256sum`), `timeout` (또는 macOS 의 `gtimeout` via `brew install coreutils`). `scripts/preflight.sh` 가 부재 시 차단.
- **첫 실행 (온라인)**: `docker pull public.ecr.aws/<alias>/seamos-fd-headless:latest`. 완전 오프라인 환경에서는 별도 오프라인 번들 사용 (본문 Important Notes 참조).

## Asset Convention

TODO E.3 will populate this section — 이 스킬이 기대하는 워크스페이스 구조와 `_interface.json` 위치.

## Execution Flow

### Step 1: 인자 파싱 & interface JSON 분기

사용자가 `/create-project --project-name <name> [--interface-json <path>] ...` 형식으로 호출. `--interface-json` 이 **제공되었으면** 해당 파일을 그대로 사용한다(Step 2 스킵). **제공되지 않았으면** Step 2 로 진행하여 대화형 합성.

### Step 2: 대화형 interface JSON 합성 (optional)

`--interface-json` 이 없으면 Claude 가 `references/interactive-prompts.md` 의 알고리즘에 따라 사용자와 대화하며 `<workspace>/_interface.json` 을 합성한다. 세부 절차(element 목록 제시 → interface 선택 → updateRate 설정 → 검증)는 `references/interactive-prompts.md` 참조.

### Step 3: create-project.sh 실행

```bash
bash skills/create-project/scripts/create-project.sh \
  --project-name <name> \
  --interface-json <workspace>/_interface.json \
  --operation GENERATE_FSP \
  --workspace <workspace>
```

스크립트 내부 흐름:
1. `preflight.sh` 호스트 도구 감지 → FAIL 시 즉시 중단
2. 워크스페이스 존재 시 abort (또는 `--force-clean`/`--resume`)
3. `validate-interface-json.sh` 로 interface JSON preflight 검증
4. `TIMEOUT_BIN="$(command -v gtimeout || command -v timeout)"` 에 `docker run` 래핑 (600s)
5. stdout 를 `<workspace>/run.log` 로 tee

### Step 4: 결과 판정

`run.log` 를 grep 해 성공/실패/unknown/timeout 중 하나로 판정:

- `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY` → exit 0 (성공)
- `FD HEADLESS EXECUTION EXITED WITH ERRORS` → exit 1 (FD 보고 실패)
- 둘 다 없음 → exit 2 (unknown)
- `timeout 124` → exit 3 (600s 초과)

### Step 5: `.seamos-context.json` 업데이트 & 핸드오프 안내

성공 시 프로젝트 루트 `.seamos-context.json` 에 `last_project` 필드 atomic upsert (flock + `.tmp` + `mv`). 후속 스킬(`build-fif`, `manage-device-app` 등)은 이 값을 자동 참조한다(자세한 내용은 `## Important Notes` 참조).

## Important Notes

### Context handoff to downstream skills

`create-project` 는 성공 종료 시 프로젝트 루트 `.seamos-context.json` 의 `last_project` 필드를 atomic upsert 한다. 후속 스킬(`build-fif`, `manage-device-app`, 기타 FD 체인)은 이 값을 자동 참조하므로, 사용자가 프로젝트 경로/이름을 매번 지정하지 않아도 된다.

스키마 및 읽기 예시는 [`shared-references/seamos-context-cache.md`](../shared-references/seamos-context-cache.md#create-project) 의 `## create-project` 섹션 참조.

재실행 시 다른 프로젝트를 가리키려면 `--project-name <other>` 로 새로 실행하면 `last_project` 가 갱신된다.

### Offline (air-gapped) usage

첫 실행은 `docker pull public.ecr.aws/<alias>/seamos-fd-headless:latest` 로 온라인 접근이 필요하다. 완전 오프라인/에어갭 환경에서는 `docker/fd-headless/scripts/build-offline-bundle.sh` 로 만든 번들(`.tar` + `.sha256`)을 전송받아 `docker load -i` 로 로드한 뒤 실행.

자세한 절차:
```bash
# (온라인 호스트)
bash docker/fd-headless/scripts/build-offline-bundle.sh \
  public.ecr.aws/<alias>/seamos-fd-headless:latest \
  ./dist

# (에어갭 호스트)
shasum -a 256 -c seamos-fd-headless-<...>.tar.sha256
docker load -i seamos-fd-headless-<...>.tar
bash skills/create-project/scripts/create-project.sh --project-name <Name> --interface-json <...>
```

### Concurrency

동일 프로젝트명으로 두 인보케이션을 동시에 실행하는 것은 지원되지 않는다. 워크스페이스 충돌 방지를 위해 기본 동작은 **기존 워크스페이스 존재 시 abort**. 재실행이 의도라면 `--force-clean` (rm -rf 후 재생성) 또는 `--resume` (기존 상태 유지) 중 하나를 명시.

`.seamos-context.json` 은 `flock` + `.tmp`+`mv` 로 atomic 쓰기가 보장된다.

### UI Type

이 스킬은 UI Type 을 항상 `"Custom UI"` 로 고정한다. 다른 UI type (예: `"Standard UI"`) 이 필요하면 별도 스킬을 사용하거나 `docker/fd-headless/entrypoint.sh` 를 직접 실행하는 low-level 경로를 고려할 것.

### Redistribution approval

Docker 이미지는 AWS Public ECR 로 배포되며, `LEGAL.md` 의 `STATUS: APPROVED` 가 CI 블로킹 게이트로 강제된다. 새 FD 바이너리 버전으로 교체 시 `docker/fd-headless/checksums.txt`, `skills/create-project/references/fd-version.json`, `LEGAL.md` 의 Binary 섹션을 함께 갱신한 뒤 CI 재빌드.
