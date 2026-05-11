# Changelog

All notable changes to **seamos-everywhere** are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [SemVer](https://semver.org/) (pre-1.0: minor bumps signal feature additions, patch bumps signal fixes).

## [0.7.9] — 2026-05-11

**CustomUI ↔ 앱 REST CORS 우회 패턴 문서화 + plugin.json 버전 sync.** UI 에서 앱이 등록한 REST 라우트(`/crops` 등)를 부르면 `CORS policy 로 blocked` / preflight `OPTIONS 404` 가 떴는데, 현재 스킬 어디에도 서버측 CORS 핸들러 패턴이 없었음 (C++ 의 `Access-Control-Allow-Origin` 한 줄은 `/extApi` cloud proxy 응답 한정). 브라우저 측 우회는 SeamOS 에 존재하지 않으므로 (`no-cors` 도 답 아님) 정설 픽스를 Java/C++ 양쪽 스킬에 흡수. SSOT: https://docs.seamos.io/docs/4/6/2/5 ("REST Endpoints & WebSocket" → CORS Handling).

### Fixed — CORS 가이드 부재로 UI↔앱 REST 호출이 항상 깨지던 문제

근본 원인은 origin 불일치다. UI 는 UI gateway 포트(예: 6563)의 `/{featureId}/` 아래에서 서빙되고, 앱이 `registerRoute`/`registerGetService` 로 노출한 REST 라우트는 `get_assigned_ports` 가 돌려주는 **다른 포트**에 산다. 따라서 UI 의 `fetch` 는 *항상* cross-origin → 브라우저가 OPTIONS preflight 를 쏘는데 서버에 핸들러가 없으면 404 → 차단. 우회는 서버에만 존재한다.

- **`skills/seamos-app-framework/references/usage-patterns/cpp.md`** — REST API Convention 섹션에 **CORS Handling** 추가. `NevonexRoute::handleOptions` 오버라이드로 `Access-Control-Allow-Origin / -Methods / -Headers` 세팅 후 204 응답 + 실제 `handleGet`/`handlePost` 응답에도 `Allow-Origin` mirror. 공통 정책은 `CorsRoute` 베이스로 추출하라는 팁과, **prod 에서 `*` 금지** (credentialed request 비활성) 경고 포함.
- **`skills/seamos-app-framework/references/usage-patterns/java.md`** — 동일 위치에 **CORS Handling** 추가. `addCustomUISupport()` 안에 `UIWebServiceProvider.registerBeforeFilter((req,res) -> { ...Allow-* 헤더... })` (모든 응답에 헤더 주입) + `registerOptionsService("/*", new NevonexRoute() { ... })` (catch-all 200) 한 쌍. before-filter 는 한 번만 등록.
- **`skills/seamos-customui-client/SKILL.md`** — "Why this exists" 바로 아래 **"CORS — fix on the server, not in the browser"** 섹션 신설. DevTools 증상 3종 (`blocked by CORS policy` / preflight 404 / `Allow-Origin` 누락) → C++·Java 픽스를 한 줄씩 요약한 표 → `seamos-app-framework` 의 "REST API Convention → CORS Handling" 으로 라우팅. Pattern selection 표에도 `"CORS blocked / Allow-Origin 누락 / OPTIONS 404"` 행 추가, Hard rules 에 CORS preflight 항목 추가.
- **`skills/seamos-customui-client/references/port-discovery.md`** — Failure modes 표 마지막 행에 CORS preflight 항목 추가. fetch 가 404 / WS 가 즉시 끊김 같은 다른 증상과 한 데서 비교 가능.

### Fixed — `plugin.json` 버전이 v0.7.8 sync 누락

v0.7.8 커밋에서 `marketplace.json` 만 0.7.8 로 올리고 `.claude-plugin/plugin.json` 은 0.7.7 에 멈춰 있었음. 이번 릴리즈에서 두 파일 모두 **0.7.9** 로 정렬.

- `.claude-plugin/plugin.json` 0.7.7 → 0.7.9
- `.claude-plugin/marketplace.json` 0.7.8 → 0.7.9

### Why now (사용자 학습 동기)

사용자가 "UI → 백엔드 API 요청 시 CORS 에러 발생, [doc 4/6/2/5](https://docs.seamos.io/docs/4/6/2/5) 보고 스킬 수정해줘" 라고 직접 지목. 문서가 권하는 두 언어별 정설 패턴 (C++ `handleOptions` / Java `registerBeforeFilter` + `registerOptionsService`) 을 흡수해, 다음 작업부터는 `seamos-customui-client` 또는 `seamos-app-framework` 가 트리거되면 자동으로 잡힌다.

### Notes

- 코드 변경 없음 — 스킬 문서 / reference 만. 회귀 위험 없음.
- 실제 픽스를 적용할 때 `Access-Control-Allow-Origin: *` 는 LAN 전용 plain-`http` UI 한정. 운영 환경에서 credentialed request 가 필요해지면 origin 을 정확히 지정해야 한다는 점을 두 스킬 모두에 명시.

## [0.7.8] — 2026-05-08

**Marketplace category taxonomy 갱신 + `deviceTypes` 신규 필드 반영.** backend 의 `create_app` 라이브 스키마를 직접 조회한 결과, `categories` enum 값 5개가 모두 새 이름으로 교체됐고 (`AGRICULTURE`, `CONSTRUCTION`, `DRONE`, `DIAGNOSTICS`, `MATERIALS` → `EASY_WORK`, `FARM_MANAGEMENT`, `DEVICE_MANAGEMENT`, `ENTERTAINMENT`, `TEST`), 호환 기기 타입을 명시하는 `deviceTypes` enum 배열이 신규 required 필드로 추가됨. `upload-app` 스킬과 reference 가 옛 enum 으로 안내하고 있어 따라 짠 사용자는 backend 가 reject. 그 갭을 닫는다.

### Fixed — `upload-app` 옛 enum 안내로 인한 업로드 reject

- **`skills/upload-app/references/config-enum-values.md`** — `categories` 표 5개 신규 값으로 교체 (`EASY_WORK` / `FARM_MANAGEMENT` / `DEVICE_MANAGEMENT` / `ENTERTAINMENT` / `TEST`). required 조건을 "최소 1" → **"`isForTest=false` 일 때 required 최소 1"** 로 정정 (테스트 빌드는 optional).
- **`skills/upload-app/SKILL.md` Step 3A-5 (field guide 출력)** — "Options: CONSTRUCTION, AGRICULTURE, ..." 하드코드 → 신규 enum 으로 교체 + `deviceTypes` / `ownershipType` Options 도 함께 노출. "Always parse enum values from the live schema's `itemSchema.type` / `type` string rather than hardcoding" 원칙을 명문화 — backend 가 또 enum 을 바꿔도 코드 수정 없이 따라가도록.
- **`skills/upload-app/SKILL.md` Step 3B-2 (validation)** — required 분류를 *always* (`info`, `variants`) 와 *`isForTest=false` 일 때만* (`email`, `phoneNumber`, `categories`, `deviceTypes`, `pricingType`, `countries`, `languages`) 로 분리. `deviceTypes` enum 검증 추가. "live schema disagrees → schema wins" 명시.
- **`skills/upload-app/SKILL.md` Step 3B-3 (confirm summary)** — 업로드 전 요약 출력에 `호환 기기 타입` 라인 추가. feuType 라인 라벨도 `기기 (feuType)` 로 명확화 (deviceTypes 와 헷갈리지 않도록).

### Added — 신규 enum 필드 2개

- **`deviceTypes` (array of enum, `isForTest=false` 일 때 required)** — 앱이 호환되는 농기계 타입. 값: `TRACTOR` / `RICE_TRANSPLANTER` / `CULTIVATOR` / `COMBINE` / `MULTI_CULTIVATOR`. `references/config-template.json` 에 빈 배열 placeholder 추가, `config-enum-values.md` 에 의미 표 추가.
- **`ownershipType` (string enum, optional)** — 앱 소유권 타입. 값: `ORGANIZATION` / `DEVELOPER`. backend 기본값 사용 시 생략 가능. `config-template.json` / `config-enum-values.md` 에 추가.

### Changed — 마이그레이션 안내 (Step 3B-2a) 2-Case 로 확장

옛 단수 `category` 필드 안내 1건 → 두 가지 부적합 케이스로 분리. 둘 다 자동 변환 금지 — 사용자 의도를 추측해야 하기 때문.

1. **단수→복수**: `config.json` 에 `category` (string) 가 있으면 deprecated 안내 + `categories` (array) 변환 가이드. backend 는 아직 받지만 schema 가 명시적으로 `deprecated - use categories` 라고 표기.
2. **옛 enum 값**: `AGRICULTURE` / `CONSTRUCTION` / `DRONE` / `DIAGNOSTICS` / `MATERIALS` 가 발견되면 stop. 후보 매핑 힌트만 제시:
   - `AGRICULTURE` → `FARM_MANAGEMENT` (가장 가까움)
   - `DIAGNOSTICS` → `DEVICE_MANAGEMENT`
   - `CONSTRUCTION` / `DRONE` / `MATERIALS` → 직접 후속 없음, 사용자 판단

자동 변환을 끝내 거부하는 이유는 `CONSTRUCTION` 같은 값은 깔끔한 successor 가 없고, `AGRICULTURE → FARM_MANAGEMENT` 도 추측이라 사용자 확인이 필수라서.

### Changed — 문서 표기 정정

- **`CLAUDE.md`** SeamOS MCP Tools 표의 `edit_app_metadata` 설명: `category` (단수, 옛 표기) → `categories, deviceTypes` (현행 복수 + 신규 필드 반영).

### Why now (사용자 학습 동기)

사용자가 "카테고리 명이 바뀌었어, 직접 mcp 조회해서 봐줄 수 있어?" 라고 요청. `mcp__seamos-marketplace__create_app` 라이브 호출로 받은 스키마 응답을 SSOT 로 흡수. v0.7.7 까지의 enum (`AGRICULTURE` 등 5개) 은 backend 가 더 이상 받지 않으며, `deviceTypes` 신규 필드가 빠지면 `isForTest=false` 업로드는 reject. v0.7.8 은 그 갭을 닫는다.

### Notes

- 코드 변경 없음 — 스킬 문서 / reference / 템플릿만. 회귀 위험 없음.
- 정적 fallback 도 갱신했지만 **라이브 스키마가 항상 SSOT**. backend 가 또 enum 을 바꾸면 fallback 보다 live 응답을 우선하라는 원칙을 SKILL.md 에 명시.
- `update-app` 스킬은 metadata 를 안 다루므로 수정 없음 (categories/deviceTypes 편집은 `edit_app_metadata` 경로).

## [0.7.7] — 2026-05-08

**Java External API SSOT 정정 — `agnote-core` 흡수.** v0.7.6 의 Java External API 섹션은 C++ 매핑에 의존한 *근사치* 였음. 사용자가 `~/Desktop/Backend/agnote-core` (실제 Java NEVONEX 앱) 를 가리키며 "이걸로 진짜 진행 가능한 상태인지" 물어 갭이 드러남. 그 코드를 SSOT 로 흡수해서 Java 측을 처음부터 검증된 패턴으로 갈아끼움.

### Fixed — Java 패턴 정설화

`skills/seamos-app-framework/references/usage-patterns/java.md` 의 External API 섹션 전면 재작성. 정정된 항목:

- **`uploadData` 시그니처**: `(data, 1)` 2-arg 추측 → 실제 `(data, priority, ConnectionTypeEnum)` **3-arg, 반환 `String`**. `agnote-core` default priority 는 `2` (Medium), C++ 의 `1` 은 다른 프로젝트 컨벤션이었음.
- **CloudDownloadListener 베이스 클래스**: `implements PropertyChangeListener` (잘못) → **`extends AbstractCloudDownloadListener implements ICloudDownloadListener, PropertyChangeListener`** + `handleContent`/`handleFile` override.
- **PropertyChange 이벤트명**: `"download"` (잘못) → **`"CloudMessageReceived"`/`"CloudFileReceived"`**. v0.7.6 그대로 따라 짰다면 listener 가 등록은 되지만 영원히 발화 안 하는 silent bug.
- **`PendingRequestRegistry` 패턴**: `Map<String, CompletableFuture<String>>` (sync 대기) → **`Map<String, String>`** (cid → type-string) + 60 s daemon evict. Java 가 sync 대기하지 않고 type-routed broadcast 하기 때문.
- **응답 frame**: `external_api_response` (C++) → **`{"type":"EXT-{domain}", "data":...}`** (Java agnote). UI 측 dispatch 가 frame.type 으로 분기해야 함.
- **broadcast 메서드명**: `broadcast(...)` → **`broadcastMessage(...)`** (`UIWebsocketEndPoint`).
- **Listener 등록 hook**: `addCustomUISupport()` 안 → **`addListenersForDownload()`** 별도 lifecycle hook (`main()` 에서 `addCustomUISupport` 다음, `startProviders` 전 호출).
- **`GracefulFeatureStop` 가드** 추가 — 셧다운 중 이벤트 처리 race 방지.
- **`Cloud*Exception` 개별 catch** — `CloudBadRequestException`, `CloudUnAuthorizedException`, `CloudAccessDeniedException`, `CloudConnectionException`, `PlatformServiceException` 분리. 일반 `catch (Exception)` 는 auth 실패와 network 실패를 못 가림.
- **Service 변종 분류 변경**: "Pattern A (sync `/extApi`) / Pattern B (async WS)" → **V1 (Cloud Upload ack-only) / V2 (Trigger + type-routed broadcast)**. agnote 에는 Pattern A 가 존재하지 않음 — 모두 `cloud-upload/{name}` REST 라우트가 `uploadData` 를 부르는 변종.
- **UI envelope key**: agnote 의 UI 는 `endPoint`/`methodSelect` 별칭을 안 쓰고 처음부터 backend 키(`externalUrl`, `method`, `header`, `msg`)로 보냄. C++ reference 의 rename 은 프로젝트 의존 컨벤션으로 격하.
- **`correlation-id` 형식**: `"HTTP{ms}"`/`"WS{ms}"` (C++) → **UUID v4** (Java agnote). Java 는 prefix 가 dispatch signal 이 아님 (registry 가 type-routing 담당).

### Changed — Cross-language divergence surfaced

- **`skills/seamos-app-framework/references/usage-patterns/cpp.md`** — External API 섹션 헤더에 "Java differs in several conventions — read `java.md`, don't translate from this section" 노트 추가.
- **`skills/seamos-customui-client/references/cloud-proxy.md`** — Envelope key rename 표를 "Convention A vs B" 로 재구성. Response frame 표 추가 (`external_api_response` vs `EXT-{domain}`). UI dispatch 가 `frame.type` 분기해야 한다는 점 명시.
- **`skills/seamos-plugins/references/usage-patterns/java.md`** — `Cloud.getInstance().uploadData(data, 1)` 2-arg 인용 → 3-arg `(data, priority, ConnectionTypeEnum.WIFI)` + 반환 `String` (cloud ack, not upstream body) 로 정정.
- **`skills/seamos-app-framework/SKILL.md`** — 트리거 8개 추가 (`cloud-upload`, `클라우드 업로드`, `PendingRequestRegistry`, `CloudMessageReceived`, `CloudFileReceived`, `ConnectionTypeEnum`, `BaseRestService`, `AbstractCloudDownloadListener`, `EXT-frame`). Pattern Selection 의 External API 항목을 언어별로 분리 ("conventions differ by language — pick the right reference file"). 패턴 표의 External API 행에 "Java/C++ 컨벤션 다름" 경고 추가.

### Why now (사용자 학습 동기)

`agnote-core` 의 `CloudDownloadListener.java` / `PendingRequestRegistry.java` / `FuelPriceCloudUploadService.java` / `WeatherGetService.java` / `ApplicationMain.java` 와 그 프로젝트의 자체 `cloud-upload` 스킬 (service-template + registration-template) 까지 비교한 결과, v0.7.6 의 Java 섹션은 **컴파일은 되지만 listener 가 안 불리는 silent bug** 를 포함한 5~6 개 mismatch 가 있었음. 가장 치명적인 게 `"download"` vs `"CloudMessageReceived"` — 등록만 되고 영원히 발화 안 함. v0.7.7 은 그 갭을 닫는다.

### Notes

- 코드 변경 없음 — 스킬 문서/메타데이터만. 회귀 위험 없음.
- C++ 섹션은 그대로 유지 (`cpp_deploy_test_19` 검증). 변경된 건 "Java 가 다르다" 는 cross-ref 만.
- agnote-core 자체 cloud-upload 스킬은 외부 ref 로 링크하지 않음 — 그 스킬은 도메인별 service generator 라 seamos-everywhere 의 generic 스킬과 layer 가 다름.

## [0.7.6] — 2026-05-08

**External API Server Communication 패턴 도큐먼트화.** 사용자가 SeamOS 앱(C++/Java)에서 외부 HTTPS API 를 호출하는 방법을 물었을 때, 스킬에는 — 공식 문서(https://docs.seamos.io/docs/4/5/4) 와 reference 구현(`external_api_test`, `cpp_deploy_test_19`) 모두 존재함에도 — 패턴이 전혀 들어 있지 않아 매번 raw 코드를 직접 읽고 재구성해야 했음. 이 갭을 메운다. 스킬 본체 코드 변경 없음 (문서 + 트리거 키워드 + cross-reference 만).

### Added — External API Server Communication
- **`skills/seamos-app-framework/references/usage-patterns/cpp.md`** — "External API Server Communication" 섹션 신설 (+299 lines). 두 패턴 풀 코드:
  - **Pattern A — Sync HTTP `/extApi`**: `ExternalApiRequestManager` singleton + `std::promise`/`wait_for(10s)` + Poco `NevonexRoute` 핸들러. UI 가 동기 응답 기대하는 form submit / bulk fetch 용.
  - **Pattern B — Async WebSocket `/socket`**: `WebSocketEndPoint::onWebSocketMessage` 에서 `endPoint` 필드 감지 → Cloud uploadData 디스패치 → `CloudDownloadListener` 가 `external_api_response` envelope 으로 broadcast. 실시간/concurrent/long-op 용.
  - **단일 응답 핸들러**: `CloudDownloadListener::handleMessage` 가 `correlation-id` prefix(`HTTP*` vs `WS*`)로 두 패턴 분기.
  - **Listener 등록**: `ApplicationMain::addCloudDownloadListener` (Cloud singleton 에 `addPropertyChangeListener`) + `addCustomUIListener` (`/extApi` Route + `/socket` WS).
  - **Gotcha 5 개**: register-before-uploadData race, correlation-id 충돌, importance arg = 1 fixed, Pattern A 의 10 초 ceiling, D2D listener 빈 stub 은 의도적 (Cloud 코드 복사 금지).
- **`skills/seamos-app-framework/references/usage-patterns/java.md`** — Java 동등 패턴 섹션 (+147 lines). C++ ⇄ Java 타입 매핑 표(`std::promise` ↔ `CompletableFuture`, `Json::Value` ↔ Gson `JsonObject`, `BaseRestService` 기반 라우트). Pattern A 풀 스켈레톤(`ExternalApiRequestManager` ConcurrentHashMap + `CompletableFuture.get(10, TimeUnit.SECONDS)`).
- **`skills/seamos-customui-client/references/cloud-proxy.md`** — "How the backend dispatches the envelope" 섹션 추가 (+62 lines). 브라우저↔백엔드 envelope key rename 표(`endPoint`→`externalUrl`, `methodSelect`→`method`, `reqHeader`→`header`, `reqBody`→`msg`), 두 패턴 요약, "백엔드 의심 vs UI 의심" 트러블슈팅 표. 실제 backend 구현은 `seamos-app-framework` 로 cross-reference.

### Changed — Trigger keywords + cross-references
- **`skills/seamos-app-framework/SKILL.md`** — description 에 "external API server communication" 추가, 트리거 9 개 추가(`external API`, `외부 API`, `cloud proxy`, `uploadData`, `extApi`, `CloudDownloadListener`, `correlation-id`, `외부 서버 호출`, `백엔드 외부 호출`). 패턴 표에 External API 행 추가. Step 1 Pattern Selection 에 외부 API 항목 추가.
- **`skills/seamos-customui-client/SKILL.md`** — description 에 envelope key rename 명시(`endPoint → externalUrl` 등) — 백엔드 측 키 이름과 UI 측 키 이름이 다른 점이 디버깅의 첫 함정인데 description 에 안 써 있어서 cloud-proxy.md 까지 들어가야 알 수 있던 부분.
- **`skills/seamos-plugins/references/usage-patterns/cpp.md` / `java.md`** — Platform Service Methods 의 `Cloud::uploadData(data, ?)` 두번째 인자에 주석 추가: **importance(중요도). 보통 1 로 픽스해서 사용** (사용자 확인 사항). 외부 API 호출은 직접 HTTP 클라이언트가 아니라 Cloud 채널로 가야 한다는 원칙 + `seamos-app-framework` 외부 API 섹션으로 cross-ref 추가.

### Why now (사용자 학습 동기)
사용자가 `cpp_deploy_test_19` 의 `WebSocketEndPointImpl.cpp` / `CloudDownloadListenerImpl.cpp` 와 공식 문서를 함께 보여주며 "이 패턴이 스킬에 왜 없냐"고 짚어줘서 갭을 인지. 다음 SeamOS 앱 만들 때 Claude 가 처음부터 올바른 패턴(특히 `correlation-id` prefix 분기, importance arg, envelope key rename)을 생성하도록 SSOT 를 옮긴다.

### Notes
- 코드 변경 없음 — 스킬 문서/메타데이터만. plugin install/setup/upload/build 동작 회귀 위험 없음.
- 레퍼런스 구현 두 개 모두 명시: `external_api_test` (두 패턴 다), `cpp_deploy_test_19` (WebSocket-only 변종) — 사용자가 어느 프로젝트 보고 따라 만들지 헷갈리지 않게.

## [0.7.5] — 2026-05-07

**Zero-config plugin install.** 0.7.4 까지 사용자가 plugin install 직후 `/plugin config seamos-everywhere` 로 `seamos_api_url` 을 직접 입력해야 첫 MCP 호출이 동작했다. 이는 일반 사용자에게 마찰이고, 0.7.1 워크스루에서도 외부 의존(B2 — Claude Code 본체가 install 시 userConfig prompt 를 안 띄우는 문제) 을 우회 못 해 STATUS_WARN 안내로만 처리해뒀던 부분. 0.7.5 는 마찰 자체를 제거 — plugin 의 `mcp-servers.json` 이 dev 마켓플레이스 URL 을 직접 박아두고, `userConfig.seamos_api_url` 정의는 통째 제거한다. install 즉시 OAuth 기반 마켓플레이스 도구가 동작.

### Changed — Zero-config MCP
- **`mcp-servers.json`** — `seamos-marketplace.url` 을 `${user_config.seamos_api_url}/mcp` placeholder 에서 `https://dev.marketplace-api.seamos.io/mcp` (dev URL 직접) 로 교체. user-scope plugin install 의 zero-config 보장.
- **`.claude-plugin/plugin.json`** — `userConfig` 블록 통째 제거. user-scope settings 에 install/uninstall 시 잔존하는 entry 가 더 이상 없다 — 사용자 지적: `userConfig` default 는 user scope 에 박히므로 project-scope 격리 실패. mcp-servers.json 하드코딩이 가장 깔끔.
- **`skills/setup/scripts/setup.sh`** — Step 7 의 `seamos_api_url` userConfig empty 검사 + `STATUS_WARN: userConfig 'seamos_api_url' empty` 분기 제거. user-scope 시 단순히 "plugin auto-registers (dev URL embedded), `/mcp` 로 검증" 안내만 출력.
- **`skills/setup/SKILL.md`** — "Plugin userConfig (user-scope only)" 섹션을 "Plugin MCP 자동 등록 (zero-config)" 로 교체. Asset Convention / Execution Flow 의 user-scope 안내 갱신.
- **`skills/setup/references/mcp-template.md`** — User scope vs Project scope 비교표의 "Plugin auto-registers via mcp-servers.json + userConfig" 를 "(dev URL embedded, zero-config)" 로 갱신. project-scope `.mcp.json` 의 의미를 "endpoint override 가 필요한 경우" 로 좁힘.
- **`skills/upload-app/SKILL.md` / `scripts/resolve-marketplace-url.sh`** — `mcp-servers.json + userConfig` 표현을 `mcp-servers.json` (dev URL embedded) 로 정리. `CLAUDE_MCP_SEAMOS_URL` env var 경로는 legacy fallback 으로 유지 (제거 시 이득 없음).
- **`README.md`** — Configuration 섹션을 "Zero-config" 로 재작성. `seamos_api_url` 표 항목 제거 + endpoint override 흐름 설명. 0.5.x → 0.7.x 마이그레이션 가이드를 0.7.5 기준으로 갱신.

### Fixed — Implicit
- **B2 (0.7.1 워크스루 외부 의존 항목)** — `/plugin install` 시 Claude Code 본체가 required `userConfig` prompt 를 띄우지 않던 문제. 0.7.5 에서 `userConfig` 자체가 사라졌으므로 이슈 자체가 무의미해짐 — 별도 외부 PR 트래킹 종료.

### Migration
v0.5.x – v0.7.4 사용자: `~/.claude/settings.json` 의 `pluginConfigs.seamos-everywhere@seamos-plugins.options.seamos_api_url` entry 는 더 이상 읽히지 않는다. 그대로 두어도 무해 — 다음 settings 편집 시 청소만 권장. project 별로 다른 endpoint 를 쓰던 사용자는 `setup --endpoint <URL>` 로 project-scope `.mcp.json` 을 작성하면 된다 (이전과 동일).

## [0.7.4] — 2026-05-07

0.7.1 pluginTest71 워크스루 (CPP / IMU angle viewer 를 새 워크스페이스에서 setup → create-project → init-customui → 코드 → run-app → build-fif → upload-app 까지 돌려본 end-to-end) 에서 발견된 14건 함정 중 우리 측 책임 11건을 일괄 픽스. 외부 의존 3건(B2 plugin install userConfig prompt, B3 custom-ui-react-template repo, C2 marketplace name alias)은 우리 측 안내만 강화하고 별도 트랙으로 처리.

### Fixed — Hard-stop
- **A2 / `skills/build-fif/scripts/build-fif.sh`** — FD Headless 0.7.1 가 `FDProject.props` 의 `CPP_APP_PATH` 에 잘못된 `App` suffix 를 박는 회귀가 있어 `[2/7]` 단계에서 즉사. props 가 가리키는 dir 부재 시 `PROJ_ROOT` 하위에서 `CMakeLists.txt` 보유 디렉토리를 자동 검색 + `WARN: ...auto-resolved...` 출력 후 진행 (산출물 빌드는 정상). 사용자가 props 를 직접 고쳐야 한다는 안내도 함께 surface.
- **A3 / `skills/upload-app/`** — `.mcp.json` 부재를 hard stop 으로 단정하던 가정 폐기. URL discovery 를 4-source 다층화: `.seamos-workspace.json.marketplace.endpointUrl` (preferred, project/user 양 scope) → `.mcp.json.mcpServers["seamos-marketplace"].url` (project scope) → `CLAUDE_MCP_SEAMOS_URL` env var → fail-with-remediation. 결정 로직을 단독 헬퍼 `scripts/resolve-marketplace-url.sh` 로 추출 (11 unit tests).
- **A4 / `skills/setup/`, `skills/init-customui/`** — `.seamos-workspace.json` 의 `ui.react.templateRef` 기본값을 `main` → `master` 로 교정 (실제 템플릿 레포 `AGMO-Inc/custom-ui-react-template` 의 default branch). 0.7.1 까지 박혀있던 `main` 은 데이터 결함이라 사용자가 JSON 을 수동 편집하지 않는 한 `git clone --depth 1 -b main` 에서 100% 실패. 추가로 setup 의 `--reconfigure` 경로에서 stale `main` 자동 마이그레이션 + STATUS_WARN, init-customui 는 `git ls-remote --symref HEAD` 로 remote default 를 진실로 삼아 미래 rename 도 자동 흡수.
- **A5 / `skills/init-customui/scripts/init-customui.sh`** — `auto_patch_deploy()` 가 sed substitute 결과 검증 없이 SUCCESS 보고하던 회귀 제거. Pattern A (substitute) → Pattern A2 (`defineConfig({...})` 안에 build 블록 awk 삽입) → STATUS_WARN 의 3단 폴백. **false-SUCCESS 금지** — 패치 실제 반영 여부를 `grep` 후속 검증, 미반영이면 `STATUS_WARN: deploy-path patch skipped` + 정확한 수동 스니펫 출력.

### Fixed — Functional
- **B1 / `skills/setup/scripts/setup.sh`** — scope 자동 감지가 `~/.claude/plugins/cache/...` 같은 local-install 캐시 경로도 user-scope 로 오판하던 문제 수정. 결정 우선순위를 `--scope` flag → `~/.claude/installed_plugins.json` → `BASH_SOURCE` 휴리스틱(cache 분리) 의 3단 폴백으로 교체.
- **C5 / `skills/setup/scripts/setup.sh`** — user-scope 안내가 `MCP server is auto-registered` 로 단언하던 문제. 실제로는 `userConfig.seamos_api_url` 미입력 시 등록 자체 실패하는데 사용자는 안내를 믿고 진행하다 upload-app 에서 막혔음. `~/.claude/settings*.json` 에서 `seamos_api_url` 값 best-effort 검사 후 부재 시 `STATUS_WARN: userConfig 'seamos_api_url' empty` + `/plugin config` 안내.

### Fixed — Diagnostic / UX
- **A1 / `skills/shared-references/scripts/check-ecr-public-auth.sh`** (신설) — `~/.docker/config.json` 의 stale `public.ecr.aws` bearer token 이 anonymous public pull 을 403 으로 막던 회귀를 일괄 처리하는 공유 헬퍼. 9 unit tests. `build-fif` / `run-app --via-fd-cli` / `create-project` 의 docker pull 직전에 호출 (`*_CLEAN_ECR_AUTH=1` env 로 `--auto-clean` 활성).
- **C1 / `skills/create-project/scripts/preflight.sh`** — zsh alias 만 있고 `/usr/local/bin/docker` symlink 가 없는 macOS 환경에서 `command -v docker` 가 false 가 나는 케이스에 대해, Docker.app 바이너리 존재 시 `sudo ln -sf .../docker /usr/local/bin/docker` 정확한 hint 출력.
- **C3 / `skills/run-app/scripts/run-via-fd-cli.sh` + `skills/run-app/SKILL.md`** — `APP_PROJECT_ROOT` 부정확 시 `does not look like an FD project` 메시지를 layout diagram (`com.bosch.fsp.<APP>` / `<APP>_CPP_SDK` / `<APP>_<APP>` 형제) 로 강화 + 자주 발생하는 오류 두 가지(한 단계 얕음 / 깊음) 명시.
- **C4 / `skills/upload-app/references/`** — `config-template.json` 의 `pricingType: "FREE | PAID"` 류 enum placeholder 가 그대로 backend validator 에 흘러 reject 되던 문제. enum 항목은 모두 `""` / `[]` 로 두고 동행 가이드 `references/config-enum-values.md` 신설하여 valid value 와 source-of-truth (live `create_app` schema) 안내.

### Eval
- 신규 6개 단위 테스트 / smoke 보강 — 7개 test suite 전수 PASS. 내역: setup smoke 4 case (B1/A4-warn/A4-migrate/A3 endpointUrl), init-customui smoke A5 vite.config 3 case, build-fif `test-cpp-app-fallback.sh` 4 case, upload-app `test-resolve-url.sh` 11 case, shared-references `test-check-ecr-public-auth.sh` 9 case, create-project smoke C1 hint grep + build-fif fixture 보강.

### Documentation
- **`README.md`** — Contributing 섹션의 "submit a PR against `main`" → `master` (이 레포 자체의 default branch 도 `master`).
- **`skills/setup/SKILL.md`** — Scope Resolution + Plugin userConfig 섹션 신설, Execution Flow 갱신.

### Migration
- v0.7.3 이하에서 이미 생성한 `.seamos-workspace.json` 은 자동 갱신되지 않는다.
  - `ui.react.templateRef` 가 `"main"` 인 경우: `setup --reconfigure` 한 번 돌리면 자동 마이그레이션 + 백업 없이 in-place 수정 (`[migrate] ui.react.templateRef: 'main' → 'master'` 로그).
  - `marketplace.endpointUrl` 이 부재한 경우 (0.7.1 이전 schemaVersion): 동일하게 `setup --reconfigure` 로 보강.
- 외부 의존 (이번 릴리스 범위 밖):
  - **B2** — `/plugin install` 직후 plugin 의 required `userConfig.seamos_api_url` 이 prompt 되지 않는 문제는 Claude Code 본체 책임. 수동 설정: `/plugin config seamos-everywhere`.
  - **B3** — `customui-src` 템플릿의 TanStack `routeTree.gen.ts` stale 으로 신규 route 추가 시 build 실패는 [`AGMO-Inc/custom-ui-react-template`](https://github.com/AGMO-Inc/custom-ui-react-template) 레포의 `package.json#scripts.build` 에 `tsr generate &&` 가 추가되면 자동 해소. 별도 PR 트랙.
  - **C2** — `/plugin marketplace add AGMO-Inc/seamos-everywhere` 후 marketplace name alias (`seamos-plugins`) 혼동은 Claude Code 본체 측 협업 항목.

## [0.7.2] — 2026-05-07

Two follow-ups to v0.7.1: a missing OAuth client declaration that prevented the marketplace handshake from completing, plus a migration note for users coming directly from a v0.5.x install.

### Fixed
- **`mcpServers.seamos-marketplace.oauth.clientId` declared as `"sdm-mcp"`** in `mcp-servers.json`. Claude Code's HTTP MCP OAuth client needs an explicit `client_id` matching the SeamOS Keycloak `sdm-mcp` confidential client (PKCE, loopback redirect; see AGMO-Inc/agmo-auth-system). Without it, the OAuth handshake on the first marketplace MCP call cannot complete because the authorization server has no dynamic-registration path enabled. v0.7.1 shipped without this field, so the brand-new OAuth flow it introduced wouldn't actually start for end users.

### Added
- **Migration note in `README.md` and CHANGELOG** — explicit instruction to rename or remove stale `sdm_api_url` / `sdm_api_key` (and any other `sdm_*` userConfig key) entries in `~/.claude/settings.json` after upgrading. The `seamos_api_url` value should be kept; `seamos_api_key` should not be added (no longer read by the plugin).

### Why
A user upgrading directly from v0.5.x to v0.7.1 hit a confusing chain: first the marketplace MCP server appeared registered but every call failed with a malformed URL (stale userConfig key — `${user_config.seamos_api_url}/mcp` collapsed to `/mcp` because the new key didn't exist), then once that was fixed the OAuth handshake itself silently failed (no `client_id` declared). The plugin had no way to surface either failure on its own — `${user_config.X}` substitution returns an empty string for unknown keys, and Claude Code's OAuth client can't infer the right `client_id` without dynamic registration support. v0.7.2 closes both gaps.

### Migration (across v0.5.x → v0.7+)
1. Open `~/.claude/settings.json`.
2. Under `pluginConfigs.seamos-everywhere@seamos-plugins.options`, replace any `sdm_api_url` / `sdm_api_key` entry with `seamos_api_url` only — keep just the URL value:
   ```json
   "pluginConfigs": {
     "seamos-everywhere@seamos-plugins": {
       "options": {
         "seamos_api_url": "https://dev.marketplace-api.seamos.io"
       }
     }
   }
   ```
3. Restart Claude Code. The first marketplace MCP call opens a browser for one-time SeamOS OAuth login.

## [0.7.1] — 2026-05-06

Marketplace authentication switches from a static `X-API-Key` header to OAuth 2.1 (PKCE). MCP calls go through Claude Code's standard HTTP MCP client, which receives an RFC 9728 protected-resource-metadata challenge and runs OAuth discovery → browser login → token cache automatically. Multipart uploads use a one-time `ut_*` token returned in the `create_app` / `update_app` MCP responses, sent as `Authorization: Bearer` (5-minute TTL, single-use, bound to the appId). User-side change is minimal — a one-time browser login on the first MCP call, fully automatic afterward.

### Removed — Breaking
- **`userConfig.seamos_api_key`** — removed from `.claude-plugin/plugin.json`. The plugin install prompt no longer asks for an API key.
- **`mcpServers.seamos-marketplace.headers.X-API-Key`** — removed from `mcp-servers.json`. Only the URL remains.
- **`--api-key` flag in `upload.sh` / `update.sh`** — removed. Only `--upload-token` is accepted.
- **API key prompt in the `setup` skill** — removed. Setup itself collects no credentials.
- **One-shot 5xx retry in `update.sh`** — removed. The single-use upload token is consumed by the first request, so a retry inside the script cannot succeed; the user is now guided to rerun the skill, which fetches a fresh token.

### Changed
- **Multipart upload authentication** — `upload.sh` / `update.sh` now send `Authorization: Bearer ut_...`. Masking format is the first 6 characters of the token followed by `***` (e.g. `ut_abc***`).
- **`upload-app` SKILL.md** — Step 1A extracts `endpoint.authentication.uploadToken` from the `create_app` response and passes it as `--upload-token` in Step 4.
- **`update-app` SKILL.md** — new `5-0. Get one-time upload token` step. Right after user confirmation, the skill calls `update_app` to obtain a fresh token, then runs `update.sh` immediately. 5-minute expiry guard.
- **`setup` skill** — the `.mcp.json` template no longer adds a `--header X-API-Key: ...` pair to `args`. stdio + `npx mcp-remote` + URL is sufficient (mcp-remote handles the OAuth challenge automatically).
- **`seamos-common-rules.md` §1 — token masking rule** — masking target shifts from a static API key to a one-time upload token. The example prefix `sdm_ak_***` is replaced with `ut_***`.
- **`CLAUDE.md` / `README.md`** — Auth guidance fully rewritten around OAuth (PKCE) + multipart upload tokens. "API key issuance" / "secret-via-env-var" guidance removed.

### Why
sdm-backend#617 (`/mcp` OAuth Resource Server transition) and sdm-backend#621 (one-time upload token issuance for `/v2/apps[/{id}/versions]`) ship in the backend, removing any reason for the plugin to keep a static API key flow. OAuth tokens are cached by Claude Code and are not exposed to external bash scripts, so multipart uploads are split off into short-lived tokens embedded in the MCP response (Claude Code already holds an authenticated context and forwards them for the same user). The net effect is zero secrets a user has to enter.

### Migration
- Users on v0.7.0: after updating, the `seamos_api_key` field disappears from the plugin settings panel (silently ignored). The next marketplace MCP call opens a browser for SeamOS login — log in once and the token is cached.
- Users with an existing project-scope `.mcp.json`: delete the `"--header"`, `"X-API-Key: ..."` pair from `args` directly, or rerun `setup --reconfigure`.
- Multipart upload flows (upload-app / update-app) are unchanged from the user's perspective — token issuance, consumption, and expiry are handled entirely inside the plugin.

## [0.7.0] — 2026-05-06

SeamOS 앱 개발의 첫 진입을 일관되게 만드는 두 신규 스킬(`setup`, `init-customui`)을 추가하고, USER_ROOT 마커를 `.mcp.json` 일원에서 새 마커 `.seamos-workspace.json` 로 분리. 기존 `create-project` 의 `find_user_root` 함수는 두 마커를 OR 로 인식하도록 1줄 패치(역호환). 두 가지 플러그인 설치 스코프(project / user)를 자동 감지해 산출물이 달라진다.

### Added
- **`setup` 스킬 신설** — SeamOS 1회용 환경 부트스트랩. `${USER_ROOT}/.seamos-workspace.json` (워크스페이스 마커 + UI prefs + marketplace endpoint) 작성, project scope 시 `${USER_ROOT}/.mcp.json` (stdio + npx mcp-remote, dev URL default) 도 작성, `seamos-assets/{builds,screenshots}/` 부트스트랩. 멱등 — 재실행 시 변경 없으면 모든 step `[skip]` 통과. `--workspace-dir`, `--endpoint dev|local|<URL>`, `--reconfigure`, `--non-interactive`, `--dry-run` 지원.
- **`init-customui` 스킬 신설** — 앱마다 UI 폴더 scaffold. **vanilla** 모드는 `customui-src/` 를 만들지 않고 깊은 `ui/` 가 직접 작업 폴더(빌드 단계 없음). **react** 모드는 `${USER_ROOT}/${PROJECT}/customui-src/` 에 React 템플릿(`AGMO-Inc/custom-ui-react-template`) clone + `npm install` + deploy 출력 경로 자동 패치(vite.config 또는 package.json), 깊은 `ui/` 에 `.seamos-do-not-edit.md` 가드 마커 자동 생성. `--reset` 모드 전환 시 깊은 `ui/` 를 `ui.bak.{timestamp}/` 로 자동 백업. workspace JSON 의 `ui.activeSrcPath` 를 SSOT 로 갱신해 customui-* 친척 스킬이 한 필드만 보고 작업 위치를 결정.
- **`shared-references/scripts/find-user-root.sh`** — USER_ROOT 마커 탐색 공유 lib (`.seamos-workspace.json` OR `.mcp.json`). sourceable + CLI 듀얼 인터페이스, `SEAMOS_ALLOW_PWD_FALLBACK=1` fallback.

### Changed
- **`create-project.find_user_root` — `.seamos-workspace.json` 도 마커로 인식 (back-compat OR 의미론, 1줄 패치)**. 기존 `.mcp.json` 동작 그대로 유지. WARN/ERROR 메시지 갱신 — `run 'setup' first or run inside a project that has either marker at its root`.
- **`create-project` SKILL.md — "Next step: `init-customui`" callout** Stage 1C 직후 추가. orchestrator 가 자연 라우팅하는 의도 명시 (하드 체이닝 X).

### Why
디자인의 핵심 균열: 현재 `create-project` 는 `.mcp.json` 을 USER_ROOT 마커로 가정하는데, **마켓플레이스 user-scope 설치 시 플러그인이 MCP 를 자동 등록하므로 사용자 워크스페이스에 `.mcp.json` 이 존재할 이유가 사라진다**. 이 균열을 메우기 위해 마커를 `.seamos-workspace.json` 로 분리하고, MCP 설정과 워크스페이스 마커의 의미를 떼어냈다.

UI 분기는 또 다른 빈자리였다: 현재 어떤 스킬도 vanilla / react UI 프레임워크 선택을 다루지 않았으며, React 빌드 산출물과 vanilla 작업 파일이 같은 깊은 `ui/` 폴더를 공유하면 agent / 사용자가 어디를 수정해야 할지 헷갈리는 인지 부하가 발생한다. 이를 해결하기 위해 `ui.activeSrcPath` 단일 SSOT 필드 + react 모드의 가드 마커 파일 패턴을 도입했다. `agmo:setup` 과의 트리거 충돌은 description 트리거 phrase 를 SeamOS 컨텍스트와 강결합해 회피했다(상세 — `skills/setup/references/trigger-design.md`).

## [0.6.3] — 2026-05-06

PR #29 (`seamos-customui-ux` 스킬 신설 — UX 원칙 + ADS Foundation rule) 머지에 맞춰 v0.6.2 가 `seamos-customui-client` 에 추가했던 ADS 라우팅 본문을 `seamos-customui-ux` 로 이전. 두 스킬이 동일한 ADS hard rule 을 중복으로 외치는 상태(SSOT 위반)를 정리하고, 통신 vs 디자인 시스템 책임 분담을 명확화.

### Changed

- **`seamos-customui-client` SKILL.md — Design system 섹션 제거, cross-ref 한 줄로 축약.** v0.6.2 가 추가했던 "Design system — `@seamos/ads` (ADS)" 섹션(Hard rule + vanilla fallback + ADS MCP 도구 표)을 통째로 삭제하고, "UI 디자인 시스템 규칙은 `seamos-customui-ux` 가 정의한다" 형태의 cross-reference 만 보존. Pattern selection 표의 "What component should I use for X" 행도 동일한 cross-ref 로 정리.
- **`seamos-customui-ux` SKILL.md — vanilla CustomUI fallback 단락 흡수 (PR #29 PR-side fixup, 본 머지 commit 76761d9 에 squash 됨).** v0.6.2 가 명시했던 "vanilla 인 경우 CSS variables + DOM 구조 + 클래스명 복제" 가이드를 Foundation rule 직하위 sub-section 으로 이전. "vanilla 는 렌더링 선택일 뿐, 시스템 opt-out 이 아니다" 원칙을 명시.
- **`seamos-customui-ux/references/ads-mcp.md` — Registration 섹션 톤 조정 (PR #29 PR-side fixup, 본 머지 commit 76761d9 에 squash 됨).** 무조건 "수동 등록" 으로 안내하던 본문을 "플러그인 내부에서는 자동 등록 / standalone 시에만 수동 등록" 두 단락으로 분리. v0.6.2 의 자동 등록 사실과 정합.

### Why

v0.6.2 와 PR #29 가 독립적으로 작성되며 **같은 ADS 메시지를 두 스킬에서 따로 외치고 vanilla 가이드/자동등록 사실이 모순**되는 상태를 해결. 책임 분담 — 통신 프로토콜은 `seamos-customui-client`, 디자인 시스템·UX 원칙은 `seamos-customui-ux`. PR #29 의 PR-side 보정 2 건은 PR 머지 commit 에 squash 흡수돼 있고, 본 패치는 master 측 `seamos-customui-client` 정리 + 버전 sync.

## [0.6.2] — 2026-05-06

`@seamos/ads` (Agmo Design System) MCP 서버를 플러그인 매니페스트에 내장 등록 + `seamos-customui-client` 스킬에 ADS 라우팅 규칙을 추가. 플러그인 설치만으로 ADS 컴포넌트 카탈로그(props·CSS variables·예제)가 Claude Code 에 자동 연결되며, CustomUI 코드 작성 전 ADS 를 우선 조회하는 흐름이 스킬 본문에 강제된다. 이로써 SeamOS 앱 UI 의 시각적 일관성이 코드젠 단계에서 자동 확보된다.

### Added

- **`ads` MCP 서버 자동 등록** (`mcp-servers.json`) — `https://mcp.ads.seamos.io/` HTTP transport, 무인증. ADS 팀이 무인증 운영을 향후에도 유지하기로 합의. 도구: `list_components`, `get_component`, `search_components`.
- **`seamos-customui-client` 스킬 — "Design system" 섹션 신규** — ADS 컴포넌트를 우선 조회하도록 강제하는 hard rule + Pattern selection 표 행 2 건 추가. CustomUI 가 vanilla HTML/JS 인 현실을 반영해, ADS React 컴포넌트를 그대로 못 쓰는 경우 **CSS variables + DOM 구조 + 클래스명 + 인터랙션 상태**를 `get_component` 예제로부터 복제하라는 가이드를 명시.

### Notes — 의도적 비결정

- `@seamos/ads` npm 의존성 자동 주입은 보류. 현재 CustomUI 가 대부분 vanilla 라 React 런타임을 강제하면 비용 대비 이득이 작음. React 기반 CustomUI 가 더 흔해지면 `create-project` 의 UI 템플릿에 시드하는 형태로 후속.
- `ads` MCP 의 버전 핀 미적용. 카탈로그가 항상 최신 ADS 를 반영하므로 SeamOS 앱이 사용 중인 `@seamos/ads` 버전과 표류 가능. ADS MCP 가 `?version=` 헤더/쿼리를 제공하면 도입.

## [0.6.1] — 2026-04-30

브랜드 일관성을 위해 MCP 설정·스킬·문서 전반의 `sdm` / `SDM` 표기를 `seamos` / `SeamOS` 로 일괄 정리. 이는 **breaking change** 로, plugin userConfig 키와 MCP 서버 이름이 변경되어 기존 설치 사용자는 키를 다시 설정해야 한다.

### Changed — Breaking

- **MCP 서버명**: `sdm-marketplace` → `seamos-marketplace`, `sdm-marketplace-local` → `seamos-marketplace-local` (`mcp-servers.json`, `.mcp.json`).
- **plugin userConfig 키**: `sdm_api_key` / `sdm_api_url` → `seamos_api_key` / `seamos_api_url` (`.claude-plugin/plugin.json`). 기존 사용자는 Claude Code 의 plugin 설정에서 새 키 이름으로 재입력 필요.
- **MCP 도구 prefix**: 스킬 본문이 참조하던 `mcp__sdm-marketplace__*` 표기를 `mcp__seamos-marketplace__*` 로 갱신 (`upload-app`, `update-app`, `manage-device-app`).
- **shared reference 파일명**: `skills/shared-references/sdm-common-rules.md` → `seamos-common-rules.md` (git mv 로 history 보존). 참조 2 건 (`upload-app`, `update-app` SKILL.md) 동기 갱신.

### Changed — 문서·산문

- `CLAUDE.md`, `README.md` 의 "SDM Marketplace" / "SDM MCP Server" / "sdm-backend" 등 표기를 SeamOS 계열로 통일. `AGMO SDM System` 프로젝트명도 `AGMO SeamOS System` 으로 정리.
- 스킬 설명문·에러 메시지 (`SDM 로컬 서버에 연결할 수 없습니다` 등) 와 스크립트 헤더 (`SDM Marketplace App Upload Script` 등) 모두 SeamOS 로 갱신.
- `concept/` 의 다이어그램·PPT 생성기 라벨 ("SDM MCP Server", "sdm-backend API") 도 일괄 갱신 (gitignored — 로컬 산출용).

### Unchanged — 의도적 보존

- `sdm_ak_***` 예시 prefix (`seamos-common-rules.md` §1): 백엔드가 실제 발급하는 API 키 포맷을 문서화한 것으로, 변경 시 사용자가 실제 키 형식에 대해 혼동. 백엔드 prefix 가 바뀌면 추후 동기화.
- `.mcp.json` 의 실제 API 키 값 (`sdm_ak_*` prefixed): 외부 백엔드가 발급한 실 데이터.
- `regen-sdk-app/` (SDK 약어), `BasdMac*` (ISO-11783 SPN 표준 필드명) — `sdm` 과 무관한 우연한 부분 일치.

### Migration

기존 v0.6.0 사용자는 다음을 수행:

1. Claude Code plugin 설정에서 `sdm_api_key` / `sdm_api_url` 값을 복사해 새 키 `seamos_api_key` / `seamos_api_url` 로 재입력.
2. 로컬 `.mcp.json` 의 서버 이름을 `seamos-marketplace` / `seamos-marketplace-local` 로 수정 (실제 키 값과 URL 은 그대로 유지).
3. 외부에서 MCP 도구를 직접 참조하던 자동화 스크립트가 있다면 `mcp__sdm-marketplace__*` → `mcp__seamos-marketplace__*` 로 prefix 갱신.

## [0.6.0] — 2026-04-30

신규 스킬 `edit-plugins` — 기존 SeamOS 프로젝트의 plugin / interface 집합을 안전하게 변경하고, **변경이 실제 앱에 반영되도록 FSP + SDK skeleton 재생성을 자동 chain**. v0.5.x 까지는 SSOT 직접 편집 → `create-project --regen-fsp-only` → `regen-sdk-app` 의 3 단계를 사용자가 수동으로 묶어야 했고, 중간 단계 누락 시 running 앱이 stale FSP 를 계속 사용하는 silent failure 가 발생. 본 스킬은 이 묶음을 단일 진입점으로 통합하고, 자동 백업·롤백·offlineDB 검증·Bosch FD limitation 사후 감지까지 일괄 제공.

### Added — `edit-plugins` 스킬

`SKILL.md` + `scripts/edit-plugins.sh` (`inspect` / `apply` 서브커맨드) + 3 개 e2e eval. 트리거: "플러그인 추가", "플러그인 제거", "GPS 빼줘", "IMU 넣어줘", "edit plugins", "add plugin", "remove plugin" 등.

- **워크플로**: ① `inspect` — 현재 SSOT 의 plugin / entry JSON 출력 → ② 카탈로그(`seamos-plugins/references/catalog.md`) + 현재 사용 중 plugin 표시 → ③ 추가 plugin 의 인터페이스 / Cyclic 주기 / Adhoc 모드를 사용자에게 질문 → ④ `apply --dry-run` 으로 SSOT diff + 계획된 regen 시퀀스 미리보기 → ⑤ `--reset-tests` 여부 사용자 확인 → ⑥ 최종 확인 후 patch 적용 + `create-project --regen-fsp-only` + `regen-sdk-app` 자동 chain.
- **patch 스키마**: `{ add: [{branch, config}], remove: [{branch}] }`. add/remove 동일 branch 충돌 / 빈 결과 / 잘못된 config 문자열은 exit 2 로 차단.
- **자동 백업 + 롤백**: SSOT 갱신 직전 `<PROJECT>-interface.json.bak.<UTC-ISO>` 생성. FSP regen 실패 시 SSOT 자동 원복. SDK regen 실패 시 SSOT/FSP 보존하고 사용자에게 명시 롤백 명령 안내.
- **offlineDB 검증**: 신규 SSOT 를 `validate-interface-json.sh` 로 재검증 — unknown plugin / interface / config 진입 차단.
- **`--image-tag` 패스스루**: 사용자 환경에 `seamos-fd-headless:latest` 가 없고 `public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest` 만 있는 경우(흔한 케이스), `--image-tag` (또는 `SEAMOS_FD_IMAGE` env) 를 chain 된 두 regen 모두에 그대로 forward. 미적용 시 SDK regen 이 silent no-op 으로 끝나는 경로 차단.
- **Bosch FD limitation 사후 감지**: `UPDATE_SDK_APP` 은 앱 프로젝트에 `customui/` 폴더가 없을 때 silent no-op (SUCCESS 마커 + `SEVERE: App project does not contain the custom ui folder` 만 로그). 본 스킬은 SDK regen 후 로그를 grep 해 SEVERE 발견 시 사용자에게 명시 WARNING + mitigation 안내(신규 프로젝트면 `create-project` 새로 / 사용자 코드 있으면 stale `src-gen/<removed-plugin>/` 수동 청소).
- **`--force-clean` 절대 금지 정책**: 사용자 코드 보존이 원칙. SKILL.md 의 "Important Notes" 에 명시 — `regen-fsp-only` → `regen-sdk-app` chain 만 사용.

### Added — e2e 평가 (3 개 케이스, 실제 Docker)

`evals/evals.json` 의 3 개 케이스를 실제 fixture 프로젝트(create-project 산출 113MB 워크스페이스) 위에서 with-skill / without-skill 양쪽으로 검증.

- `add-plugin-happy-path` — IMU/accl, IMU/angle 추가 + `--reset-tests`. with_skill 880s 완료, FSP·SDK 양쪽 SUCCESSFULLY. without_skill 12 분 cap 내 chain 미완.
- `remove-plugin-with-confirmation` — GPSPlugin 전부 제거. with_skill 자동 백업/롤백/SEVERE 감지 검증. without_skill 은 FSP 만 정리되고 SDK 19 개 stale 파일 잔존 — **본 스킬이 prevent 하려는 정확한 failure 모드 입증**.
- `missing-context-routing` — `.seamos-context.json` 부재 시 exit 64 + `create-project` 안내. USER_ROOT 미변경 검증.

### Fixed — e2e 가 발견한 실제 결함 2 건

- **`set -u` + 빈 배열 unbound variable** at `edit-plugins.sh:295` — `--reset-tests` 미사용(가장 흔한 경로) 시 `${regen_args[@]}` 가 죽음. `${regen_args[@]+"${regen_args[@]}"}` 가드로 수정.
- **`--image-tag` 미전달** — SDK regen 이 default 태그(`seamos-fd-headless:latest`)로 fallback 해 사용자 환경의 ECR 풀 경로와 불일치 → silent no-op. CLI 인자 + env 양쪽 추가, dry-run 출력에도 image tag 표시.

## [0.5.9] — 2026-04-30

v0.5.7 의 `update-app` SKILL.md `argument-hint` 가 광고하던 `--feu-type` / `--arch` 인자를 `update.sh` 도 직접 받도록 구현. 자동화 파이프라인이 인터랙티브 단계 없이 `update.sh` 를 직접 호출 가능 — 스킬 레이어 우회 경로 완성.

### Added — `update.sh` 의 single-variant convenience 인자

- `--feu-type FEU` — multipart part name (단일 variant 등록용).
- `--fif PATH` — 명시적 `.fif` 경로.
- `--arch ARCH` — `<ARCH>-*.fif` 패턴으로 BUILD_DIR 단일 매칭 자동 해석. 0 매칭 / 다중 매칭은 명시 에러 (자동 첫 번째 픽업 금지).
- `--build-dir DIR` — `--arch` 해석 시 검색 루트 (기본 `./seamos-assets/builds`).
- 본 4 개 인자는 기존 `--app-file TYPE PATH` 와 혼용 불가 — 하나의 호출은 한 vector 만 사용.
- 본 변경 전에는 `update.sh` 가 `--app-file` 만 받아 자동화 파이프라인이 SKILL.md 의 인터랙티브 단계를 우회할 수 없었음 (`argument-hint` 와 `update.sh` 인자가 정합되지 않은 상태).

### Added — `update-app/scripts/test/test-args.sh` 회귀 방지 테스트

15 개 assertion: `--feu-type` + `--fif` 합성, `--arch` 단일 매칭 / 다중 / 0 매칭 분기, `--app-file` 와 mutual exclusion, `--feu-type` 단독 사용 시 에러, `--fif` / `--arch` 단독 사용 시 에러, legacy `--app-file` 경로 회귀 없음, `--dry-run` 의 API key 마스킹.

## [0.5.8] — 2026-04-30

이전 두 패치(v0.5.6, v0.5.7) 의 후속 정리. CHANGELOG 의 v0.5.4 / v0.5.5 누락 엔트리 소급 보충, `disk_packaging_policy()` 의 dry-run 안전성을 구조적으로 분리, legacy 중복 cleanup 1 줄 제거. 사용자 코드 영향 없음.

### Fixed — `disk_packaging_policy()` dry-run 경로의 구조적 안전성 분리

기존 함수는 단일 루프에서 `if [[ $dry_run -eq 0 ]]; then rm` 가드로 dry-run 비파괴성을 유지. 가드는 정상 동작했으나, 향후 함수 본문 수정 시 가드 누락이 회귀로 이어질 수 있는 구조적 취약성. 특히 build-fif.sh:421 의 dry-run 호출이 사용자 원본 워크스페이스 경로(`$APP_PATH`) 를 가리키는 한계와 결합되면 잠재적 데이터 손상 경로.

- count phase 와 mutation phase 를 물리적으로 분리. dry-run 은 count 후 즉시 `return 0` — mutation 코드에 도달 불가.
- 향후 mutation 로직이 추가되더라도 dry-run early-return 위에 작성하지 않는 한 dry-run 호출자에 영향 없음 (구조적 보장).
- `test-disk-policy.sh` 5/5 assertion 회귀 없음.

### Changed — `build-fif.sh` legacy 중복 cleanup 1 줄 제거

Java 분기의 `rm -f /tmp/nvx/app_proj/*/disk/*.mv.db /tmp/nvx/app_proj/*/disk/*.trace.db /tmp/nvx/app_proj/*/disk/*.mv.db.backup_*` 줄은 v0.5.6 의 `disk_packaging_policy()` 도입으로 완전히 흡수됨. 무해하나 정리.

### Added — CHANGELOG 소급 엔트리

- `[0.5.5] — 2026-04-29` — 4 스킬 11 건 실전 피드백 (cpp.md 빌드 함정 5 건, customui-client REST 라우트 포트, run-app 외부 프로젝트 / 포트 토폴로지, update-app fallback 가이드, update.sh 5xx retry, manage-device-app reconciliation).
- `[0.5.4] — 2026-04-28` — `fd-cli:stable` 이미지 GUI `8.6.0-260421.1217` 업그레이드.

### Fixed — `marketplace.json` 버전 sync

v0.5.6 / v0.5.7 PR 에서 누락된 `marketplace.json` 의 `version` 필드를 `0.5.5 → 0.5.8` 로 sync.

## [0.5.7] — 2026-04-30

`update-app` 의 fallback 흐름이 `.fif` 파일명에서 feuType 을 추정하던 휴리스틱을 제거. ARCH 토큰 파싱과 feuType 명시 질문을 분리하고, `last_app_register` 캐시(v0.5.6) 와 결합해 잘못된 feuType 으로 marketplace 에 등록되던 사고 경로를 차단.

### Fixed — `update-app` 파일명 → feuType 휴리스틱이 잘못된 ARCH 등록을 유발

기존 fallback 은 `get_app_status` 응답에 `feuType` 필드가 없을 때 `.fif` 파일명에서 `feuType` 을 *추정*(예: `RCU4-3Q-20.fif → RCU4-3Q/20`) 했음. 같은 앱이 여러 ARCH 변형으로 빌드된 경우(`RCU4-3Q-20.fif`, `RCU4-7Q-20.fif`) 파일명에서 feuType 을 결정할 수 없고, 잘못된 feuType 으로 marketplace 에 등록되거나 다른 ARCH 디바이스에 잘못된 바이너리가 배포되는 보안/배포 정합성 결함이었음.

- 파일명에서는 ARCH 토큰만 파싱(`<ARCH>-<VERSION>.fif` 컨벤션). feuType 은 *추정하지 않고* 별도 단계로 분리해 사용자에게 명시 질문.
- ARCH 토큰 파싱 실패 시 ARCH 와 feuType 모두 직접 입력 fallback.
- `--feu-type FEU` / `--arch ARCH` argument-hint 추가 — 자동화 파이프라인이 인터랙티브 단계 없이 명시 주입 가능.
- 다중 ARCH 빌드가 BUILD_DIR 에 공존할 때 어느 ARCH 를 등록할지 명시 선택 단계 추가.
- 확인 프롬프트에 (appId, feuType, ARCH, version) 4-tuple 모두 표시. 한 호출당 하나의 feuType 정책 명문화.

### Added — `last_app_register` 캐시 흐름

`update-app` 이 등록 성공 후 `last_app_register.{feuType, arch, appId, updatedAt}` 4 필드를 캐시. 다음 호출 시 같은 appId 라면 후보 목록의 첫 항목으로 `<feuType> (last used)` 제시 — **자동 채택은 하지 않음**, 항상 사용자 확인. appId 가 다르면 캐시 무용.

### Added — 회귀 방지 테스트

- `update-app/scripts/test/test-fallback-doc.sh` — 13 개 assertion: argument-hint, ARCH/feuType 분리, 휴리스틱 어휘 0건, 단일 feuType 정책, 다중 ARCH 분기, fixture 유효성.
- `update-app/scripts/test/fixtures/get_app_status_no_feutype.json` — `feuType` 키 부재 mock (fallback 진입 트리거 시뮬레이션).

## [0.5.6] — 2026-04-30

`build-fif` 의 disk 무차별 패키징 결함을 잡고, 빌드/regen/runtime 의 3 경로 정책(`./db/` working / `disk/<feature>/` persistent / `disk/seed/` allowlist) 을 6 개 문서에 일관 명시. `update-app` 측 fallback 휴리스틱 제거를 위한 `last_app_register` 캐시 스키마 신설(`update-app` 본 동작 변경은 v0.5.7 에서 따라옴).

### Fixed — `build-fif` 매 버전 업데이트마다 디바이스 DB 가 빌드 시점 snapshot 으로 롤백

build-fif.sh 의 cleanup 단계가 사용자 워크스페이스의 `disk/` 디렉토리(개발 중 쌓인 H2/SQLite 운영 데이터 포함)를 통째로 FIF 에 패키징해 디바이스에 배포되던 회귀. Java cleanup 분기는 `*.mv.db` 정도만 부분 제거했고 C++ 분기에는 대응 코드가 전무했음. 결과적으로 새 버전을 올릴 때마다 디바이스 운영 DB 가 빌드 시점 사본으로 강제 롤백되며, 시드 데이터와 우연한 dev 데이터를 구별할 방법이 없었음.

- `disk_packaging_policy()` 함수 신설 — `disk/seed/` 만 allowlist 로 보존, 그 외 `disk/**` 는 빌드 임시 사본에서 제거. apply/dry-run 양쪽 지원, bash 3.2 호환, `set -e` 친화적.
- Java/C++ cleanup 분기 양쪽에서 빌드 임시 사본 경로(`/tmp/nvx/app_proj/$(basename "$APP_PATH")`) 에 대해 호출. 사용자 원본 워크스페이스는 절대 건드리지 않음.
- DRY-RUN 출력에 `APP_TYPE`/`APP_PATH`/`SDK_PATH`/`DISK_POLICY`/`DISK_SCAN_RESULT` 5 필드 추가 — 빌드 전에 어떤 파일이 제외/보존되는지 사전 확인 가능.
- 산출물 캡처를 `cp ... 2>/dev/null` + `ls *.fif | head -1` 침묵 패턴에서 명시 배열 + 0 개 검출 시 `No FIF artifact produced` 에러 + 다중 FIF 모두 보고로 교체.

### Added — 3 경로 정책 6 개 문서에 일관 명시

`./db/` (working DB, gitignored) / `disk/<feature>/...` (persistent, 디바이스 측 생성) / `disk/seed/...` (allowlist, 빌드 시 포함, 첫 부팅 시 디바이스로 복사) 세 경로의 책임 분리를 다음 6 개 파일에 일관 명시:

- `build-fif/SKILL.md` — Disk packaging policy 섹션 신설
- `build-fif/references/build-details.md` — Disk Packaging Policy 섹션 + 표 + 디렉토리 트리 예시
- `seamos-app-framework/SKILL.md` — Notes 에 DB path conventions 표
- `seamos-app-framework/references/usage-patterns/java.md` — DB Persistence 헤더 직후 단락 prepend (H2 기준)
- `seamos-app-framework/references/usage-patterns/cpp.md` — DB Persistence 헤더 직후 단락 prepend (SQLite 기준)
- `regen-sdk-app/SKILL.md` — 보존 정책 표에 `disk/` 행 추가 (regen 은 보존 / build-fif 는 disk/seed/ 만 패키징)

### Added — `last_app_register` 캐시 스키마

`shared-references/seamos-context-cache.md` 에 `update-app` 의 마지막 등록 컨텍스트(`feuType`/`arch`/`appId`/`updatedAt`) 를 캐시하는 영역 신설. `update-app` 본 동작 변경(fallback 휴리스틱 제거) 은 v0.5.7 에서 따라옴.

### Added — 회귀 방지 테스트

- `build-fif/scripts/test/test-disk-policy.sh` — 5 개 assertion: apply mode stdout 포맷, `disk/seed/` 만 보존 검증, dry-run 포맷, dry-run 비파괴성, `disk/` 부재 시 안내 메시지.

## [0.5.5] — 2026-04-29

플러그인을 사용해 SeamOS 앱을 실제로 개발하던 중 발견된 함정 / 누락 / 오기재 11 건을 4 개 스킬에 일괄 반영. 사용자 코드 영향 없음 — 모두 가이드 보강과 `update-app/scripts/update.sh` 의 보수적 retry.

### Fixed — `seamos-app-framework` C++ 가이드의 빌드 실패 / 런타임 침묵 함정 5 건

- `FileProvider` 네임스페이스 정정: `nevonex::resource` (잘못된 `fcal::` 제거).
- Boost 1.73 호환 — `copy_options::overwrite_existing` 미존재. `remove(dst); copy_file(src, dst);` 패턴으로 통일.
- `Poco::Data` `use(T&)` 가 non-const 강제(`static_assert`). by-value / local-copy 우회 패턴 명시.
- CMake `target_link_libraries(Poco::Data Poco::DataSQLite)` 한 줄 스니펫 추가 — 기존 문서엔 헤더 사용법만 있어 항상 링크 실패.
- 보존 vs 재생성 파일 표 — DB 의존성은 프로젝트 루트 `CMakeLists.txt` 에 두어야 `regen-sdk-app` 시 살아남음.

### Fixed — `seamos-customui-client` REST 라우트 포트 가이드 누락

`registerRoute("/crops", ...)` 같은 REST 라우트도 assigned port 가 필요. UI gateway(`:6563`) 는 정적 + `get_assigned_ports` 만 프록시. "REST routes use the same port" 섹션과 `api()` 헬퍼 추가.

### Fixed — `run-app` 외부 프로젝트 / 포트 토폴로지 가이드

- 외부 프로젝트(`USER_ROOT` 밖) 는 `APP_PROJECT_ROOT=...` env 필수 — 첫 페이지 인용 박스로 끌어올림.
- `--via-fd-cli` 포트 토폴로지 표 — `:6563` UI gateway vs `:1456` cpp_app(REST+WS) 명확화.

### Fixed — `update-app` `get_app_status` 응답에 `feuType` 미포함 시 fallback 흐름 가이드

`builds/` 의 `.fif` 파일명 기반 fallback 분기를 SKILL.md 에 명시. (이 fallback 자체가 잘못된 휴리스틱이라는 점은 v0.5.7 에서 별도 fix 됨.)

### Fixed — `update-app/scripts/update.sh` 5xx / EntityManager 응답 자동 재시도

5xx 또는 JPA `EntityManager` 패턴 응답에 대해 2 초 대기 후 1 회 자동 재시도. 4xx 는 즉시 실패 유지. `bash -n` + dry-run smoke test 통과.

### Fixed — `manage-device-app` task-status 폴링 timeout reconciliation

폴링을 "5 번 시도" → 5 분 wall-clock 타임아웃으로 변경. `RUNNING` 상태로 영원히 박히는 알려진 백엔드 버그를 회피하기 위해, 타임아웃 시 `list_installed_apps` 로 디바이스 측 상태를 진실로 채택하는 reconciliation 로직 추가.

## [0.5.4] — 2026-04-28

`run-app --via-fd-cli` 가 사용하는 `public.ecr.aws/g0j5z0m9/fd-cli:stable` 의 베이크된 FeatureDesigner 빌드를 2026-02-12 → 2026-04-21 (`8.6.0-260421.1217`) 로 갱신. 같은 `:stable` 태그로 푸시했으므로 코드 / 스크립트 / 문서 변경 0 건. 호스트는 `docker pull --platform linux/amd64 .../fd-cli:stable` 한 번만 강제 갱신 필요. 백업 태그 `:stable-prev-260212` 보유 (롤백용).

### Changed — `fd-cli:stable` 이미지 GUI 업그레이드

- `docker/fd-cli/Dockerfile` 신규: 기존 `:stable` 위에 `/opt/nevonex/` 만 새 GUI 로 교체하는 상속 빌드.
- `INSTALL_x86_64.tar.xz` 는 `cpp.codegen` jar 에서 빌드 시 미리 추출해 `fd-commands.sh` prep step 이 첫 launch 전에 찾도록 배치.
- `.dockerignore` 에 `ref/FD/*.tar.gz` 빌드 컨텍스트 허용 추가.

## [0.5.3] — 2026-04-28

`run-app --via-fd-cli` 와 `regen-sdk-app` 의 실전 사용 중 드러난 6종 버그/제약을 한 번에 수정. 모두 코드 변경 없이 스킬 측에서 흡수 가능한 케이스라 패치 버전 bump.

### Fixed — `run-app --via-fd-cli` Platform Service 아카이브 경로 변경 미대응

`fd-cli` 이미지(2026-02-26 빌드 이후) 가 NEVONEX Platform Service 런타임 아카이브를 SDK(`<APP>_CPP_SDK/dependencies/INSTALL_x86_64.tar.xz`) 대신 **이미지 내부**(`/opt/nevonex/configuration/org.eclipse.osgi/<id>/.cp/dependencies/INSTALL_x86_64.tar.xz`) 로 옮긴 변경에 대응. prep step 이 SDK 경로에서 아카이브를 못 찾으면 `mkdir` 만 한 채 추출 실패 → `lib/` 부재로 `FATAL exit(3)` 발생하던 회귀를 제거.

- `run-via-fd-cli.sh` prep step 의 아카이브 후보 목록을 (1) 레거시 SDK 경로 → (2) 이미지 내부 경로(OSGi bundle id 동적 탐색) 순으로 확장.
- `fd-commands.sh` build 단계도 동일한 폴백 적용.
- 추출 시도조차 못 한 경우와 추출 후 `lib/` 누락을 분리 진단 메시지로 출력.

### Fixed — Eclipse Plugin layout `.gen.tests/` 미컴파일로 `TestSimulator` 침묵

FD Headless 가 emit 한 `com.bosch.fsp.<APP>.gen` / `com.bosch.fsp.<APP>.gen.tests` 가 PDE plugin layout(`pom.xml` 부재, `META-INF/MANIFEST.MF` + `src/` + `lib`/`testlib`) 으로 떨어진 프로젝트에서, `fd-commands.sh` 가 Maven 빌드만 시도하고 그 외 layout 은 손대지 않아 `bin/` 이 비어 있는 채 `test` 명령이 `NoClassDefFoundError: com.bosch.nevonex.sdk.test.TestSimulator` 로 침묵하던 문제. 결과적으로 시뮬레이터의 시그널 publish 가 일어나지 않아 cpp_app controller 도 침묵.

- `fd-commands.sh` 에 `compile_eclipse_plugin()` 헬퍼 추가 — `lib/` + `testlib/` 자동 classpath 수집, sibling 모듈 bin 경로 추가, mtime 기반 up-to-date 스킵, 비-`.java` 리소스 복사. `-source/-target 1.8` 매핑.
- Java/C++ 양 분기 모두 Maven 우선 → 미발견 시 javac 폴백.

### Fixed — `--via-fd-cli` WS readiness probe false-FAIL

cpp_app 이 `CustomUI server port:1456 started.` 까지 떴는데도 `/proc/net/tcp` IPv4 검사 한 가지에만 의존해 60초 타임아웃으로 false-FAIL 처리하던 버그. Apple Silicon Rosetta 콜드 스타트 / IPv6 듀얼스택 바인딩 케이스를 못 잡았음.

- 세 가지 신호(`/proc/net/tcp` IPv4 + `/proc/net/tcp6` IPv6 + run.log 의 `CustomUI server port:1456 started` 마커) 중 하나만 잡혀도 PASS.
- 타임아웃 60s → 90s.

### Fixed — `--via-fd-cli` UI gateway(6563) 호스트 도달 불가

`TestSimulator` 의 Spark/Jetty 가 컨테이너 내부 `127.0.0.1:6563` (lo 인터페이스) 에만 바인딩되어 docker port-publish(`0.0.0.0:6563 → 컨테이너 6563`) 로 들어온 요청이 응답을 못 받던 문제. `diagnose` layer 5 가 항상 FAIL 처리되었음.

- `fd-cli-runtime/scripts/ui-forwarder.py` (python3 표준 라이브러리만 사용하는 TCP forwarder) 추가.
- `run-via-fd-cli.sh` 가 host UI 포트를 컨테이너 내부 `16563` 으로 publish 하고, test 단계 직후 `0.0.0.0:16563 → 127.0.0.1:6563` forwarder 를 백그라운드로 자동 기동.
- escape hatch: `--ui-port 0` (publish/forwarder 모두 skip), `RUNAPP_NO_UI_FORWARDER=1` (구 동작으로 fallback).

### Fixed — `--via-fd-cli` `APP_PROJECT_ROOT` 자동 해석

기본 경로가 플러그인 트리(`${USER_ROOT}/<APP>/<APP>`) 한 곳만 보고 있어, 사용자가 다른 워크스페이스에서 작업할 때 매번 `APP_PROJECT_ROOT=...` env 를 명시 지정해야 했던 불편 제거.

- 후보 경로를 (1) caller 지정 → (2) 플러그인 트리 → (3) `$PWD/<APP>/<APP>` / `$PWD/<APP>` / `$PWD` → (4) `$SEAMOS_WORKSPACE/<APP>/<APP>` 순으로 탐색.
- 각 후보는 `com.bosch.fsp.<APP>` 디렉터리 존재로 검증.
- 실패 시 시도된 후보 목록과 수정 방법을 명시.

### Added — `regen-sdk-app --reset-tests` (시뮬레이터 스캐폴드 강제 재생성)

Bosch `UPDATE_SDK_APP` 이 `.gen.tests/` 트리 전체를 user-data 로 간주해 절대 덮어쓰지 않는 보존 정책상, **인터페이스에 새 플러그인을 추가해도 `SDKTest.java` 가 옛 provider 만 하드코딩한 채 남아 새 시그널이 publish 되지 않는** 구조적 결함을 우회.

- `--reset-tests`: UPDATE_SDK_APP 호출 직전 `<PROJECT>/com.bosch.fsp.<PROJECT>.gen.tests/` 삭제 → FD 가 현재 FSP/Manifest 기준으로 시뮬레이터를 재생성.
- 사용자 변경 자동 감지: `src/**/*.java` 중 `.classpath` 보다 mtime 이 새로운 파일이 있으면 거부. `--i-know-this-deletes-test-code` 로만 우회.
- `--dry-run` 출력에 reset 동작 명시.
- SKILL.md 의 시나리오 매트릭스에 인터페이스 변경 + 시뮬레이터 갱신 케이스 추가.

### Notes

- 컨테이너 내부의 `__pycache__/`, `*.pyc` 가 워크스페이스 bind-mount 로 호스트에 노출될 수 있어 `.gitignore` 에 추가.

---

## [0.5.2] — 2026-04-28

### Fixed — interface 변경 시 사용자 작성 코드 손실 (data-loss bug)

`regen-sdk-app` SKILL.md 가 interface JSON 변경 시 `create-project --force-clean` → `regen-sdk-app` 두 단계 레시피를 안내했는데, `--force-clean` 이 워크스페이스 전체(`<PROJECT>/<PROJECT>_<APP>/` 하위 사용자 코드 포함)를 `rm -rf` 로 날리는 동작이라 **사용자 hand-written 코드가 묵음 삭제되는 버그**였다. PDF §4 (UPDATE_SDK_APP) 에 따르면 입력은 FSP + 기존 APP 프로젝트뿐 — interface.json 은 보지 않으므로, FSP 만 재생성하면 충분하다는 사실 재확인.

### Added — `create-project --regen-fsp-only` (FSP-only 재생성)

`com.bosch.fsp.<PROJECT>/` 폴더만 삭제 → Stage 1A (`GENERATE_FSP`) 만 재실행 → APP 프로젝트와 사용자 코드는 보존. Stage 1B 는 자동 스킵 (`regen-sdk-app` 으로 SDK 훅을 보존된 APP 프로젝트에 머지).

- `--force-clean` / `--resume` / `--skip-sdk-app` 와 mutex.
- 워크스페이스 미존재 시 exit 64 (사용자에게 `create-project` 먼저 실행 안내).
- 컨텍스트 캐시의 `sdk_app_completed_at` / `app_project_path` 보존.

### Added — `--force-clean` 가드레일

APP 프로젝트 폴더에 사용자 코드가 있을 때 `--force-clean` 단독 실행 거부. `--i-know-this-deletes-app-code` 명시적 동의 플래그를 함께 전달하거나 `--regen-fsp-only` 로 우회하도록 안내.

### Fixed — `--force-clean --dry-run` 이 실제로 워크스페이스를 삭제하던 버그

`rm -rf` 분기가 dry-run 가드 이전에 있어서 dry-run 모드인데도 디스크 변경이 발생. `--force-clean` / `--regen-fsp-only` 두 분기 모두 dry-run 시에는 "would remove" 만 출력하도록 수정.

### Changed — codegen.type 기본값 JAVA → CPP, 자동 감지 추가

팀 컨벤션 반영 (대다수 production SeamOS 앱이 C++).

- **자동 감지**: 기존 APP 프로젝트의 빌드 파일 기반 — `CMakeLists.txt` → `CPP`, `pom.xml` → `JAVA`. `regen-fsp-only` / `regen-sdk-app` / resume 시나리오에서 작동.
- **컨텍스트 우선**: `.seamos-context.json` 의 `last_project.codegen_type` 가 있으면 그 값을 우선 사용.
- **fresh project**: 자동 감지 불가 시 fallback 은 `CPP`. 비대화형(`-t 0` false) 환경에서는 `--codegen-type` 명시 안 하면 여전히 exit 64 — fresh 프로젝트는 사용자 의도를 묵음 default 하지 않음.
- `build-config-prop.sh` 의 디폴트도 `JAVA` → `CPP`.

### Changed — SKILL.md 표/안내문 정정

- `regen-sdk-app/SKILL.md`: "When to Use" 표에 "User code preserved?" 컬럼 추가, interface 변경 행을 `--regen-fsp-only` 레시피로 교체.
- `create-project/SKILL.md`: argument-hint 갱신, `--regen-fsp-only` / `--i-know-this-deletes-app-code` 문서화, "Recipe: interface JSON changed, keep app code" 섹션 추가.
- `regen-sdk-app.sh`: FSP 누락 에러 메시지를 `--force-clean` 추천에서 `--regen-fsp-only` 추천으로 변경.

### Files

수정:
- `.claude-plugin/plugin.json` — version 0.5.1 → 0.5.2
- `skills/create-project/scripts/create-project.sh` — `--regen-fsp-only`, `--i-know-this-deletes-app-code`, dry-run 가드, codegen 자동 감지 + CPP 디폴트
- `skills/create-project/scripts/build-config-prop.sh` — codegen 디폴트 CPP
- `skills/create-project/SKILL.md` — 신규 플래그 + 안전 레시피 문서화
- `skills/regen-sdk-app/scripts/regen-sdk-app.sh` — codegen 자동 감지 + CPP 디폴트, FSP 누락 안내문 정정
- `skills/regen-sdk-app/SKILL.md` — When-to-Use 표 사용자 코드 보존 관점으로 재구성

### Compatibility

- 기존 사용자: 동작 변화 없음 (모든 신규 플래그는 opt-in).
- 단, `--force-clean` 을 APP 코드가 있는 워크스페이스에 사용하던 자동화 스크립트는 `--i-know-this-deletes-app-code` 추가 필요 — **고의된 breaking change** (data-loss 가드).
- codegen 디폴트가 CPP 로 바뀌었지만, 비대화형에서는 여전히 `--codegen-type` 명시 필요하므로 기존 자동화 영향 없음.

---

## [0.5.1] — 2026-04-27

### Fixed — Docker CLI 탐색을 cross-platform 으로 일반화

스킬 스크립트가 비대화형 bash 에서 실행될 때 macOS 의 `docker` shell alias 가 보이지 않아 `Docker is not installed` 로 오탐하던 문제 수정. Linux / macOS / Windows (Git Bash, WSL) 모든 환경에서 동작하도록 docker 탐색 로직 일반화.

- **신규 탐색 우선순위**: `$DOCKER` env override → `command -v docker` / `command -v docker.exe` → 플랫폼 표준 경로 8개 (Linux: `/usr/bin`, `/usr/local/bin`, `/snap/bin` · macOS: `/opt/homebrew/bin`, `/Applications/Docker.app/Contents/Resources/bin` · Windows Git-Bash: `/c/Program Files/Docker/Docker/resources/bin/docker.exe` · WSL: `/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe`).
- **PATH augmentation**: docker 바이너리 발견 시 그 디렉토리를 `PATH` 에 prepend — `docker buildx` / `docker compose` 같은 plugin 호출 안정화.
- **에러 메시지 개선**: Linux/macOS/Windows 별 install 명령 분기, `DOCKER=/path/to/docker` escape-hatch 안내 추가.

### Files

수정:
- `skills/build-fif/scripts/build-fif.sh` — `resolve_docker()` 함수 추가
- `skills/build-fif/references/build-details.md` — Troubleshooting 표 3-OS + `DOCKER=` escape-hatch 반영
- `skills/run-app/scripts/run-app.sh` — mac-only 폴백을 8-경로 cross-platform 으로 확장, `docker.exe` 인식
- `skills/run-app/scripts/run-via-fd-cli.sh` — 동일 확장
- `skills/create-project/scripts/preflight.sh` — docker 체크 직전 PATH augmentation 삽입, `docker.exe` 인식

### Compatibility

- 기존 Linux / Docker Desktop 표준 설치 환경 무영향.
- macOS 에서 `docker` 가 shell alias 로만 정의된 경우(즉 `/usr/local/bin/docker` symlink 부재) 자동 회복.
- Windows Git Bash / WSL 사용자 신규 지원.

---

## [0.5.0] — 2026-04-27

### Added — `run-app` 스킬 (신규)

CPP / Java SeamOS 앱을 로컬 Docker 안에서 build → run → test 까지 자동화하는 개발 루프 스킬. 기기 배포 (`manage-device-app`) 와 별개의 dev-loop 도구.

- **`--with-mqtt` (Java 기본)**: `app-builder` 이미지 안에서 cmake/mvn 빌드 + 앱 spawn + Java `TestSimulator` spawn + Mosquitto sidecar 컨테이너 자동 기동. Single-file staging overlay (Simulator.properties / feature.config / connection.props / sample_data.xml) 로 호스트 원본 무수정. `--inject-data` / `--props key=val` 로 testdata / properties override 지원.
- **`--via-fd-cli` (CPP 기본 — auto-route)**: ECR `public.ecr.aws/g0j5z0m9/fd-cli:stable` 이미지 (`/workspace/.nevonex/dependencies/<ver>/lib/` 베이크 — Platform Service runtime 포함) 로 build → run → test 위임. `app-builder` 이미지의 Platform Service 부재 한계 우회. `--skip-build` 로 빌드 산출물 재사용 빠른 반복 테스트.
- **CPP 자동 라우팅**: APP_TYPE 자동 감지 (`<APP>_CPP_SDK/` → CPP, `pom.xml` → Java). CPP 는 자동으로 `--via-fd-cli` 분기, Java 는 `app-builder` 유지. `--use-app-builder` (또는 `USE_APP_BUILDER=1`) 로 강제 우회 (Java parity 테스트 / app-builder 디버깅용).
- **`--diagnose` 5-layer 진단**: 실행 중인 앱의 데이터 흐름을 한 번에 검증.
  1. broker reachable (`$SYS` publish counter)
  2. topic activity (`fek/#` 12s sample, count + 첫 메시지)
  3. WS handshake (101 Switching Protocols)
  4. WS frames (12s sample, count + 첫 frame schema)
  5. UI HTTP (`/` + `/get_assigned_ports`)
  - 첫 FAIL layer 가 exit code (1..5) — CI/스크립트 분기 가능
  - `--skip-broker` (docker `--with-mqtt` 처럼 broker 가 host 미노출 시 layer 1, 2 SKIP)
  - `--sample-secs` 기본 12s (TestSimulator 의 `fek/3236` publish 간격 ~10s 안전 마진)
  - 호스트 mode (FeatureDesigner 직접 spawn) / docker mode 모두 동일 동작 — port 만 봄

### Verified

- **로컬 mac (arm64 Rosetta + linux/amd64)**: `bash run-app.sh --app-name SampleImu2` (CPP 자동 라우팅) → fd-cli 이미지로 SDK + APP 빌드 (~3-5분) → cpp_app + TestSimulator + UI gateway 기동 → `--diagnose` 5/5 ALL PASS, exit 0. WS frame schema `{"topic":"IMU.angle","payload":{"PL":{"angle":{"ROLL":...,"PITCH":...,"YAW":...}}}}` (vanilla FD-emitted).
- **원격 dev 머신** (`100.110.75.13`, FeatureDesigner Eclipse host-mode): `--diagnose --host 100.110.75.13` → 5/5 ALL PASS.

### Files

신규:
- `skills/run-app/SKILL.md`, `QA.md`, `references/run-app-details.md`
- `skills/run-app/scripts/run-app.sh` (driver, --diagnose / --via-fd-cli dispatch + CPP auto-route)
- `skills/run-app/scripts/diagnose.sh` (5-layer probe)
- `skills/run-app/scripts/run-via-fd-cli.sh` (fd-cli 이미지 wrapper — deps 추출, broker hostname add, WS readiness probe via `/proc/net/tcp`)
- `skills/run-app/scripts/entrypoint.sh`, `smoke-test.sh` (app-builder pipeline)
- `skills/run-app/fd-cli-runtime/scripts/{fd-commands.sh, entrypoint.sh, fd-create.py, decrypt_model.java, tcp-proxy.py}`, `fd-cli-runtime/config/supervisord.conf` — fd-cli upstream sync (Bosch FD trunk 산출물; 변경 시 재 sync 필요)

### Decisions / Caveats

- **NEVONEX Platform Service runtime 출처는 `.deb` 가 아니라 SDK tarball**. 원격 호스트 cpp_app `ldd` 검증 결과 `<workspace>/.nevonex/dependencies/<ver>/lib/libnevonex-fcal-platform.so.3` 에서 dlopen — `dpkg -l | grep nevonex` 0건. `seamos-emulator` Dockerfile 의 `.deb` install 단계는 다른 distribution path.
- **FD `Linux_HeadlessFD` product 의 application id 는 `GENERATE_FSP / GENERATE_SDK_APP / UPDATE_SDK_APP` 3개뿐**. RUN/SIMULATE 는 SWT UI handler 로만 존재 → Eclipse `-application <id>` headless 직접 호출 경로 없음. fd-cli 이미지가 GUI FD 를 포함하나 `run-via-fd-cli.sh` 는 그것 없이 fd-commands.sh 기반 직접 spawn 으로 우회.
- **fd-cli 이미지 단독 부족** — `/opt/fd-cli/scripts/`, `/workspace/.nevonex/dependencies/` 모두 docker-compose host volume 의존이 원본 설계. wrapper 가 동일 패턴으로 host bind mount 보강.
- **SAMPLE_SECS 기본 12s**: TestSimulator 의 `fek/3236` MQTT publish 간격이 약 10s — 5–6s 윈도우는 layer 2 false-FAIL 가능. WS frame 은 1Hz polling 이라 layer 4 만 보면 5s 도 충분하지만 layer 2 안전 마진을 위해 12s.
- **WS readiness probe 60s ceiling**: Apple Silicon Rosetta 환경에서 cpp_app cold start 30–45s 흡수.

### Compatibility

- `--with-mqtt` 모드 (기존 fd 0.4.x 사용자) 무영향 — Java 앱은 그대로, CPP 만 자동 라우팅.
- 강제 legacy 모드: `--use-app-builder` 또는 `USE_APP_BUILDER=1`.

### Known Limitations

- `fd-cli:stable` 이미지 ECR 인증 필요 (`aws ecr-public get-login-password`).
- `fd-cli` 이미지 약 3.8GB compressed — 첫 pull 시 충분한 디스크 필요 (`docker builder prune -f` 권장).
- `:stable` tag 는 mutable — Bosch FD trunk 변경 시 재 pull. Digest pinning 은 후속 작업 후보.
- broker 가 host 에 1883 으로 노출됨 — host 에 다른 mosquitto 가 1883 점유 중이면 충돌 (env override `MQTT_PORT` 후속 추가 필요).

---

## [0.4.5] — 이전

`chore: v0.4.5 — FD 이미지 태그 :latest 전환, codegen-type 프롬프트 강제, Dockerfile JDK 전환`

## [0.4.4]

`feat: v0.4.4 — seamos-customui-client 스킬 추가 (#14)`

## [0.4.3]

`feat: v0.4.3 — regen-sdk-app 스킬 추가 (UPDATE_SDK_APP 지원) (#12)`

## [0.4.2]

`refactor: v0.4.2 통합 USER_ROOT 레이아웃 + create-app 흡수 (#11)`

## [0.4.1]

`chore: v0.4.1 — create-project 버그 수정 + JDK 21 Temurin 전환`

[0.5.1]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.5.1
[0.5.0]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.5.0
[0.4.5]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.4.5
