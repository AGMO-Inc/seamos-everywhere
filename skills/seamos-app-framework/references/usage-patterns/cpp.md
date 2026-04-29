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

## DB Persistence

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
