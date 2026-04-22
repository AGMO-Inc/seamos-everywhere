# Interface Schema

Structure of the interface JSON and catalog JSON accepted as input by FD Headless.

## 1. `offlineDB.json` (interface catalog)

Location: `ref/00_HeadlessFD/offlineDB.json` (~141 KB).

**Top-level keys:**
- `elements` — array of plugin categories
- `enumDetails` — **serialized JSON string** (requires a second `JSON.parse` or `jq 'fromjson'` call). Consumers must perform the secondary parse.

**`elements[i]` structure:**

```json
{
  "name": "CAN_AGMO_SteerMotor",
  "childelements": [ ... ],
  "interfaces": [
    {
      "interfaceName": "Motor_Heartbeat",
      "accessMethod": "...",
      "updateRate": "Adhoc",
      "parent": "CAN_AGMO_SteerMotor"
    }
  ]
}
```

**`updateRate` allowed values:**

- `Adhoc`
- `Adhoc/Cyclic`
- `Cyclic` (expanded to `Cyclic/<N>ms` when a period is specified — e.g., `Cyclic/100ms`)
- `Process`
- `""` (empty string — no special classification)

## 2. `fd_user_selected_interface.json` (skill → FD input)

JSON passed from the skill to FD representing the user-selected interfaces. Top level is an **array**; each element is a branch/config object.

```json
[
  {
    "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat",
    "config": "Adhoc"
  },
  {
    "branch": "CAN_AGMO_SteerMotor/Motor_Request",
    "config": "Process"
  },
  {
    "branch": "Platform_Service/Cloud/Download",
    "config": ""
  },
  {
    "branch": "Implement/Connector/connectorgeometry_x",
    "config": "Cyclic/100ms"
  },
  {
    "branch": "Implement/Connector/connectorgeometry_y",
    "config": "Cyclic/200ms"
  }
]
```

**Field semantics:**

- `branch` — absolute path delimited by `/` through the `elements[].name` → `childelements`/`interfaces` tree in offlineDB. The last token is the `interfaceName`.
- `config` — one of the allowed values from the interface's `updateRate` set. When `Cyclic` is selected, append the period: `Cyclic/<N>ms`.

## 3. `enumDetails` parsing example

Using `jq`:

```bash
# enumDetails is a string, so use fromjson for secondary parse
jq '.enumDetails | fromjson' ref/00_HeadlessFD/offlineDB.json
```

JavaScript/TypeScript:

```js
const db = JSON.parse(fs.readFileSync('offlineDB.json', 'utf8'));
const enumDetails = JSON.parse(db.enumDetails); // secondary parse
```

> **Note**: `enumDetails` is a serialized JSON string. Consumers that need direct structural access must perform the secondary parse themselves.
