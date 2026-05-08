# Java Usage Patterns

> App framework patterns for SeamOS Java apps.

## REST API Convention

**URL Convention:**
- No version prefix, kebab-case, plural nouns: `crops`, `machine-models`, `work-logs`
- Path parameters: Spark-style `:id` (e.g., `machines/:id`)
- Sub-actions for state transitions: `/work-logs/start`, `/work-logs/stop`
- Bulk delete: `DELETE /resources/bulk-delete` with body `{"ids":["1","2"]}`

**Service Naming:**

| Action | Pattern | Example |
|--------|---------|---------|
| Create | `{Resource}Service` | `CropService` |
| Read All | `{Resource}GetService` | `CropGetService` |
| Read by ID | `{Resource}GetByIdService` | `MachineGetByIdService` |
| Update | `{Resource}PutService` | `MachinePutService` |
| Delete | `{Resource}DeleteService` | `CropDeleteService` |

**Class Hierarchy:**
```java
NevonexRoute → BaseRestService → {Resource}*Service
```

**BaseRestService pattern:**
```java
public abstract class BaseRestService extends NevonexRoute {
    protected JsonObject parseBody(Request request);      // Gson JSON parsing
    protected String successResponse(String id);          // {"status":"success","id":"..."}
    protected String errorResponse(String message);       // {"status":"error","message":"..."}
    protected void persistDb();                           // FCALFileProvider.saveToDisk after CUD
    protected Connection getDbConnection();               // DatabaseManager singleton
}
```

**Registration (in ApplicationMain.addCustomUISupport()):**
```java
CropService cropService = new CropService();
cropService.setController(controller);
UIWebServiceProvider.getInstance().registerPostService("crops", cropService);
UIWebServiceProvider.getInstance().registerGetService("crops", cropGetService);
UIWebServiceProvider.getInstance().registerDeleteService("crops/bulk-delete", cropDeleteService);
```

**Response format:** Always JSON. Use proper HTTP status codes (200, 400, 404).

**Validation pattern:**
```java
private static final String[] REQUIRED_FIELDS = {"name", "type"};
for (String field : REQUIRED_FIELDS) {
    if (!payload.has(field)) return errorResponse("Missing required field: " + field);
}
```

**ID generation:** `UUID.randomUUID().toString()` (recommended over `System.currentTimeMillis()`)

**Directory convention:** `rest/{resource}/` — Entity, Repository, *Service files

**Example** (Crop Create):
```java
public class CropService extends BaseRestService {
    private static final String[] REQUIRED_FIELDS = {"name"};

    @Override
    public Object processService(Request request, Response response) {
        JsonObject payload = parseBody(request);
        if (payload == null) return errorResponse("Request body is empty");
        // validate, insert via repository, persistDb(), return successResponse(id)
    }
}
```

## WebSocket

```java
@WebSocket
public class UIWebsocketEndPoint extends AbstractWebsocketEndPoint {
    private static UIWebsocketEndPoint instance;
    public static UIWebsocketEndPoint getInstance() { ... }

    @OnWebSocketMessage
    public void message(Session session, String message) {
        // Parse JSON, handle command, send response
    }
}
```

**Registration:**
```java
UIWebServiceProvider.getInstance().openWebsocket("/socket", UIWebsocketEndPoint.getInstance());
```

> Browser-side counterpart (port discovery, frame protocol, cloud proxy):
> see the `seamos-customui-client` skill.

## External API Server Communication

> Authoritative spec: https://docs.seamos.io/docs/4/5/4
>
> The reference implementations are C++ (`external_api_test`,
> `cpp_deploy_test_19`). The architectural rules below apply identically to
> Java — only the type names change. When generating Java code, mirror the
> C++ patterns in `cpp.md` § External API Server Communication and adapt as
> noted here.

### Same indirect-path rule

SeamOS Java apps **do not open external HTTP sockets directly**. Outbound
traffic goes through the Cloud plugin; responses come back via the Cloud
download listener. The platform owns auth, TLS, network policy, and audit
logging.

### Two patterns (same as C++)

| Pattern | UI entry | correlation-id prefix | App waits via | When to use |
|---------|----------|-----------------------|---------------|-------------|
| **A. Sync HTTP proxy** | `POST /extApi` | `HTTP*` | `CompletableFuture<String>` + `get(10, TimeUnit.SECONDS)` | UI expects synchronous return |
| **B. Async WebSocket** | `ws://.../socket` | `WS*` | None — push back over WS | Real-time / concurrent / long ops |

### Java equivalents of the key types

| C++ | Java |
|-----|------|
| `ExternalApiRequestManager` (singleton, `std::map<id, std::promise>`) | Singleton with `ConcurrentHashMap<String, CompletableFuture<String>>` |
| `std::promise<std::string>` / `wait_for` | `CompletableFuture<String>` + `get(10, TimeUnit.SECONDS)` |
| `Json::Value` envelope + `Json::writeString` | `JsonObject` (Gson) + `gson.toJson(...)` |
| `Cloud::getInstance()->uploadData(payload, 1)` | `Cloud.getInstance().uploadData(payloadString, 1)` — second arg is importance/priority, conventionally fixed at 1 |
| `CloudDownloadListener::handleMessage` | `CloudDownloadListener#handleMessage(String)` registered via `Cloud.getInstance().addPropertyChangeListener(...)` |
| `WebSocketEndPoint::onWebSocketMessage` | `@OnWebSocketMessage public void message(...)` on `UIWebsocketEndPoint` |
| HTTP route `ExternalApiRoute` | `BaseRestService` subclass `ExternalApiService`, registered via `UIWebServiceProvider.getInstance().registerPostService("extApi", ...)` |

### Envelope key rename (identical to C++)

```
UI sends            App forwards
─────────           ────────────
endPoint        →   externalUrl
methodSelect    →   method
reqHeader       →   header
reqBody         →   msg
correlation-id  →   correlation-id (generate "HTTP{ms}" or "WS{ms}" if absent)
```

### Pattern A skeleton (Java)

```java
public class ExternalApiRequestManager {
    private static final ExternalApiRequestManager INSTANCE = new ExternalApiRequestManager();
    private final Map<String, CompletableFuture<String>> pending = new ConcurrentHashMap<>();

    public static ExternalApiRequestManager getInstance() { return INSTANCE; }

    public void addPending(String cid, CompletableFuture<String> f) { pending.put(cid, f); }
    public void notifyResponse(String cid, String body) {
        CompletableFuture<String> f = pending.remove(cid);
        if (f != null) f.complete(body);
    }
    public void remove(String cid) { pending.remove(cid); }
}
```

```java
public class ExternalApiService extends BaseRestService {
    @Override
    public Object processService(Request request, Response response) {
        JsonObject ui = parseBody(request);

        CompletableFuture<String> future = new CompletableFuture<>();
        String cid = "HTTP" + System.currentTimeMillis();
        ExternalApiRequestManager.getInstance().addPending(cid, future);

        JsonObject envelope = new JsonObject();
        envelope.addProperty("correlation-id", cid);
        envelope.addProperty("externalUrl", ui.get("endPoint").getAsString());
        envelope.addProperty("method",      ui.get("methodSelect").getAsString());
        envelope.add("header", ui.get("reqHeader"));
        envelope.add("msg",    ui.get("reqBody"));

        Cloud.getInstance().uploadData(new Gson().toJson(envelope), 1);
        //                                                          ↑
        //  Importance (priority). Convention: fixed at 1.

        try {
            response.type("application/json");
            return future.get(10, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            ExternalApiRequestManager.getInstance().remove(cid);
            response.status(504);
            return "{\"status\":504,\"msg\":\"Gateway Timeout: No response.\"}";
        } catch (Exception e) {
            response.status(500);
            return errorResponse(e.getMessage());
        }
    }
}
```

### CloudDownloadListener dispatch (Java)

```java
public class CloudDownloadListener implements PropertyChangeListener {
    @Override
    public void propertyChange(PropertyChangeEvent ev) {
        if (!"download".equals(ev.getPropertyName())) return;
        String content = ev.getNewValue().toString();
        JsonObject root = JsonParser.parseString(content).getAsJsonObject();
        if (!root.has("correlation-id")) return;
        String cid = root.get("correlation-id").getAsString();

        if (cid.startsWith("HTTP")) {
            ExternalApiRequestManager.getInstance().notifyResponse(cid, content);
        } else if (cid.startsWith("WS")) {
            JsonObject envelope = new JsonObject();
            envelope.addProperty("type", "external_api_response");
            envelope.addProperty("correlation-id", cid);
            envelope.add("data", root.get("data"));
            UIWebsocketEndPoint.getInstance().broadcast(new Gson().toJson(envelope));
        }
    }
}
```

Register once in `ApplicationMain.addCustomUISupport()` (or equivalent
lifecycle hook):
```java
Cloud.getInstance().addPropertyChangeListener(new CloudDownloadListener());
UIWebServiceProvider.getInstance().registerPostService("extApi", new ExternalApiService());
UIWebServiceProvider.getInstance().openWebsocket("/socket", UIWebsocketEndPoint.getInstance());
```

### Same gotchas as C++

- **Register the future BEFORE calling `uploadData`** in Pattern A — same
  race window, same silent drop if you reverse the order.
- **`uploadData(payload, 1)`** — second arg is importance, fixed at 1 by
  convention.
- **Pattern A 10 s ceiling** — don't extend beyond ~10 s; switch to
  Pattern B for streaming or long-poll.
- **D2D listener stub is intentional** — the Device2Device channel
  exists but `handleMessage` is deliberately empty in the reference
  projects. Don't copy Cloud dispatch into it unless you have a use case.

## DB Persistence

Java H2 의 working DB 는 `./db/<name>.h2.mv.db` 에 두며 빌드 시 제외된다. 디바이스 영속 DB 는 `disk/<feature>/persist.h2.mv.db` 와 같이 `disk/<feature>/...` 하위에 위치하며 디바이스 측에서 런타임에 생성/유지한다 — 빌드 산출물(FIF) 에 포함되지 않는다. 앱이 의도적으로 동봉하는 시드 데이터(예: 초기 카탈로그 SQL/JSON) 는 `disk/seed/...` 하위에 두면 allowlist 정책으로 패키징되어 첫 부팅 시 디바이스로 복사된다.

> **Note:** NEVONEX apps run in runc containers with ephemeral filesystems. App updates destroy all container-internal files. Use `FCALFileProvider` to persist DB files to a host-mounted path that survives container restarts.

**Architecture:**
```
[Container — ephemeral]               [Host mount — persistent]
./db/appname.mv.db                     /var/trans/featureid/resources/appname.mv.db
  ↑ H2 JDBC connects here               ↑ FCALFileProvider.saveToDisk/retrieveFileFromDisk
  ↑ Destroyed on app update              ↑ Survives container restart
```

**H2 Configuration:**
```java
private static final String DB_URL = "jdbc:h2:./db/{appname};AUTO_SERVER=FALSE;WRITE_DELAY=0";
// WRITE_DELAY=0 is REQUIRED — ensures all changes are flushed before saveToDisk
```

**DB Lifecycle:**
```java
public void initialize() {
    new File("./db/").mkdirs();
    restoreFromDisk();              // resources/ → ./db/ (if exists)
    connection = DriverManager.getConnection(DB_URL);
    createTables();                 // CREATE TABLE IF NOT EXISTS (idempotent)
    persistToDisk();                // initial backup
}
```

**FCALFileProvider API:**
```java
FCALFileProvider.saveToDisk(new File("./db/appname.mv.db"), true);    // overwrite=true REQUIRED
File restored = FCALFileProvider.retrieveFileFromDisk("appname.mv.db");
String path = FCALFileProvider.getResourcesFolderPath();               // host-mounted path
```

**restoreFromDisk — 3 scenarios:**

| Scenario | `./db/` file | `resources/` file | Result |
|----------|-------------|-------------------|--------|
| First install | absent | absent | H2 creates new DB |
| Normal restart | present | — | Use existing, skip restore |
| After app update | absent (cleaned) | present | Copy from resources, restore data |

**persistDb() — call after every CUD operation:**
```java
protected void persistDb() {
    DatabaseManager.getInstance().persistToDisk();
}
```

**Repository pattern:** Pure JDBC PreparedStatement, return JsonObject/JsonArray (Gson).

## Feature Lifecycle

```java
public class FeatureManagerListener extends AbstractFeatureNotification {
    @Override
    public void handleFeatureStart(String message) {
        // Called after feature starts — initialize resources
    }

    @Override
    public void handleFeatureStop(String message) {
        // Called before feature stops — cleanup, flush DB
    }
}
```

**Registration (in ApplicationMain constructor):**
```java
setFeatureManager(new FeatureManagerListener());
```
