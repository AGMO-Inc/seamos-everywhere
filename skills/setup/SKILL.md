---
name: setup
description: |
  Bootstrap a SeamOS workspace — one-time environment setup before creating SeamOS apps. Writes `.seamos-workspace.json` (workspace marker + UI prefs) and, in project scope only, `.mcp.json` for the SeamOS marketplace MCP server. Idempotent.
  Triggers — Korean: "SeamOS 셋업", "SeamOS 시작", "처음 SeamOS", "프로젝트 시작 전 셋업", "seamos-workspace 만들어", "marketplace 등록". English: "SeamOS setup", "init seamos workspace", "first time seamos", "configure seamos marketplace", "bootstrap seamos workspace". Do NOT trigger on bare "셋업" / "setup" / "설정" alone (collides with `agmo:setup`); requires SeamOS context.
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
- **`--reconfigure`** — 기존 `.seamos-workspace.json` / `.mcp.json` 발견 시 동작. overwrite / merge / skip 중 선택. default = skip.

위 3 가지가 모호한 채로 invoke 하지 말 것. 마켓플레이스 인증은 OAuth (PKCE) — 첫 MCP 호출 시점에 브라우저가 열려 SeamOS 로그인 1회. setup 단계에서는 어떤 자격증명도 요구하지 않는다.

## Prerequisites

- `bash` — 모든 step 의 host 셸.
- `jq` — `.seamos-workspace.json` 작성 시 사용.
- `node` + `npx` — project scope 의 `.mcp.json` 이 `mcp-remote` 를 npx 로 실행하므로 필요.

누락 시 비차단 안내만 — 실 차단은 의존 스킬(`create-project`) 시점에 발생한다.

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

1. **Resolve scope** — `${BASH_SOURCE[0]}` 가 `~/.claude/plugins/` 하위면 `user`, 아니면 `project`.
2. **Resolve USER_ROOT** — `--workspace-dir` 우선, 미지정 시 `find-user-root.sh` 호출 (마커 없으면 `$PWD` fallback).
3. **Bootstrap assets** — `seamos-assets/{builds,screenshots}/` 부재 시 생성, 존재 시 skip.
4. **Project scope only — `.mcp.json` 작성** — `assets/.mcp.json.template` 을 endpoint URL 로 치환해 `${USER_ROOT}/.mcp.json` 작성 (stdio + `npx mcp-remote`, 인증은 첫 호출 시 OAuth 자동). 기존 파일 + `--reconfigure` 미설정 → skip + diff 안내.
5. **`.seamos-workspace.json` 작성** — `jq -n` 으로 schema 작성. 기존 파일 발견 시 schemaVersion 호환 확인 후 merge / `--reconfigure` 시 prompt.
6. **Preflight 도구 점검** — `docker`, `jq`, `shasum` / `sha256sum`, `timeout` / `gtimeout` 존재 확인. 누락 시 비차단 안내 (실 차단은 `create-project` 시점).
7. **User scope only — MCP 안내** — MCP 서버는 플러그인이 자동 등록되므로 setup 은 안내 출력만 한다.
8. **Final status** — 마지막 줄에 `STATUS_OK` / `STATUS_WARN: <reason>` / `STATUS_ERR: <reason>` 머신가독 라인.

## Important Notes

- `sdm-marketplace` (deprecated) 발견 시 마이그레이션 권장 안내만 — 자동 변환은 하지 않는다.
- 인증은 OAuth (PKCE) — setup 은 어떤 자격증명도 수집/검증하지 않는다. 인증 실패는 첫 MCP 호출 시점에 mcp-remote 가 OAuth flow 로 처리한다.
- `.mcp.json` 충돌 시 default = skip — 사용자 데이터 우선.
- Exit codes: `0` = OK / no-op (멱등), `64` = usage / preflight, `65` = data fault, `73` = preflight tool missing, `74` = network / IO.

## Shared Components

- [`skills/shared-references/scripts/find-user-root.sh`](../shared-references/scripts/find-user-root.sh) — USER_ROOT 마커 탐색 lib (`.seamos-workspace.json` > `.mcp.json` 우선순위, TODO 1.1).
- [`references/seamos-workspace-schema.md`](references/seamos-workspace-schema.md) — `.seamos-workspace.json` 스키마.
- [`references/mcp-template.md`](references/mcp-template.md) — `.mcp.json` 템플릿 의도 / 구조.
- [`references/trigger-design.md`](references/trigger-design.md) — 트리거 라우팅 분석 (`agmo:setup` 충돌 회피).
- [`assets/.mcp.json.template`](assets/.mcp.json.template) — placeholder-substituted MCP 서버 정의.
