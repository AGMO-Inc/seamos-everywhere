# SeamOS Everywhere — Routing Compass

You are working in a SeamOS app project. Route by user intent — invoke the right skill even without a slash command.

**Language**: Korean to user, English in code and files.

## Intent → Skill

| User intent | Skill |
|---|---|
| 새 프로젝트 생성 (FSP + SDK skeleton) | `create-project` |
| 플러그인/인터페이스 추가·제거 (FSP 자동 재생성) | `edit-plugins` |
| FSP 변경 후 skeleton만 다시 받기 (앱 코드 보존) | `regen-sdk-app` |
| REST · WebSocket · DB · Lifecycle · 외부 API 호출 | `seamos-app-framework` |
| CAN · GPS · IMU · GPIO · Implement · ISOPGN 신호 | `seamos-plugins` |
| CustomUI 화면 설계 · UX 원칙 (ADS 사용) | `seamos-customui-ux` |
| CustomUI 포트 자동검색 · WebSocket · cloud-proxy | `seamos-customui-client` |
| CustomUI 디렉토리 초기화 (vanilla / react) | `init-customui` |
| 로컬 실행 · MQTT/WS/HTTP 데이터 흐름 진단 | `run-app` |
| `.fif` 패키지 빌드 | `build-fif` |
| 마켓플레이스 신규 업로드 | `upload-app` |
| 마켓플레이스 버전 업데이트 | `update-app` |
| 디바이스 앱 설치 · 업데이트 · 제거 | `manage-device-app` |
| 공식 문서 (docs.seamos.io) 질의 | `ask-docs` |

## Conventions
- **USER_ROOT** = directory containing `.mcp.json`. `seamos-assets/`, `.seamos-context.json`, `<PROJECT>-interface.json` (SSOT) live there.
- **Protected regions** (`/*PROTECTED REGION ID(...) ENABLED START*/ … END*/`) are the only spans in generated app code that survive regeneration.
- **CustomUI ports are dynamic** — call `get_assigned_ports`, never hardcode. UI ⇄ backend envelope renames keys (`endPoint`→`externalUrl`, `methodSelect`→`method`).
- **Docs fallback** — if a skill's local references don't cover a topic, call `mcp__seamos-docs__search_docs` then `get_doc` (use `mode=outline` / `section` for big pages).

## Don'ts
- Don't hand-edit `<PROJECT>-interface.json` then call `regen-sdk-app` alone — FSP stays stale. Use `edit-plugins`.
- Don't fabricate doc answers. If `ask-docs` returns no result, say docs are unavailable.
