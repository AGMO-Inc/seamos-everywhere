# C++ Usage Patterns

> App framework patterns for SeamOS C++ apps.

## REST API Convention

**URL Convention:** kebab-case, plural nouns, no version prefix.

**Route + RouteFactory pair (2 files per resource):**
Every REST endpoint requires TWO classes:
- `{Resource}RouteFactory` extends `NevonexRouteFactory` — creates Route instances per request
- `{Resource}Route` extends `NevonexRoute` — handles HTTP methods

**RouteFactory pattern:**
```cpp
class CropRouteFactory : public virtual ::ecore::EObject,
        public ::nevonex::web::server::NevonexRouteFactory {
public:
    NevonexRoute* createRoute(const Poco::Net::HTTPServerRequest &request) override {
        CropRoute *route = new CropRoute();
        route->setMainController(getMainController());
        return route;
    }
    void disconnect() override {}
};
```

**Route handler — override handleGet/Post/Put/Delete:**
```cpp
class CropRoute : public virtual ::ecore::EObject,
        public ::nevonex::web::server::NevonexRoute {
public:
    void handleGet(Poco::Net::HTTPServerRequest &req,
            Poco::Net::HTTPServerResponse &resp) override {
        resp.setStatus(Poco::Net::HTTPResponse::HTTP_OK);
        resp.setContentType("application/json");
        std::ostream &out = resp.send();
        // Build JSON response
        out.flush();
    }

    void handlePost(Poco::Net::HTTPServerRequest &req,
            Poco::Net::HTTPServerResponse &resp) override {
        // Parse request body
        Json::Value body;
        Json::CharReaderBuilder builder;
        std::string errs;
        Json::parseFromStream(builder, req.stream(), &body, &errs);
        // Validate, process, respond
    }
};
```

**Registration (in ApplicationMain::addCustomUIListener):**
```cpp
auto cropFactory = std::make_shared<CropRouteFactory>();
cropFactory->setMainController(getMainController());
customui::UIWebServiceProvider::getInstance()->registerRoute("/crops", cropFactory);
```

**Response format:** JSON with HTTP status codes:
```cpp
resp.setStatus(Poco::Net::HTTPResponse::HTTP_OK);           // 200
resp.setStatus(Poco::Net::HTTPResponse::HTTP_BAD_REQUEST);  // 400
resp.setStatus(Poco::Net::HTTPResponse::HTTP_NOT_FOUND);    // 404
```

**Bulk Delete:** `DELETE /resources/bulk-delete` with JSON body (same as Java).

**Directory convention:** `web/{resource}/` — {Resource}Route.hpp/.cpp + {Resource}RouteFactory.hpp/.cpp

## WebSocket

```cpp
class WebSocketEndPoint : public virtual ::ecore::EObject,
        public ::nevonex::web::server::WebSocketRouteFactory {
    static std::shared_ptr<WebSocketEndPoint> s_holder;
public:
    static std::shared_ptr<WebSocketEndPoint> getInstance();

    void onWebSocketMessage(const std::string &message) {
        // JSON parsing (JsonCPP default, RapidJSON via ifdef)
        Json::Value json;
        Json::CharReaderBuilder builder;
        std::string errs;
        auto stream = std::istringstream(message);
        if (Json::parseFromStream(builder, stream, &json, &errs)) {
            onWebSocketJsonMessage(json);
        }
    }

    void publishMessage(const std::string &message);
    WebSocketRoute* createWebsocketRoute(const Poco::Net::HTTPServerRequest &req) override;
};
```

**Registration:**
```cpp
auto wsEndpoint = WebSocketEndPoint::getInstance();
wsEndpoint->setMainController(getMainController());
customui::UIWebServiceProvider::getInstance()->registerWebsocketRoute("/socket", wsEndpoint);
```

> Browser-side counterpart (port discovery, frame protocol, cloud proxy):
> see the `seamos-customui-client` skill.

## External API Server Communication

> Authoritative spec: https://docs.seamos.io/docs/4/5/4
>
> Reference implementations: `external_api_test` (full — both patterns) and
> `cpp_deploy_test_19` (WebSocket-only variant).

### Why the indirect path

SeamOS apps **do not open TCP/HTTP sockets to external servers directly**.
Every outbound call to a non-local URL flows through the Cloud plugin, which
the platform forwards to the configured external server. The response comes
back through `CloudDownloadListener::handleMessage`. The app matches request
to response by `correlation-id`.

This isn't an arbitrary detour — it's where the platform attaches:
- Authentication and TLS / certificate validation
- Network-policy enforcement (the device's egress is locked down)
- Audit logging

App code therefore never sees the upstream's TCP endpoint, never handles
TLS, and never embeds external credentials. If you want a direct outbound
HTTP from C++, you'd need to link Poco/Boost.Beast yourself and you'd lose
all of the above — almost always wrong.

### Two patterns: pick by how the UI waits

| Pattern | UI entry | correlation-id prefix | App waits via | When to use |
|---------|----------|-----------------------|---------------|-------------|
| **A. Sync HTTP proxy** | `POST /extApi` | `HTTP*` | `std::promise` + `wait_for(10s)` | Form submit, bulk fetch, UI expects one synchronous return |
| **B. Async WebSocket** | `ws://.../socket` | `WS*` | None — push back via WS | Real-time, multiple concurrent calls, long ops |

The `correlation-id` prefix is the **single dispatch signal** in
`CloudDownloadListener::handleMessage`. Honour it when generating ids and
the same listener handles both patterns.

### Envelope key rename (UI ⇄ Cloud proxy)

The UI speaks browser-friendly keys; the Cloud channel speaks proxy-contract
keys. The translation is the app's job:

| UI sends (browser) | App forwards (Cloud proxy) |
|--------------------|----------------------------|
| `endPoint`         | `externalUrl`              |
| `methodSelect`     | `method`                   |
| `reqHeader`        | `header`                   |
| `reqBody`          | `msg`                      |
| `correlation-id` (optional) | `correlation-id` (generated if absent) |

### Request envelope struct

A small carrier struct keeps both patterns honest:

```cpp
class ExternalApiRequest {
public:
    std::string endPoint;     // External URL
    std::string method;       // GET, POST, ...
    Json::Value headerJson;   // Headers as JSON
    Json::Value bodyJson;     // Request body as JSON
};
```

### Pattern A — Sync HTTP `/extApi`

Two pieces: a singleton that parks `std::promise`s by id, and a
`NevonexRoute` that registers the promise, fires the request, and blocks
on the future.

**Correlation manager (singleton):**
```cpp
class ExternalApiRequestManager {
public:
    static ExternalApiRequestManager* getInstance();

    void addPendingRequest(
        const std::string& correlationId,
        std::shared_ptr<std::promise<std::string>> promiseObj);

    void notifyResponse(
        const std::string& correlationId,
        const std::string& responseBody);

    void removeRequest(const std::string& correlationId);

private:
    std::mutex _mutex;
    std::map<std::string, std::shared_ptr<std::promise<std::string>>>
            _pendingRequests;
};

void ExternalApiRequestManager::notifyResponse(
        const std::string& correlationId, const std::string& responseBody) {
    std::lock_guard<std::mutex> lock(_mutex);
    auto it = _pendingRequests.find(correlationId);
    if (it != _pendingRequests.end()) {
        try {
            it->second->set_value(responseBody);
        } catch (const std::future_error&) { /* already set */ }
        _pendingRequests.erase(it);
    }
}
```

**HTTP route handler — POST `/extApi`:**
```cpp
void ExternalApiRoute::handlePost(
        Poco::Net::HTTPServerRequest &req,
        Poco::Net::HTTPServerResponse &response) {
    // 1. Parse incoming UI body
    Json::Value uiBody;
    Json::CharReaderBuilder builder;
    std::string errs;
    auto stream = std::istringstream(
        std::string(std::istreambuf_iterator<char>(req.stream()), {}));
    Json::parseFromStream(builder, stream, &uiBody, &errs);

    // 2. Register a promise BEFORE firing — race-free
    auto promise = std::make_shared<std::promise<std::string>>();
    auto future  = promise->get_future();

    long ts = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    std::string cid = "HTTP" + std::to_string(ts);
    ExternalApiRequestManager::getInstance()->addPendingRequest(cid, promise);

    // 3. Build proxy envelope (rename keys) and send via Cloud
    Json::Value envelope;
    envelope["correlation-id"] = cid;
    envelope["externalUrl"]    = uiBody["endPoint"].asString();
    envelope["method"]         = uiBody["methodSelect"].asString();
    envelope["header"]         = uiBody["reqHeader"];
    envelope["msg"]            = uiBody["reqBody"];

    Json::StreamWriterBuilder writer;
    std::string envelopeStr = Json::writeString(writer, envelope);
    ::nevonex::cloud::Cloud::getInstance()->uploadData(envelopeStr, 1);
    //                                                              ↑
    //   Second arg is importance (priority). Convention: fixed at 1.

    // 4. Wait up to 10 s
    if (future.wait_for(std::chrono::seconds(10))
            == std::future_status::ready) {
        response.setStatus(Poco::Net::HTTPResponse::HTTP_OK);
        response.setContentType("application/json");
        response.set("Access-Control-Allow-Origin", "*");
        std::ostream &out = response.send();
        out << future.get();
        out.flush();
    } else {
        ExternalApiRequestManager::getInstance()->removeRequest(cid);
        response.setStatus(Poco::Net::HTTPResponse::HTTP_GATEWAY_TIMEOUT);
        std::ostream &out = response.send();
        out << R"({"status":504,"msg":"Gateway Timeout: No response."})";
        out.flush();
    }
}
```

> The 10 s timeout is the reference value — adjust per app, but cap it.
> A blocked HTTP thread in the SeamOS app starves other requests.

### Pattern B — Async WebSocket `/socket`

When the UI already has a WebSocket open, dispatch through it and push the
response back asynchronously. No promise/future, no thread blocking.

```cpp
void WebSocketEndPoint::onWebSocketMessage(const std::string &message) {
    // Parse UI message; if it's an external-API request, route it.
    Json::Value root;
    Json::CharReaderBuilder rb;
    std::string errs;
    std::unique_ptr<Json::CharReader> reader(rb.newCharReader());
    if (!reader->parse(message.data(),
                       message.data() + message.size(),
                       &root, &errs)) return;

    if (!root.isMember("endPoint")) {
        // Not an external API call — handle other UI frames (publish, etc.)
        return;
    }

    long ts = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    std::string cid = root.get("correlation-id", "").asString();
    if (cid.empty()) cid = "WS" + std::to_string(ts);

    Json::Value envelope;
    envelope["correlation-id"] = cid;
    envelope["externalUrl"]    = root["endPoint"].asString();
    envelope["method"]         = root["methodSelect"].asString();
    envelope["header"]         = root["reqHeader"];
    envelope["msg"]            = root["reqBody"];

    Json::StreamWriterBuilder writer;
    std::string envelopeStr = Json::writeString(writer, envelope);
    ::nevonex::cloud::Cloud::getInstance()->uploadData(envelopeStr, 1);
    // Response will arrive in CloudDownloadListener and be pushed to the WS.
}
```

### CloudDownloadListener — the single response handler

The same listener serves both patterns. Disambiguate by `correlation-id`
prefix. Pattern A resolves the parked promise; Pattern B re-wraps and pushes
to the UI WebSocket as `external_api_response`.

```cpp
void CloudDownloadListener::handleMessage(const std::string &_content) {
    Json::Value response;
    Json::CharReaderBuilder builder;
    std::string errs;
    auto stream = std::istringstream(_content);
    if (!Json::parseFromStream(builder, stream, &response, &errs)) {
        NEVONEX_LOG(SeverityLevel::warning)
                << "[CloudDownload] JSON parse failed: " << errs;
        return;
    }
    if (!response.isMember("correlation-id")
            || !response["correlation-id"].isString()) return;

    const std::string cid = response["correlation-id"].asString();

    if (cid.find("HTTP") != std::string::npos) {
        // Pattern A: wake up ExternalApiRoute::handlePost
        ExternalApiRequestManager::getInstance()
                ->notifyResponse(cid, _content);
        return;
    }

    if (cid.find("WS") != std::string::npos) {
        // Pattern B: re-wrap as external_api_response and broadcast
        Json::Value envelope;
        envelope["type"]           = "external_api_response";
        envelope["correlation-id"] = cid;
        envelope["data"]           = response.get("data", Json::Value());

        Json::StreamWriterBuilder wb; wb["indentation"] = "";
        auto ws = ::AppMain::web::WebSocketEndPoint::getInstance();
        if (ws) ws->publishMessage(Json::writeString(wb, envelope));
    }
}
```

> The outgoing UI envelope (`{ type: "external_api_response", ... }`) is
> what the browser-side dispatcher matches on. See the browser dispatch
> skeleton in `seamos-customui-client` → ws-protocol.md.

### Listener registration (in `addCustomUIListener` / lifecycle)

```cpp
void ApplicationMain::addCloudDownloadListener() {
    using namespace ::nevonex::cloud;
    auto *listener = new CloudDownloadListener();
    listener->setMainController(getMainController());
    Cloud::getInstance()->addPropertyChangeListener(listener);
    //                    ↑
    // Cloud is a singleton; treat it as a long-lived global. The listener
    // outlives any single request — it's the demux for ALL cloud responses.
}

void ApplicationMain::addCustomUIListener() {
    // Pattern A — HTTP proxy route
    auto extFactory = std::make_shared<ExternalApiRouteFactory>();
    extFactory->setMainController(getMainController());
    customui::UIWebServiceProvider::getInstance()
            ->registerRoute("/extApi", extFactory);

    // Pattern B — WebSocket route (also handles /publish frames etc.)
    auto ws = WebSocketEndPoint::getInstance();
    ws->setMainController(getMainController());
    customui::UIWebServiceProvider::getInstance()
            ->registerWebsocketRoute("/socket", ws);
}
```

### Common gotchas

- **Register the promise BEFORE calling `uploadData`** in Pattern A. If the
  cloud responds faster than `addPendingRequest` runs, `notifyResponse`
  silently drops the message — there's no parked entry to resolve.
- **`correlation-id` must be unique across BOTH patterns at any moment.**
  The prefix is the dispatch key, but the full id (prefix + epoch) must
  also be unique. `HTTP{ms}` + `WS{ms}` collisions across patterns at the
  same millisecond are theoretically possible — add a counter if you fire
  many requests in tight loops.
- **`Cloud::uploadData(payload, 1)` second arg is importance/priority,
  conventionally fixed at 1.** The Cloud plugin uses it to bucket queued
  outbound traffic; varying it without a deliberate reason is noise.
- **Don't use Pattern A for streaming or long-poll responses.** The 10 s
  timeout fires and the response, when it eventually arrives, becomes an
  orphan that `notifyResponse` drops because `removeRequest` already ran.
  Use Pattern B and let the UI manage its own timeout.
- **Device2Device download/receive looks similar but is a separate channel
  — its `handleMessage` is intentionally left unimplemented in the
  reference projects.** Don't copy the Cloud dispatch logic into the D2D
  listener unless you actually need D2D-driven responses.

## DB Persistence

C++ SQLite 의 working DB 는 `./db/<name>.db` 에 두며 빌드 시 제외된다. 디바이스 영속 DB 는 `disk/<feature>/runtime.db` 와 같이 `disk/<feature>/...` 하위에 위치하며 디바이스 측에서 런타임에 생성/유지한다 — 빌드 산출물(FIF) 에 포함되지 않는다. 앱이 의도적으로 동봉하는 시드 데이터(예: 초기 카탈로그 SQLite dump 또는 JSON) 는 `disk/seed/...` 하위에 두면 allowlist 정책으로 패키징되어 첫 부팅 시 디바이스로 복사된다.

> **Note:** NEVONEX apps run in runc containers with ephemeral filesystems. App updates destroy all container-internal files. Use `FileProvider` to persist DB files to a host-mounted path that survives container restarts.

**Architecture:**
```
[Container — ephemeral]               [Host mount — persistent]
./db/app.db                            /var/trans/featureid/resources/app.db
  ↑ SQLite connects here                ↑ FileProvider::saveToDisk/retrieveFileFromDisk
  ↑ Destroyed on app update              ↑ Survives container restart
```

**SQLite + Poco Data setup:**
```cpp
#include <Poco/Data/Session.h>
#include <Poco/Data/SQLite/Connector.h>

Poco::Data::SQLite::Connector::registerConnector();
Poco::Data::Session session("SQLite", "./db/app.db");
```

**CMake link — required, easy to miss:** The headers above will *parse* without any CMake change, but linking fails with undefined references to `Poco::Data::*` and the SQLite connector unless you add the components and link the targets. A user who follows only the C++ snippets above hits this on the first build. Add to the app's `CMakeLists.txt` (NOT the generated AppMain.cmake — see "Where to put the link" below):

```cmake
find_package(Poco REQUIRED COMPONENTS Data DataSQLite)
target_link_libraries(${APP_TARGET}
    PRIVATE
        Poco::Data
        Poco::DataSQLite
)
```

If the project also uses Boost.Filesystem (e.g. for `restoreFromDisk` / `copy_file`):

```cmake
find_package(Boost REQUIRED COMPONENTS filesystem)
target_link_libraries(${APP_TARGET} PRIVATE Boost::filesystem)
```

**Where to put the link — preserved vs regenerated files:** FD Headless `UPDATE_SDK_APP` (run by the `regen-sdk-app` skill when the FSP changes) regenerates a subset of the project. Putting Poco/Boost link calls in a regenerated file means the next regen wipes them out and the link breaks again.

| File | Lifecycle | Safe to edit? |
|------|-----------|---------------|
| `CMakeLists.txt` (app root) | **Preserved** across `UPDATE_SDK_APP` | ✅ Put `find_package` + `target_link_libraries` here |
| `<APP>App/CMakeLists.txt` (user code module) | **Preserved** | ✅ Same — for module-scoped deps |
| `<APP>_CPP_SDK/.../AppMain.cmake` (generated) | **Regenerated** every UPDATE_SDK_APP | ❌ Edits get overwritten |
| `<APP>_CPP_SDK/.../*.gen.cmake` | **Regenerated** | ❌ |
| `web/`, `db/`, user-authored `.cpp/.hpp` under `<APP>App/src/` | **Preserved** | ✅ |

If you need a link flag visible to the generated AppMain target, attach it to your user module via `PUBLIC` linkage and `target_link_libraries(AppMain PRIVATE <YourUserModule>)` in the preserved root `CMakeLists.txt` — the dependency propagates without touching the generated file.

> See `regen-sdk-app` skill for the full preservation policy. The rule of thumb: anything under `<APP>_CPP_SDK/` is regenerated; anything under `<APP>App/` and the project-root `CMakeLists.txt` is yours.

**FileProvider API (singleton — equivalent to Java FCALFileProvider):**
```cpp
#include <nevonex-fcal-platform/resource/FileProvider.hpp>
// The package name is `nevonex-fcal-platform`, but the C++ namespace is
// `nevonex::resource` (no `::fcal::` segment). This trips people up — the
// header path and the namespace don't share the `fcal` token.
using nevonex::resource::FileProvider;
using nevonex::resource::FilePath;

// Save — overwrite=true is REQUIRED (default is false!)
FileProvider::getInstance().saveToDisk(FilePath("./db/app.db"), true);

// Restore
FilePath restored = FileProvider::getInstance().retrieveFileFromDisk("app.db");

// Get persistent path
FilePath resPath = FileProvider::getInstance().getResourcesFolderPath();
```

> **Namespace gotcha:** the fully-qualified type is `nevonex::resource::FileProvider`. There is **no** `nevonex::fcal::resource::*` — the `fcal` in the package/header name is not mirrored in the namespace. Code that types `nevonex::fcal::resource::FileProvider` fails to compile with "no type named 'fcal' in namespace 'nevonex'".

> **Warning:** C++ `FileProvider::saveToDisk` defaults `overwrite` to `false`. Omitting the second parameter causes an exception on every call after the first. Always pass `true` explicitly.

**DB Lifecycle:**
```cpp
void DatabaseManager::initialize() {
    boost::filesystem::create_directories("./db/");
    restoreFromDisk();              // resources/ → ./db/ if exists
    session = Session("SQLite", "./db/app.db");
    session << "CREATE TABLE IF NOT EXISTS ...", now;
    persistToDisk();                // initial backup
}
```

**Boost.Filesystem version pin (1.73):** The SDK's app-builder image ships **Boost 1.73**, which does **not** have `copy_options::overwrite_existing` (that name landed in 1.74+). On 1.73 the equivalent is `copy_option::overwrite_if_exists` (singular `copy_option`). Don't write either — the portable form is to remove the destination first and then `copy_file`, which works on every Boost version the SDK has shipped:

```cpp
// Portable across Boost 1.73+ — what we recommend
namespace fs = boost::filesystem;
if (fs::exists(dst)) fs::remove(dst);
fs::copy_file(src, dst);

// AVOID — fails to compile on Boost 1.73
fs::copy_file(src, dst, fs::copy_options::overwrite_existing);  // 1.74+ only
fs::copy_file(src, dst, fs::copy_option::overwrite_if_exists);  // 1.73 only — non-portable
```

**restoreFromDisk — same 3 scenarios as Java:**
| Scenario | `./db/` file | `resources/` file | Result |
|----------|-------------|-------------------|--------|
| First install | absent | absent | SQLite creates new DB |
| Normal restart | present | — | Use existing |
| After app update | absent (cleaned) | present | Copy from resources |

**Prepared Statement + Transaction:**
```cpp
session << "INSERT INTO crops VALUES(?, ?)", use(id), use(name), now;

Poco::Data::Transaction tn(session);
session << "UPDATE crops SET name = ? WHERE id = ?", use(name), use(id), now;
tn.commit();
```

> **`use()` parameters must be non-const lvalues.** `Poco::Data::use(T&)` binds by reference and asserts non-const internally (`Binding.h` — `static_assert(!IsConst<T>::VALUE, ...)`). Repository methods that accept `const std::string& name` and forward `name` to `use()` fail to compile with a static_assert error. Two fixes:
>
> ```cpp
> // OPTION A — accept by value (cheap for small types, recommended)
> bool insertCrop(std::string id, std::string name) {
>     session << "INSERT INTO crops VALUES(?, ?)", use(id), use(name), now;
>     return true;
> }
>
> // OPTION B — accept by const ref, copy into a local before binding
> bool insertCrop(const std::string& id, const std::string& name) {
>     std::string idLocal = id;
>     std::string nameLocal = name;
>     session << "INSERT INTO crops VALUES(?, ?)", use(idLocal), use(nameLocal), now;
>     return true;
> }
> ```
>
> The bound variables must outlive the `now` execution, which is why `use()` insists on non-const references — Poco may write back into them for output bindings.

**persistToDisk — call after every CUD operation.**

## Feature Lifecycle + Ignition State

**FeatureManagerListener (same as Java):**
```cpp
void FeatureManagerListener::handleFeatureStart(const std::string &message) {
    NEVONEX_LOG(SeverityLevel::info) << "Feature started: " << message;
    // Initialize resources
}

void FeatureManagerListener::handleFeatureStop(const std::string &message) {
    NEVONEX_LOG(SeverityLevel::info) << "Feature stopping: " << message;
    // Cleanup, flush DB
}
```

**IgnitionStateListener (C++ only):**
```cpp
void IgnitionStateListener::handleIgnitionOn() {
    NEVONEX_LOG(SeverityLevel::info) << "Ignition ON";
}

void IgnitionStateListener::handleIgnitionOff() {
    NEVONEX_LOG(SeverityLevel::info) << "Ignition OFF";
    // Save state, reduce power consumption
}
```
