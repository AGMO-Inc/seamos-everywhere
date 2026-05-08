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
> Java reference implementation: **`agnote-core`** (`FuelPriceCloudUploadService`,
> `WeatherGetService`, `CloudDownloadListener`, `PendingRequestRegistry`).
> The conventions below are taken from real running code in that project —
> they differ from the C++ reference (`cpp_deploy_test_19`) in several
> places. Where the languages diverge, **trust this section for Java**;
> see `cpp.md` for the C++ contract.

### The indirect-path rule (same as C++)

SeamOS Java apps **do not open external HTTP sockets directly**. Outbound
traffic goes through the Cloud plugin (`com.bosch.nevonex.cloud.impl.Cloud`),
the platform forwards it, and responses come back via a
`CloudDownloadListener`. The platform owns auth, TLS, network policy, and
audit logging — call `HttpClient`/`URLConnection` from app code and you
lose all of that.

### How the C++ patterns map to Java

C++ docs split the work into "Pattern A (sync `POST /extApi`)" and
"Pattern B (async WebSocket)". The Java reference (`agnote-core`) does
**not** ship a `/extApi` route at all. Instead, every external call is a
**plain REST endpoint that triggers a Cloud upload, then either returns
immediately (ack-only) or has the response broadcast over the WebSocket
when it lands**. Two variants emerge:

| Variant | Service shape | Registry use | UI receives via | When to use |
|---------|---------------|--------------|-----------------|-------------|
| **V1. Cloud Upload (ack-only)** | `{Name}CloudUploadService extends BaseRestService`, returns `{status, correlationId, response}` synchronously from `uploadData` | None — UI matches by `correlationId` later | Generic WS broadcast (whatever `CloudDownloadListener` does with the eventual response) | UI is happy with "request accepted, wait for it on the WS" semantics |
| **V2. Trigger + type-routed broadcast** | `{Name}GetService extends BaseRestService`, `register(cid, "{type}")` then upload, returns `{"status":"success"}` immediately | `PendingRequestRegistry.register` / `consume` | `{"type":"EXT-{type}", "data":{parsed}}` frame on the WS | Response needs server-side parsing or domain routing before the UI sees it |

A C++-style **synchronous** `/extApi` route (block the HTTP thread on a
`CompletableFuture` for up to 10 s) is **possible** in Java but not
present in any verified reference. If you need it, mirror the C++ Pattern A
in `cpp.md` and use `CompletableFuture.get(10, TimeUnit.SECONDS)` —
treat it as new ground, not a documented pattern.

### `uploadData` signature (Java)

```java
String result = Cloud.getInstance()
        .uploadData(dataString, priority, ConnectionTypeEnum.WIFI);
//                              ↑          ↑
//   priority 1=High / 2=Medium / 3=Low    ConnectionTypeEnum.{WIFI,SATELLITE}
```

- **Three args, returns `String`** (cloud-side ack/result; not the upstream
  HTTP body — that arrives later via `CloudDownloadListener`).
- **Default priority in `agnote-core` is `2`** (Medium), not `1`. C++ docs
  describe `1` as "fixed by convention" — that came from a different
  project. Pick a deliberate value; `2` is the safe default.
- `ConnectionTypeEnum` lives in `com.bosch.nevonex.common`.
- Throws specific `Cloud{BadRequest,UnAuthorized,AccessDenied,Connection}Exception`
  + `PlatformServiceException`. Catch each — error messages are the only
  way to tell auth failures from network failures.

### Outgoing envelope (the JSON inside `data`)

```json
{
  "correlation-id": "550e8400-e29b-41d4-a716-446655440000",
  "externalUrl":    "https://api.example.com/data",
  "method":         "POST",
  "header":         { "Content-Type": "application/json", "Authorization": "Bearer ..." },
  "msg":            "<request body string>"
}
```

- `correlation-id`: **UUID v4** in `agnote-core` (`UUID.randomUUID().toString()`),
  not `HTTP{ms}` / `WS{ms}` like C++. Don't rely on a prefix to dispatch
  responses — Java uses the registry instead.
- `header` is a JSON object. The service should default `Content-Type:
  application/json` when caller omits it.
- `msg` is typically a string but the reference keeps it as a `JsonElement`
  so structured payloads pass through unchanged.

> **UI envelope keys vs backend envelope keys** — `agnote-core`'s UI sends
> the backend keys (`externalUrl`, `method`, `header`, `msg`) directly and
> the service forwards them verbatim. The `endPoint`/`methodSelect`/
> `reqHeader`/`reqBody` aliases described in `cpp.md` are a different
> project's UI convention, not a Java-side requirement. If you start with
> agnote, keep the keys aligned end-to-end.

### Variant V1 — Cloud Upload service (ack-only)

The whole service is just envelope-build + `uploadData`. The HTTP response
hands the UI a `correlationId` it can match against the eventual WS frame.

```java
public class FuelPriceCloudUploadService extends BaseRestService {

    @Override
    protected Object processService(Request request, Response response) {
        try {
            JsonObject payload = parseBody(request);
            if (payload == null) return errorResponse("Request body is empty");

            // Validate externalUrl + method (POST/GET)
            String externalUrl = requireString(payload, "externalUrl");
            String method = requireString(payload, "method").toUpperCase();
            if (!method.equals("POST") && !method.equals("GET")) {
                return errorResponse("'method' must be POST or GET");
            }

            JsonObject header = payload.has("header") && payload.get("header").isJsonObject()
                    ? payload.get("header").getAsJsonObject() : new JsonObject();
            if (!header.has("Content-Type")) {
                header.addProperty("Content-Type", "application/json");
            }
            JsonElement msg = payload.has("msg") ? payload.get("msg") : new JsonPrimitive("");

            String correlationId = UUID.randomUUID().toString();
            JsonObject envelope = new JsonObject();
            envelope.addProperty("correlation-id", correlationId);
            envelope.addProperty("externalUrl", externalUrl);
            envelope.addProperty("method", method);
            envelope.add("header", header);
            envelope.add("msg", msg);

            int priority = payload.has("priority") ? payload.get("priority").getAsInt() : 2;
            ConnectionTypeEnum conn = payload.has("connectionType")
                    ? ConnectionTypeEnum.get(payload.get("connectionType").getAsString())
                    : ConnectionTypeEnum.WIFI;

            String ack = Cloud.getInstance().uploadData(envelope.toString(), priority, conn);

            JsonObject res = new JsonObject();
            res.addProperty("status", "success");
            res.addProperty("correlationId", correlationId);
            res.addProperty("response", ack);
            return res.toString();

        } catch (CloudBadRequestException e)    { return errorResponse("Cloud bad request: " + e.getMessage()); }
        catch (CloudUnAuthorizedException e)    { return errorResponse("Cloud unauthorized: " + e.getMessage()); }
        catch (CloudAccessDeniedException e)    { return errorResponse("Cloud access denied: " + e.getMessage()); }
        catch (CloudConnectionException e)      { return errorResponse("Cloud connection failed: " + e.getMessage()); }
        catch (PlatformServiceException e)      { return errorResponse("Platform service error: " + e.getMessage()); }
        catch (Exception e)                     { return errorResponse(e.getMessage()); }
    }
}
```

Registered with route prefix `cloud-upload/`:
```java
UIWebServiceProvider.getInstance()
        .registerPostService("cloud-upload/fuel-price", fuelPriceCloudUploadService);
```

### Variant V2 — Trigger + type-routed broadcast

When the listener needs to **parse / transform** the upstream response
(e.g. weather: pick out today's max/min), tag the request with a `type` in
`PendingRequestRegistry`. The listener consumes the type and broadcasts a
domain frame.

```java
public class WeatherGetService extends BaseRestService {

    private static final String BASE_URL =
            "https://api.open-meteo.com/v1/forecast";

    @Override
    protected Object processService(Request request, Response response) {
        String latitude  = requireQuery(request, "latitude");
        String longitude = requireQuery(request, "longitude");

        triggerExternalApiCall(latitude, longitude);

        JsonObject result = new JsonObject();
        result.addProperty("status", "success");
        result.addProperty("message", "Weather request triggered");
        return result.toString();
    }

    private void triggerExternalApiCall(String lat, String lon) {
        String url = BASE_URL + "?latitude=" + lat + "&longitude=" + lon
                + "&current=temperature_2m,weather_code"
                + "&timezone=auto";

        String cid = UUID.randomUUID().toString();
        PendingRequestRegistry.getInstance().register(cid, "weather");
        //                                              ↑
        //  Tag = the type-routing key consumed by CloudDownloadListener.

        JsonObject envelope = new JsonObject();
        envelope.addProperty("correlation-id", cid);
        envelope.addProperty("externalUrl", url);
        envelope.addProperty("method", "GET");
        envelope.add("header", new JsonObject());
        envelope.addProperty("msg", "");

        Cloud.getInstance().uploadData(envelope.toString(), 2, ConnectionTypeEnum.WIFI);
    }
}
```

### `PendingRequestRegistry` — the agnote-core demux table

A small singleton: **correlation-id → type-string**, with a 60 s TTL.
*Not* a `CompletableFuture` map (that would block a thread; agnote
listeners broadcast instead).

```java
public class PendingRequestRegistry {
    private static final PendingRequestRegistry INSTANCE = new PendingRequestRegistry();
    private static final long TTL_MS = 60_000;

    private final ConcurrentHashMap<String, String> pending = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long>   timestamps = new ConcurrentHashMap<>();

    private PendingRequestRegistry() {
        ScheduledExecutorService cleaner = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "PendingRequestRegistry-cleaner");
            t.setDaemon(true);  // don't pin JVM shutdown
            return t;
        });
        cleaner.scheduleAtFixedRate(this::evictExpired, TTL_MS, TTL_MS, TimeUnit.MILLISECONDS);
    }

    public static PendingRequestRegistry getInstance() { return INSTANCE; }

    public void register(String correlationId, String type) {
        pending.put(correlationId, type);
        timestamps.put(correlationId, System.currentTimeMillis());
    }

    /** Returns the type, or null if unknown / expired. Removes the entry. */
    public String consume(String correlationId) {
        timestamps.remove(correlationId);
        return pending.remove(correlationId);
    }

    private void evictExpired() {
        long now = System.currentTimeMillis();
        timestamps.entrySet().removeIf(e -> {
            if (now - e.getValue() > TTL_MS) { pending.remove(e.getKey()); return true; }
            return false;
        });
    }
}
```

### `CloudDownloadListener` — single demux for all responses

The listener is a NEVONEX-generated EMF object. Extend
`AbstractCloudDownloadListener` and override `handleContent` /
`handleFile`; the `propertyChange` glue routes platform events to those
methods. Two non-obvious requirements:

1. **Property names are `CloudMessageReceived` / `CloudFileReceived`** — not
   `"download"`. Wrong name = listener registers but never fires.
2. **Guard with `GracefulFeatureStop`** — the platform fires events even
   during shutdown; processing them races against resource teardown and
   throws spurious errors in the logs.

```java
public class CloudDownloadListener extends AbstractCloudDownloadListener
        implements ICloudDownloadListener, PropertyChangeListener {

    protected void handleFile(String filePath) {
        // optional — Cloud-downloaded files land here
    }

    protected void handleContent(String message) {
        if (GracefulFeatureStop.getInstance().isFeatureStopped()) return;

        try {
            JsonObject json = JsonParser.parseString(message).getAsJsonObject();
            String type = null;
            if (json.has("correlation-id")) {
                type = PendingRequestRegistry.getInstance()
                        .consume(json.get("correlation-id").getAsString());
            }

            if ("weather".equals(type)) {
                JsonObject parsed = parseWeatherResponse(json);
                JsonObject frame = new JsonObject();
                frame.addProperty("type", "EXT-weather");
                frame.add("data", parsed);
                UIWebsocketEndPoint.getInstance().broadcastMessage(frame.toString());
            } else if (looksLikeFuelPriceResponse(message)) {
                // V1 fallback: content-based routing for services that
                // didn't register a type. Save to DB + broadcast.
                JsonObject frame = new JsonObject();
                frame.addProperty("type", "EXT-fuel");
                frame.add("data", JsonParser.parseString(message));
                UIWebsocketEndPoint.getInstance().broadcastMessage(frame.toString());
            } else {
                // Unknown response — pass through raw.
                UIWebsocketEndPoint.getInstance().broadcastMessage(message);
            }
        } catch (Exception e) {
            FCALLogs.getInstance().log.error("broadcast failed: " + e.getMessage());
        }
    }

    @Override
    public void propertyChange(PropertyChangeEvent evt) {
        switch (evt.getPropertyName()) {
            case "CloudMessageReceived": handleContent((String) evt.getNewValue()); break;
            case "CloudFileReceived":    handleFile((String) evt.getNewValue());    break;
            default: /* ignore other Cloud events */
        }
    }
}
```

### Listener registration

`ApplicationMain` exposes a dedicated lifecycle hook for Cloud listeners:

```java
public void addListenersForDownload() {
    CloudDownloadListener listener = new CloudDownloadListener();
    Cloud.getInstance().addPropertyChangeListener(listener);
}

// In ApplicationMain.main():
sa.addCustomUISupport();         // REST + WS routes
sa.addListenersForUserDefinedControls();
sa.addListenersForDownload();    // ← THIS — easy to forget
sa.startProviders();
```

### Response frame on the WebSocket

The browser receives:
```json
{ "type": "EXT-{domain}", "data": { /* parsed by CloudDownloadListener */ } }
```

This **differs from the C++ reference**, which broadcasts
`{"type":"external_api_response","correlation-id":...,"data":...}`. If the
UI is shared across both apps, branch on `type.startsWith("EXT-")` vs
`type === "external_api_response"`. The agnote frame intentionally drops
`correlation-id` because the broadcast is fan-out; UI matches by `type`.

### Common gotchas (Java-specific)

- **`addListenersForDownload()` must run after `initialize(...)` and
  before `startProviders()`.** Off-order = `Cloud.getInstance()` is null
  or events fire before the listener registers.
- **PropertyChange names are case-sensitive strings.** `"cloudmessagereceived"`
  fails silently. Match exactly: `"CloudMessageReceived"`,
  `"CloudFileReceived"`.
- **`PendingRequestRegistry` TTL is 60 s.** Slow upstreams blow past it
  and the response arrives as untyped — listener falls through to the
  passthrough branch, UI sees a raw JSON it can't parse. Either raise the
  TTL with intent, or make the listener tolerate untyped responses
  (agnote does the latter for fuel-price via content sniffing).
- **`uploadData` returns the cloud-side ack, not the upstream body.** The
  upstream body arrives later via the listener. Don't try to parse the
  return value as your API response.
- **Catch each `Cloud*Exception` separately.** Generic `catch (Exception)`
  swallows the auth/network distinction. The reference services all break
  these out into individual catches with distinct error messages.
- **D2D listener stub is intentional** — `Device2DeviceDownloadListener`
  exists but its `handleMessage` is deliberately empty. Don't copy Cloud
  dispatch into it without a real D2D use case.

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
