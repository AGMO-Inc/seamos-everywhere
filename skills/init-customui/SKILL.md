---
name: init-customui
description: |
  Initialize the CustomUI directory layout for a SeamOS app — vanilla (work directly in deep ui/) or react (scaffold customui-src/ from a template, npm install, patch deploy path, drop a do-not-edit marker into deep ui/). Records the SSOT path in .seamos-workspace.json. Run after create-project for each app.
  Triggers — Korean: "customui 초기화", "customui 폴더 만들어", "customui 스캐폴드", "react UI 시작", "vanilla UI 시작", "customui 모드 바꿔", "vanilla로 전환", "customui-src 만들어", "ui template clone". English: "init customui", "scaffold customui", "create customui directory", "switch ui to react", "switch ui to vanilla", "clone ui template", "reset customui". Do NOT trigger on bare "CustomUI 만들어" / "design CustomUI screen" (route to seamos-customui-ux) or "CustomUI 안 떠" / "WebSocket frame 안 와" (route to seamos-customui-client).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--project-name <name>] [--ui react|vanilla] [--reset] [--app-project-name <name>]"
---

# Init CustomUI — SeamOS App UI Scaffold

## Overview

SeamOS 앱별 CustomUI 디렉터리 레이아웃을 초기화한다. **vanilla** 모드는 deep `ui/` 를 작업 SSOT 로 그대로 사용 (빌드 단계 없음). **react** 모드는 `${PROJECT}/customui-src/` 를 템플릿 레포에서 스캐폴드하고 `npm install` 후 deploy output path 를 deep `ui/` 로 patch 한 뒤, deep `ui/` 에 do-not-edit 마커를 떨어뜨려 사용자가 직접 편집하지 않도록 한다. 선택된 모드는 `.seamos-workspace.json.ui.{defaultFramework,activeSrcPath}` 에 기록되어 `seamos-customui-client` / `seamos-customui-ux` 가 SSOT 위치를 일관되게 인식하도록 한다. `create-project` 직후 앱마다 1 회 실행.

## Agent Preflight (REQUIRED)

`init-customui` 를 invoke 하기 전, LLM agent 는 다음 user-owned decisions 를 사용자와 명확히 합의해야 한다 — 기본값으로 가정하면 안 된다.

- **`--project-name`** — `.seamos-context.json` 의 `last_project.name` 이 default. 워크스페이스에 여러 프로젝트가 공존하거나 context 파일이 없으면 prompt.
- **`--ui`** — `react` 또는 `vanilla`. 인자 미지정 + `.seamos-workspace.json.ui.defaultFramework` 가 설정되어 있으면 그 값을 default 로 쓰고, 아니면 prompt.
- **`--app-project-name`** — `.seamos-context.json.last_project.app_project_name` 이 default. deep `ui/` 경로 산출에 필수.
- **`--reset`** — 모드 전환 시에만 의미가 있다. 파괴적 — 백업 의도를 사용자에게 확인. `--non-interactive` 모드에서 파괴적 전환은 fail-closed (`exit 64`).

## Prerequisites

- `git` — react 모드 템플릿 clone.
- `npm` + `node` — react 모드 의존성 설치.
- `jq` — `.seamos-workspace.json` 갱신.
- 네트워크 — react 모드 최초 clone 시 필요.

## USER_ROOT

`.seamos-workspace.json` 이 **REQUIRED**. 부재 시 `exit 64` 와 함께 stderr 로 `ERROR: .seamos-workspace.json not found — run 'setup' first` 출력. 마커 위치는 공유 lib `find-user-root.sh` 가 자동 해석한다.

## Asset Convention

| 항목 | 경로 |
|---|---|
| Deep `ui/` 경로 | `${USER_ROOT}/${PROJECT}/${PROJECT}/${app_project_name}/ui/` (formula); `.seamos-context.json.last_project.app_project_path` 가 있으면 `${app_project_path}/ui` 우선 |
| React source | `${USER_ROOT}/${PROJECT}/customui-src/` (= `${PROJECT}/${PROJECT}/` 와 sibling) |
| Workspace JSON 갱신 필드 | `ui.defaultFramework`, `ui.activeSrcPath` (USER_ROOT 상대 경로) |

## Execution Flow

### Vanilla mode

1. `.seamos-workspace.json` + `.seamos-context.json` (또는 `--project-name` / `--app-project-name` 인자) 검증.
2. Deep `ui/` 경로 해석. 부재 → `exit 64` (사용자에게 `create-project` 선행 안내).
3. 이전 react 셋업의 `customui-src/` 가 존재 + `--reset` 미설정 → `exit 0` 와 함께 `[skip] mode mismatch — pass --reset to switch from react to vanilla`.
4. Deep `ui/` 가 비어 있을 때만 `assets/vanilla-readme.md` 를 `${deep_ui}/README.md` 로 drop.
5. `.seamos-workspace.json` 의 `ui.defaultFramework="vanilla"`, `ui.activeSrcPath=<USER_ROOT 상대 deep ui 경로>` 갱신.
6. 마지막 줄에 `STATUS_OK`.

### React mode

1. 위와 동일하게 검증.
2. Deep `ui/` 경로 해석. 부재 → `exit 64`.
3. `customui-src/` 이미 존재 + `--reset` 미설정 → `[skip] customui-src/ already present`. `exit 0`.
4. `git clone --depth 1 -b ${ref} ${repo} ${USER_ROOT}/${PROJECT}/customui-src/` (값은 workspace JSON `ui.react` 에서).
5. `customui-src/.git/` 제거.
6. `(cd customui-src && npm install)` — 실패 → `exit 74` (재시도용으로 clone 보존).
7. `customui-src/vite.config.*` 또는 `package.json#scripts.deploy` 의 deploy 출력 경로를 `${deep_ui}` (상대 경로) 로 auto-patch. 패턴 미스 시 WARN + 수동 가이드 출력 후 진행.
8. `assets/seamos-do-not-edit.md` 를 `${deep_ui}/.seamos-do-not-edit.md` 로 drop.
9. `${USER_ROOT}/.gitignore` 에 sentinel block 부재 시 append:
   ```
   # BEGIN seamos-init-customui:<PROJECT>
   <PROJECT>/customui-src/dist/
   <PROJECT>/customui-src/node_modules/
   # END seamos-init-customui:<PROJECT>
   ```
10. Workspace JSON 갱신: `ui.defaultFramework="react"`, `ui.activeSrcPath=<PROJECT>/customui-src` (USER_ROOT 상대).
11. 마지막 줄에 `STATUS_OK`.

## Mode Transition Matrix

| From | To | Action |
|---|---|---|
| none | vanilla | `activeSrcPath` = deep `ui/`, deep `ui/` 가 비어 있으면 README drop |
| none | react | `customui-src/` clone + `npm install` + deploy patch + deep `ui/` 마커 drop |
| vanilla | react | deep `ui/` → `ui.bak.{ts}/` 로 이동, 비운 뒤 마커 drop, 이후 "none → react" steps 수행 |
| react | vanilla | deep `ui/` → `ui.bak.{ts}/` 로 이동, 비운 뒤 마커 제거, `customui-src/` 삭제 |

모든 `--reset` 전환은 interactive confirm 필요 (`--non-interactive` 시 fail-closed).

## Important Notes

- `--reset` 은 삭제 전 confirm — 파괴적 가드.
- 부분 상태 복구: clone 실패 시 `customui-src.tmp.*` 정리; `npm install` 실패 시 `customui-src/` 보존하여 수동 재시도 가능.
- Deploy path auto-patch 실패는 비차단 — WARN + 수동 가이드만 출력.
- Exit codes: `0` = OK / no-op / skip, `64` = usage / preflight (workspace JSON 부재, deep ui/ 부재, app_project_name 미해석, non-interactive 파괴적 전환), `65` = data fault (malformed workspace JSON), `73` = preflight tool 미존재, `74` = network / IO (`git clone`, `npm install`).

## Shared Components

- [`skills/shared-references/scripts/find-user-root.sh`](../shared-references/scripts/find-user-root.sh) — USER_ROOT lookup.
- [`skills/setup/references/seamos-workspace-schema.md`](../setup/references/seamos-workspace-schema.md) — 스키마 cross-skill reference.
- [`references/trigger-design.md`](references/trigger-design.md) — 트리거 라우팅 분석.
- [`references/mode-transition-matrix.md`](references/mode-transition-matrix.md) — 전환 detail steps.
- [`references/react-template.md`](references/react-template.md) — 템플릿 구조 + auto-patch logic.
- [`assets/seamos-do-not-edit.md`](assets/seamos-do-not-edit.md) — react 모드 deep-ui 마커 본문.
- [`assets/vanilla-readme.md`](assets/vanilla-readme.md) — vanilla 모드 placeholder README.
