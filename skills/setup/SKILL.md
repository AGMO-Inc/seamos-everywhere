---
name: setup
description: |
  Bootstrap a SeamOS workspace — one-time environment setup before creating SeamOS apps. Writes `.seamos-workspace.json` (workspace marker + UI prefs) and, in project scope only, `.mcp.json` for the SeamOS marketplace MCP server. Idempotent.
  Triggers: "SeamOS setup", "init seamos workspace", "first time seamos", "configure seamos marketplace", "bootstrap seamos workspace". Do NOT trigger on bare "setup" alone (collides with `agmo:setup`); requires SeamOS context.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--workspace-dir <path>] [--endpoint dev|local|<URL>] [--reconfigure] [--non-interactive]"
---

# Setup — SeamOS Workspace Bootstrap

## Overview

SeamOS 앱 개발의 1회용 환경 부트스트랩. 멱등 — 재실행 시 변경 없으면 모든 step 이 `[skip]` 으로 통과. 두 가지 플러그인 설치 스코프(project / user)를 자동 감지해 산출물이 달라진다.

## Agent Preflight (REQUIRED)

`setup.sh` 를 invoke 하기 전, LLM agent 는 다음 user-owned decisions 를 사용자와 명확히 합의해야 한다 — 기본값으로 가정하면 안 된다.

- **`--workspace-dir`** — USER_ROOT 후보. 기본 `$PWD`. 사용자에게 "어디를 SeamOS workspace 로 쓸지" 확인.
- **`--endpoint`** — `dev` (default, `https://dev.marketplace-api.seamos.io/mcp`) / `local` (`http://localhost:8088/mcp`) / 커스텀 URL.
- **`--scope`** — `project` 또는 `user`. 미지정 시 자동 감지 (아래 *Scope Resolution* 참고). plugin 이 `~/.claude/plugins/cache/...` 같은 비표준 경로에 설치된 경우 자동 감지가 user 로 오인할 수 있어 명시 권장.
- **`--reconfigure`** — 기존 `.seamos-workspace.json` / `.mcp.json` 발견 시 동작. overwrite / merge / skip 중 선택. default = skip.

Do not invoke while any of the 4 above are still ambiguous. Marketplace authentication is OAuth (PKCE) — the first MCP call opens a browser for a one-time SeamOS login. `setup` itself requires no credentials.

## Prerequisites

- `bash` — 모든 step 의 host 셸.
- `jq` — `.seamos-workspace.json` 작성 시 사용 (scope 자동 감지 시에도 필요).
- `node` + `npx` — project scope 의 `.mcp.json` 이 `mcp-remote` 를 npx 로 실행하므로 필요.

누락 시 비차단 안내만 — 실 차단은 의존 스킬(`create-project`) 시점에 발생한다.

### Plugin userConfig (user-scope only)

User scope 설치에서는 plugin 이 `mcp-servers.json` + `userConfig.seamos_api_url` 로 MCP 서버를 자동 등록한다. **`/plugin install` 직후 `seamos_api_url` 이 비어있으면** placeholder 가 unresolved 상태로 남아 MCP 서버 spawn 자체가 실패하며, 이 상황은 setup 출력에서 `STATUS_WARN: userConfig 'seamos_api_url' empty` 로 노출된다.

해결:
```
/plugin config seamos-everywhere
# seamos_api_url 에 dev → https://dev.marketplace-api.seamos.io
#                local → http://localhost:8088
#                혹은 사용자 endpoint
```

설정 후 `setup` 재실행하지 않아도 다음 MCP 호출부터 등록된다.

## Scope Resolution

Setup 은 다음 우선순위로 scope 를 결정한다 (B1):

1. **`--scope project|user` 명시 인자** — 자동 감지 무시, 사용자 결정 우선.
2. **`~/.claude/installed_plugins.json`** — Claude Code 플러그인 레지스트리. `seamos-everywhere` entry 의 `scope` / `installScope` / `installLocation` 필드를 참고. `user`/`global` → user, `project`/`local`/`repo` → project.
3. **BASH_SOURCE 휴리스틱** (fallback) — 다음 패턴으로 분기:
   - `*/.claude/plugins/cache/*` → **project** (cache 는 local-install download cache).
   - `*/.claude/plugins/*` → user.
   - 그 외 → project.

> **0.7.1 까지의 회귀**: BASH_SOURCE 만으로 판단했기 때문에 `~/.claude/plugins/cache/...` 에 떨어진 local install 도 user 로 오판했다. 0.7.2 부터는 cache 경로를 명시 분리하고 `installed_plugins.json` 을 우선 참고한다.

## USER_ROOT

USER_ROOT 마커 우선순위: `.seamos-workspace.json` > `.mcp.json`. 두 마커 모두 OR 로 인식되며, 의존 스킬(`create-project`, `init-customui`) 은 둘 중 하나가 있어야 동작한다.

`setup` 자체는 마커 부재 상태에서도 실행 가능 — 첫 부트스트랩이므로 `--workspace-dir` 또는 `$PWD` 가 USER_ROOT 가 된다. 즉 setup 의 산출물이 곧 마커가 된다.

이후 다른 SeamOS 스킬은 마커가 없으면 `exit 64` 로 차단되며, 사용자에게 setup 을 먼저 실행하도록 안내한다.

## Asset Convention

setup 의 산출물:

| 경로 | Scope | Purpose |
|---|---|---|
| `${USER_ROOT}/.seamos-workspace.json` | both | 워크스페이스 마커 + UI prefs + marketplace endpoint |
| `${USER_ROOT}/.mcp.json` | project only | seamos-marketplace MCP 서버 등록 (stdio + npx mcp-remote) |
| `${USER_ROOT}/seamos-assets/builds/` | both | build-fif 출력 캐시 |
| `${USER_ROOT}/seamos-assets/screenshots/` | both | upload-app 스크린샷 자료 |

User scope 에서 MCP 서버는 플러그인이 `mcp-servers.json` + `userConfig` 로 자동 등록하므로 `.mcp.json` 을 작성하지 않는다.

## Execution Flow

1. **Resolve scope** — `--scope` flag → `installed_plugins.json` → BASH_SOURCE 휴리스틱(cache 분리 포함) 의 3단 폴백. 자세한 규칙은 위 *Scope Resolution* 섹션.
2. **Resolve USER_ROOT** — `--workspace-dir` 우선, 미지정 시 `find-user-root.sh` 호출 (마커 없으면 `$PWD` fallback).
3. **Bootstrap assets** — `seamos-assets/{builds,screenshots}/` 부재 시 생성, 존재 시 skip.
4. **Project scope only — write `.mcp.json`** — substitute the endpoint URL into `assets/.mcp.json.template` and write to `${USER_ROOT}/.mcp.json` (stdio + `npx mcp-remote`; OAuth runs automatically on the first call). If the file already exists and `--reconfigure` is not set → skip + diff notice.
5. **`.seamos-workspace.json` 작성** — `jq -n` 으로 schema 작성. **두 scope 모두에서 `marketplace.endpoint` + `marketplace.endpointUrl` 을 항상 기록** (A3 — upload-app 의 URL discovery 폴백 source). 기존 파일 발견 시 schemaVersion 호환 확인 + stale `ui.react.templateRef == "main"` 감지 시 `--reconfigure` 호출에서 자동 마이그레이션 (A4).
6. **Preflight 도구 점검** — `docker`, `jq`, `shasum` / `sha256sum`, `timeout` / `gtimeout` 존재 확인. 누락 시 비차단 안내 (실 차단은 `create-project` 시점).
7. **User scope only — MCP 안내 (조건부, C5)** — `~/.claude/settings*.json` 에서 `seamos_api_url` userConfig 값을 best-effort 로 검사. 비어있으면 `STATUS_WARN: userConfig 'seamos_api_url' empty` + `/plugin config` 안내. 값이 있으면 "delegated to plugin" + `/mcp` 검증 안내 출력. **"auto-registered" 라고 단언하지 않는다.**
8. **Final status** — 마지막 줄에 `STATUS_OK` 또는 `STATUS_WARN: <reason1>; <reason2>` (다중 사유 join) / `STATUS_ERR: <reason>` 머신가독 라인.

## Important Notes

- `sdm-marketplace` (deprecated) 발견 시 마이그레이션 권장 안내만 — 자동 변환은 하지 않는다.
- Authentication is OAuth (PKCE) — `setup` collects and validates no credentials. Auth failures surface at the first MCP call, where `mcp-remote` runs the OAuth flow.
- `.mcp.json` 충돌 시 default = skip — 사용자 데이터 우선.
- Exit codes: `0` = OK / no-op (멱등), `64` = usage / preflight, `65` = data fault, `73` = preflight tool missing, `74` = network / IO.

## Shared Components

- [`skills/shared-references/scripts/find-user-root.sh`](../shared-references/scripts/find-user-root.sh) — USER_ROOT 마커 탐색 lib (`.seamos-workspace.json` > `.mcp.json` 우선순위, TODO 1.1).
- [`references/seamos-workspace-schema.md`](references/seamos-workspace-schema.md) — `.seamos-workspace.json` 스키마.
- [`references/mcp-template.md`](references/mcp-template.md) — `.mcp.json` 템플릿 의도 / 구조.
- [`references/trigger-design.md`](references/trigger-design.md) — 트리거 라우팅 분석 (`agmo:setup` 충돌 회피).
- [`assets/.mcp.json.template`](assets/.mcp.json.template) — placeholder-substituted MCP 서버 정의.
