# Interactive Interface JSON Synthesis

Algorithm Claude uses to synthesize `fd_user_selected_interface.json` interactively with the user, based on `offlineDB.json`, when the user has not provided `--interface-json`.

## Preconditions

- `offlineDB.json` catalog file must be accessible from one of the following sources (in priority order):
  1. **Environment variable** `SEAMOS_OFFLINEDB_PATH` — specify as an absolute path (highest priority)
  2. **Skill bundle** `skills/create-project/assets/offlineDB.json` — bundled file shipped with the skill
  3. **Repo local** `ref/00_HeadlessFD/offlineDB.json` — fallback when running inside the seamos-everywhere repo
- User workspace path (`<workspace>`) must already be determined
- Final artifact: `<workspace>/_interface.json` (fd_user_selected_interface format)

## Algorithm

### Step 1: Load catalog

Determine the `offlineDB.json` path using the priority order above, then Read it. The top level has `elements` (array) and `enumDetails` (string).

### Step 1a: Secondary parse of `enumDetails`

`enumDetails` is a **serialized JSON string**. Parse it a second time if structured enum candidates are needed:

```bash
jq '.enumDetails | fromjson' offlineDB.json
```

Or directly in Claude:

```js
JSON.parse(db.enumDetails)
```

This step is only needed when config options (e.g., `Cyclic` periods) are defined as enums. Not required in the default synthesis path.

### Step 2: Present element list

Present `elements[].name` to the user with numbered items:

```
Please select one of the following plugin categories:
  1. CAN_AGMO_SteerMotor
  2. Platform_Service
  3. Implement
  4. ...
```

Wait until the user selects a number (or name).

### Step 3: Expand selected element's interfaces

Present the selected element's `interfaces[]` with numbered items. If `childelements` exist, traverse recursively to include child interfaces as well.

```
Interfaces under CAN_AGMO_SteerMotor:
  1. Motor_Heartbeat (updateRate: Adhoc)
  2. Motor_Request   (updateRate: Process)
```

Wait for the user to select a number. Multiple selections are allowed (`1, 2, 3` or `all`).

### Step 4: Configure updateRate

For each selected interface, present `updateRate` candidates. Based on the interface's `updateRate` field value:

- `Adhoc` → auto-adopt (`config = "Adhoc"`)
- `Process` → auto-adopt
- `Cyclic` or `Adhoc/Cyclic` → **ask for period (ms)**:
  ```
  Enter the Cyclic period for Motor_Request in ms (e.g. 100): _
  ```
  User input `100` → `config = "Cyclic/100ms"`
- `""` (empty) → auto-adopt (`config = ""`)

### Step 5: Serialize selections

Serialize the confirmed list as an array in `fd_user_selected_interface.json` format:

```json
[
  { "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat", "config": "Adhoc" },
  { "branch": "CAN_AGMO_SteerMotor/Motor_Request",   "config": "Process" },
  { "branch": "Implement/Connector/connectorgeometry_x", "config": "Cyclic/100ms" }
]
```

### Step 6: Save to workspace

Save to `<workspace>/_interface.json` using the `Write` tool. Notify the user of the saved path.

### Step 7: Self-validate

Validate the synthesized JSON with `validate-interface-json.sh`. If the `offlineDB.json` argument is omitted, the script auto-resolves it using the priority order (env > bundle > repo):

```bash
# Auto-resolve offlineDB.json (env > bundle > repo)
bash skills/create-project/scripts/validate-interface-json.sh <workspace>/_interface.json

# Or with explicit path
bash skills/create-project/scripts/validate-interface-json.sh <workspace>/_interface.json <offlineDB.json>
```

- exit 0 → proceed to next step (invoke create-project.sh)
- exit 1 → show failed entries listed in stderr to the user and **request re-selection** (return to Step 2)

## User-facing message templates

### Initial guidance
```
No interface JSON was specified. Starting interactive synthesis. Please make selections from the list below.
```

### Re-selection on error
```
Validation errors found in selected entries:
  - {failed_entry_line}
Please re-select a number to exclude or replace the affected entry.
```

### Completion notice
```
interface JSON has been saved to <workspace>/_interface.json.
Now running create-project.sh...
```

## Example final JSON

```json
[
  { "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat", "config": "Adhoc" },
  { "branch": "CAN_AGMO_SteerMotor/Motor_Request", "config": "Process" },
  { "branch": "Implement/Connector/connectorgeometry_x", "config": "Cyclic/100ms" },
  { "branch": "Platform_Service/Cloud/Download", "config": "" }
]
```

Valid JSON array; each entry is a `branch`/`config` object.
