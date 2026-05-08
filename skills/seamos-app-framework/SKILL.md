---
name: seamos-app-framework
description: >
  SeamOS (NEVONEX) app framework code generation guide for REST API, WebSocket, DB persistence,
  feature lifecycle, and external API server communication patterns. Supports Java and C++ projects.
  Use when developing SeamOS apps that need HTTP endpoints, WebSocket communication,
  database storage, lifecycle management, or outbound calls to external/cloud APIs
  (which must route through the Cloud plugin — apps cannot open external HTTP sockets directly).
  Triggers: "REST", "API", "endpoint", "라우트", "route", "WebSocket", "소켓", "socket",
  "DB", "database", "데이터베이스", "영속성", "persistence", "H2", "SQLite",
  "lifecycle", "라이프사이클", "CRUD", "테이블", "table", "repository",
  "saveToDisk", "persistToDisk", "handleFeatureStart",
  "external API", "외부 API", "cloud proxy", "uploadData", "extApi",
  "CloudDownloadListener", "correlation-id", "외부 서버 호출", "백엔드 외부 호출",
  "cloud-upload", "클라우드 업로드", "PendingRequestRegistry",
  "CloudMessageReceived", "CloudFileReceived", "ConnectionTypeEnum",
  "BaseRestService", "AbstractCloudDownloadListener", "EXT-frame".
---

# SeamOS App Framework

Guide for developing SeamOS apps with REST APIs, WebSocket communication, database persistence, and feature lifecycle management.

## Quick Start

1. **Identify pattern** — Determine which pattern the user needs (REST, WebSocket, DB, Lifecycle)
2. **Detect language** — Check project language (Java/C++) using same detection as seamos-plugins
3. **Load patterns** — Read `references/usage-patterns/{lang}.md`
4. **Generate code** — Apply the relevant section's patterns

## Patterns

| Pattern | Java | C++ | Use Case |
|---------|------|-----|----------|
| REST API | NevonexRoute + Spark | NevonexRoute + Poco | HTTP endpoints, CRUD |
| WebSocket | Jetty @WebSocket | WebSocketRouteFactory | Real-time communication |
| DB Persistence | H2 + FCALFileProvider | SQLite + FileProvider | Data storage with container survival |
| Feature Lifecycle | AbstractFeatureNotification | FeatureManagerListener + IgnitionStateListener | App start/stop hooks |
| External API | `BaseRestService` cloud-upload + `PendingRequestRegistry` (type→cid, 60s TTL) + `AbstractCloudDownloadListener` | `std::promise` + `/extApi` route + `CloudDownloadListener` | Outbound HTTPS to cloud / marketplace / 3rd-party. **Java and C++ conventions diverge — read the language file, don't translate across.** |

## Workflow

### Step 1: Pattern Selection

Determine which pattern the user needs:
- **REST API** — HTTP endpoints, CRUD operations, request/response handling
- **WebSocket** — Real-time bidirectional communication between app and client
- **DB Persistence** — Structured data storage that survives NEVONEX container restarts
- **Feature Lifecycle** — Hooks for app start, stop, and ignition state changes
- **External API Server Communication** — Outbound calls from the app to non-local URLs (cloud APIs, marketplace, 3rd-party). Must route through the Cloud plugin's `uploadData` + `CloudDownloadListener` channel; direct HTTP sockets are not supported. **Conventions differ by language — pick the right reference file**:
  - **C++** (`cpp.md`, ref impl `cpp_deploy_test_19`): two patterns — sync `POST /extApi` (`HTTP*` prefix, `std::promise` + 10 s wait) and async `/socket` (`WS*` prefix, WS push). UI envelope renames keys (`endPoint`/`methodSelect`). Response frame: `external_api_response`.
  - **Java** (`java.md`, ref impl `agnote-core`): `BaseRestService` cloud-upload routes (`cloud-upload/{name}`) — V1 (ack-only, registry-free) or V2 (`PendingRequestRegistry.register(cid, type)` + listener parses + `EXT-{domain}` broadcast). UI sends backend keys directly (no rename). `uploadData(data, priority, ConnectionTypeEnum)` 3-arg.

### Step 2: Language Detection

Determine the project language:
- `.fgd` filename contains `_java` → Java
- `.fgd` filename contains `_cpp` → C++
- Check `.gen` folder for `.javajet` or `.cppjet` templates
- Fallback: check `FDProject.props`

Load the appropriate pattern file:
- Java → `references/usage-patterns/java.md`
- C++ → `references/usage-patterns/cpp.md`

### Step 3: Code Generation

Read the pattern file and find the `##` section matching the selected pattern. Apply the code template directly — no placeholder substitution beyond class and variable names.

## Notes

- DB Persistence uses a dual-path architecture due to NEVONEX runc container ephemeral filesystem. The `saveToDisk(file, true)` API copies DB to a host-mounted path that survives container restarts. **overwrite parameter must be `true`.**
- Java H2 requires `WRITE_DELAY=0` to ensure data is flushed before `saveToDisk`.
- C++ FileProvider `overwrite` defaults to `false` — always pass `true` explicitly.
- C++ specifics that bite first-time authors (all in `references/usage-patterns/cpp.md`):
  - **Namespace:** `nevonex::resource::FileProvider` — there is no `::fcal::` segment despite the package being `nevonex-fcal-platform`.
  - **Boost 1.73 compat:** the SDK ships Boost 1.73; use `remove(dst); copy_file(src, dst);` instead of `copy_options::overwrite_existing` (1.74+ only).
  - **Poco `use(T&)`:** parameters bound with `Poco::Data::use(...)` must be **non-const** lvalues — `const T&` triggers a static_assert. Take by value or copy into a local before binding.
  - **CMake link:** `find_package(Poco REQUIRED COMPONENTS Data DataSQLite)` + `target_link_libraries(... Poco::Data Poco::DataSQLite)` in the **project-root `CMakeLists.txt`** (preserved across `regen-sdk-app`), not in any file under `<APP>_CPP_SDK/` (regenerated).
- REST/WebSocket patterns are NEVONEX-specific (NevonexRoute, UIWebServiceProvider). Standard HTTP frameworks do not apply.
- **REST routes registered with `registerRoute("/path", ...)` are served on the app's WS port (default 1456 in `--via-fd-cli`), not the UI gateway port (6563).** The browser must call them through the `get_assigned_ports`-derived base URL — see `seamos-customui-client` for the client-side pattern.
- **DB path conventions**:

  | 경로 | 의미 | 빌드 시 | 런타임 |
  |---|---|---|---|
  | `./db/` | 작업 DB (working copy, gitignored) | 제외 | 런타임 생성 |
  | `disk/<feature>/...` | 디바이스 영속 영역 (persistent) | 제외 | 디바이스에서 생성/유지 |
  | `disk/seed/...` | 앱이 동봉하는 시드 데이터 | **포함 (allowlist)** | 첫 부팅 시 복사 |
