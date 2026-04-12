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

**FileProvider API (singleton — equivalent to Java FCALFileProvider):**
```cpp
#include <nevonex-fcal-platform/resource/FileProvider.hpp>

// Save — overwrite=true is REQUIRED (default is false!)
FileProvider::getInstance().saveToDisk(FilePath("./db/app.db"), true);

// Restore
FilePath restored = FileProvider::getInstance().retrieveFileFromDisk("app.db");

// Get persistent path
FilePath resPath = FileProvider::getInstance().getResourcesFolderPath();
```

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
