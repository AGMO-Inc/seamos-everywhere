# Trigger Design — `seamos-everywhere:setup`

`setup` 스킬의 라우팅 정확도를 위한 트리거 설계 분석. 가장 큰 충돌 후보는 `agmo:setup` (first-time agmo plugin config) 이므로 SeamOS 컨텍스트 단어와의 결합을 강제한다.

## Positive examples

다음 utterances 는 반드시 `seamos-everywhere:setup` 으로 라우팅되어야 한다.

- "처음 SeamOS 프로젝트 시작하려고 하는데"
- "seamos workspace 셋업해줘"
- "SeamOS 마켓플레이스 키 등록해줘"
- "init seamos workspace"
- "register seamos api key"
- "프로젝트 시작 전 셋업 한번 돌려줘"
- "seamos-workspace 만들어"
- "configure seamos marketplace"
- "first time seamos 환경 잡고 싶어"
- "MCP 키 등록해줘 SeamOS"
- "bootstrap seamos workspace"

## Negative examples

다음 utterances 는 절대 `seamos-everywhere:setup` 으로 라우팅되어선 안 된다.

- "VSCode setup 도와줘" — IDE 셋업, SeamOS 와 무관.
- "git 설정 좀 봐줘" — git config, 대상이 다르다.
- "agmo 플러그인 처음 셋업" → `agmo:setup` 으로.
- "/config 열어" — Claude Code 자체 설정 슬래시 커맨드.
- "환경변수 설정 가이드" — shell rc / dotfiles, SeamOS 와 무관.
- "셋업 좀 도와줘" (단독) — 컨텍스트 부족; 모호하므로 orchestrator 가 되묻거나 `agmo:setup` default.
- "설정 파일 어디에 있어?" — 단순 inquiry, 액션 아님.

## Collision analysis with `agmo:setup`

두 스킬은 동일한 트리거 단어 ("셋업", "setup", "설정") 영역을 공유하지만 **scope** 가 완전히 다르다.

- **`agmo:setup`** — agmo 플러그인의 first-time configuration. 워크플로우 옵션, 권한, 글로벌 prefs 등을 설정. 타깃은 "agmo 플러그인" 자체.
- **`seamos-everywhere:setup`** — SeamOS 워크스페이스 부트스트랩. `.seamos-workspace.json` / `.mcp.json` 작성, marketplace endpoint 와 API key 등록. 타깃은 "SeamOS 앱 개발 환경".

라우팅 결정 룰:
- 발화가 **bare** "셋업" / "setup" / "설정" 만 포함 → `agmo:setup` (default agmo first-time config).
- 발화에 **SeamOS context** 가 명시 ("SeamOS", "seamos", "marketplace", "workspace", "API key", "MCP", "프로젝트 시작 전") → `seamos-everywhere:setup`.
- 두 신호가 동시에 등장하면 SeamOS 가 더 구체적이므로 `seamos-everywhere:setup` 우선.

## Routing logic

orchestrator 가 사용하는 신호:

- **Context keywords** (SeamOS 라우팅 강신호): `SeamOS`, `seamos`, `customui`, `marketplace`, `API key`, `.mcp.json`, `workspace`, `seamos-workspace`, `mcp-remote`.
- **Intent verbs**: `init`, `bootstrap`, `register`, `configure`, `만들어`, `셋업`, `등록`, `시작`, `처음`.
- **Negative anchors** (라우팅 차단): `VSCode`, `git`, `agmo 플러그인`, `/config`, `환경변수`, `dotfiles`, `shell rc`.

라우팅 휴리스틱: `(context keyword 1+)` AND `(intent verb 1+)` 가 동시 만족이면 hit. context 없이 intent 만 → miss → `agmo:setup` 으로 fallback.

## Test prompts

skill-creator 가 트리거 정확도를 검증할 때 쓸 수 있는 입력 / 기대 라우팅 페어.

1. `"처음 SeamOS 프로젝트 시작하려고 하는데"` — Expected: HIT (`seamos-everywhere:setup`).
2. `"seamos marketplace API key 등록해줘"` — Expected: HIT (`seamos-everywhere:setup`).
3. `"agmo 플러그인 처음 셋업하고 싶어"` — Expected: MISS (route to `agmo:setup`).
4. `"VSCode setup 도와줘"` — Expected: MISS (route to none / general assistant).
5. `"init seamos workspace at ~/projects/foo"` — Expected: HIT (`seamos-everywhere:setup`).
6. `"환경변수 설정 가이드 좀"` — Expected: MISS (route to none — generic).
7. `"bootstrap seamos workspace"` — Expected: HIT (`seamos-everywhere:setup`).
