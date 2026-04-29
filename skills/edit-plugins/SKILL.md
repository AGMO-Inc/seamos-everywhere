---
name: edit-plugins
description: Add or remove SeamOS plugins (and their interfaces) on an existing SeamOS project, then automatically re-sync the FSP and SDK/skeleton. Walks the user through plugin catalog → interface selection → diff preview → apply, then chains `create-project --regen-fsp-only` and `regen-sdk-app` so the change actually reaches the running app. Use this skill whenever the user wants to change which plugins or interfaces an existing SeamOS project uses — phrasings like "플러그인 추가", "플러그인 제거", "GPS 빼줘", "IMU 넣어줘", "인터페이스 추가", "interface 빼", "edit plugins", "add plugin", "remove plugin", "plugin 바꿔", "plugin config 수정", "interface.json 수정해줘". Trigger generously: any time the user wants to mutate the set of plugins or interfaces on an existing project, this skill is the right entry point — do NOT have the user hand-edit `<PROJECT>-interface.json` and then call regen-sdk-app separately, because skipping FSP regeneration produces a stale skeleton that silently ignores the new branches.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--project-name NAME] [--image-tag TAG] [--dry-run] [--no-regen]"
---

# Edit Plugins on an Existing SeamOS Project

Mutates the plugin/interface set of an existing SeamOS project by editing the SSOT `<USER_ROOT>/<PROJECT>-interface.json`, then **always** re-syncs FSP + SDK + skeleton so the change reaches the actual running app.

This skill replaces a 3-step manual workflow that users get wrong (or stop halfway through):

1. Manually edit `<PROJECT>-interface.json`
2. `create-project --regen-fsp-only` (FSP from new interface, app code preserved)
3. `regen-sdk-app` (merge new SDK hooks into the existing app)

If steps 2-3 are skipped, the change silently does nothing — the running app keeps using the old FSP. **Always chain to regen.** This is the core value of the skill.

## When to Use This vs. Alternatives

| Scenario | Skill |
|---|---|
| Change which plugins/interfaces an **existing** project uses | **this skill (`edit-plugins`)** |
| Brand-new project, decide initial plugins | `create-project` |
| Just refresh SDK from already-current FSP | `regen-sdk-app` |
| FSP-only refresh, no plugin change | `create-project --regen-fsp-only` |
| Upload a new `.fif` to marketplace | `update-app` |

## Prerequisites

1. **USER_ROOT**: directory containing `.mcp.json` (discovered by upward traversal from `$PWD`).
2. **Existing project**: `$USER_ROOT/.seamos-context.json` must have `last_project.{name, workspace_path, app_project_name, codegen_type, app_project_path, sdk_app_completed_at}`. If missing → tell the user to run `create-project` first; do not try to guess.
3. **SSOT**: `$USER_ROOT/<PROJECT>-interface.json` must exist (this is what we mutate). If missing → tell the user the project is in an inconsistent state and to run `create-project --regen-fsp-only` first to materialize it from the workspace.
4. **Catalog access**: needs `skills/seamos-plugins/references/catalog.md` and `detail/{Plugin}.md` (reads only — never writes).

## Execution Flow (LLM Orchestration)

Treat this as a guided dialog. Don't run anything destructive without explicit user confirmation.

### Step 1: Inspect current state

```bash
bash skills/edit-plugins/scripts/edit-plugins.sh inspect
```

Outputs a JSON document on stdout:

```json
{
  "user_root": "/Users/.../proj-root",
  "project_name": "MyProject",
  "ssot_path": "/Users/.../proj-root/MyProject-interface.json",
  "current_entries": [
    {"branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat", "config": "Adhoc"},
    {"branch": "GPSPlugin/InternalGPSInfo", "config": "Cyclic/1000ms"}
  ],
  "current_plugins": ["CAN_AGMO_SteerMotor", "GPSPlugin"]
}
```

If `current_entries` is empty or the SSOT is missing, surface that immediately and stop — do not silently propose a full first-time setup (that's `create-project`'s job).

### Step 2: Show catalog + current state to user

Read `skills/seamos-plugins/references/catalog.md`. Render a compact table that **marks which plugins are currently in use** based on `current_plugins`. Example:

```
Plugin                       In use   Direction      Description
─────────────────────────────────────────────────────────────────────
CAN_AGMO_SteerMotor          ✓        8 In / 1 Out   Steering motor
GPSPlugin                    ✓        4 In / 1 Out   Internal GPS
IMU                                   4 In           Internal IMU
Platform_Service                      8 Methods      Cloud / D2D
...
```

Then ask the user concretely:

> "어떤 plugin 을 추가하거나 제거하시겠어요? (예: 'IMU 추가', 'GPSPlugin 제거', 'IMU 추가하고 SteerMotor 빼줘')"

A single invocation can do both adds and removes — collect everything before moving on.

### Step 3: For each plugin to ADD — pick interfaces

For each plugin the user wants to add, read `skills/seamos-plugins/references/detail/{Plugin}.md`. Show the interface table and ask which interfaces they want. For `In` (Subscribe) interfaces, ask the operation mode:

- **Cyclic** — periodic. Need a period (`Cyclic/1000ms`, `Cyclic/100ms`, etc.). Default to the cycle column from the detail file when present.
- **Adhoc** — event-driven, no period.
- **Both** — `Adhoc/Cyclic` (rare, only if explicitly asked).

For `Out` interfaces, the config is always `Process` (don't ask — fixed by spec).

For `Platform_Service` methods, the config is `""` (empty string).

**Important — large catalogs**: `ISOPGN` (140 signals) and `Implement` (634 signals) are too big to dump in one go. If the user picks one of these, ask which signal **categories** or specific signal names they need first, then `Grep` the detail file for matching rows only. Never paste the whole file into the conversation.

### Step 4: For each plugin to REMOVE — confirm scope

For removal, ask the user whether they want to remove **all** entries for that plugin or just a subset:

> "GPSPlugin 의 어떤 인터페이스를 제거할까요? (a) 전부, (b) 일부 — 일부면 어떤 것?"

Default to "all" if the user said "GPSPlugin 빼줘" without naming interfaces.

### Step 5: Compose patch + show diff

Build a JSON patch file describing the operations:

```json
{
  "add": [
    {"branch": "IMU/InternalIMUInfo", "config": "Cyclic/100ms"},
    {"branch": "IMU/InternalIMUStatus", "config": "Adhoc"}
  ],
  "remove": [
    {"branch": "GPSPlugin/InternalGPSInfo"},
    {"branch": "GPSPlugin/InternalGPSStatus"}
  ]
}
```

Save it to a temp file, then run:

```bash
bash skills/edit-plugins/scripts/edit-plugins.sh apply --patch <patch.json> --dry-run
```

The `--dry-run` mode validates the patch against `offlineDB.json`, prints the unified diff that **would** be applied to the SSOT, and prints the planned regen command sequence. **Show this diff to the user verbatim.**

### Step 6: Ask about `.gen.tests/`

After plugin/interface changes, the test simulator scaffold (`com.bosch.fsp.<PROJECT>.gen.tests/`) under the workspace still references the old providers. Ask the user:

> "인터페이스가 바뀌었으니 테스트 시뮬레이터 스캐폴드(`.gen.tests/`)도 새 인터페이스에 맞춰 다시 만들까요? (Y = `--reset-tests` 적용 / N = 그대로 유지 — 새 인터페이스는 시뮬레이터에서 안 보입니다)"

Default = ask, never decide silently. Pass-through to `regen-sdk-app --reset-tests` if user agrees.

### Step 7: Final confirmation + apply

Get explicit user confirmation, then run:

```bash
bash skills/edit-plugins/scripts/edit-plugins.sh apply \
  --patch <patch.json> \
  [--reset-tests]
```

The `apply` subcommand does, in order:

1. Acquire context lock (flock → mkdir fallback)
2. Backup SSOT to `<PROJECT>-interface.json.bak.<UTC-ISO>`
3. Apply add/remove operations to the SSOT (jq-based, deterministic)
4. Re-validate the result against `offlineDB.json` via `validate-interface-json.sh`
5. **`create-project --regen-fsp-only --project-name <NAME>`** — regenerates FSP from the new SSOT, preserves app code
6. **`regen-sdk-app [--reset-tests]`** — merges new SDK hooks into the existing app project
7. On any failure during steps 5-6: restore SSOT from backup, surface the error, exit non-zero

**These regen steps are not optional.** Skipping them leaves the running app on the old FSP, which is the bug this skill exists to prevent. Do not add a `--no-regen` shortcut for end users; the flag exists only for the test harness to isolate the JSON-edit logic.

### Step 8: Report what changed

After successful regen, print a compact summary:

```
✓ Added: IMU/InternalIMUInfo (Cyclic/100ms), IMU/InternalIMUStatus (Adhoc)
✓ Removed: GPSPlugin/InternalGPSInfo, GPSPlugin/InternalGPSStatus
✓ FSP regenerated: com.bosch.fsp.MyProject/
✓ SDK skeleton merged: MyProject_App/ (your hand-written code preserved)
✓ Test simulator scaffold reset: .gen.tests/  (or "kept as-is" if --reset-tests was declined)

Backup: MyProject-interface.json.bak.2026-04-30T12-34-56Z
```

If the user wants to roll back, point them at the backup file and tell them to re-run with the inverse patch (or copy the backup back over the SSOT and run `create-project --regen-fsp-only && regen-sdk-app`).

## Patch Schema (for reference)

```json
{
  "add":    [ { "branch": "<plugin>/<path>/<interface>", "config": "<config>" } ],
  "remove": [ { "branch": "<plugin>/<path>/<interface>" } ]
}
```

- `branch` matches the offlineDB element/interface name path. Validated at apply time.
- `config` follows the existing SSOT vocabulary: `""`, `"Adhoc"`, `"Adhoc/Cyclic"`, `"Cyclic"`, `"Cyclic/<N>ms"`, `"Process"`. Anything else fails validation.
- `remove.branch` does an exact-string match against existing entries. If a branch is in `remove` but not in the current SSOT, it's a soft warning (printed to stderr) — not a hard failure, since the user's intent ("make sure this is gone") is still satisfied.
- A branch appearing in both `add` and `remove` is rejected at validation time (exit 64) — pick one.

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Patch applied + regen succeeded |
| 1 | Regen failure (FSP or SDK_APP); SSOT restored from backup |
| 2 | Validation failure (unknown branch, invalid config, contradictory patch) |
| 3 | `timeout` fired during a docker step |
| 64 | Usage error — missing context, missing SSOT, malformed patch JSON |
| 69 | Docker image unavailable |

## Important Notes

- **Never `--force-clean`.** This skill must never call `create-project --force-clean` — that wipes the user's hand-written app code under `<PROJECT>/<PROJECT>_<APP>/`. The standard path is `--regen-fsp-only` followed by `regen-sdk-app`, which preserves user code by design. The repo memory note `feedback_no_user_code_destruction.md` calls this out specifically.
- **Backup is non-negotiable.** Even though the JSON edit is deterministic and reversible, an unexpected jq error or a partially-written file would otherwise corrupt the SSOT. Always write the backup before mutating.
- **Don't auto-decide `--reset-tests`.** It deletes `.gen.tests/`. If the user wrote any test code there, it would be lost. Ask, then pass through.
- **Concurrency**: `.seamos-context.json` is shared with create-project / regen-sdk-app. Use the same lock helper they use (`acquire_context_lock`). Concurrent edit-plugins runs against the same project are not supported.
- **Don't expand to UI port / codegen / app-name changes.** Those belong to `create-project` flags; this skill is only the plugin/interface set. Keep scope tight.
- **`--image-tag` flows through both regens.** When the user's environment doesn't have `seamos-fd-headless:latest` locally (e.g., they only have the public ECR full path), pass `--image-tag <ref>` (or set `SEAMOS_FD_IMAGE`); the script forwards it to both `create-project --regen-fsp-only` and `regen-sdk-app` so the chained regens stay on the same image. Without this, the SDK regen step can default to a missing tag and silently produce a no-op result while the FSP regen succeeds — leaving the app project stale.
- **Bosch FD limitation: missing `customui/` → SDK no-op.** `UPDATE_SDK_APP` returns success but performs no SDK merge when the app project lacks a `customui/` folder. This is the default state of a freshly generated CPP project that hasn't had any user UI code added yet. Symptom: the FD log contains `SEVERE: App project does not contain the custom ui folder`, FSP regen is fine, but `<APP>_CPP_SDK/src-gen/nevonex/<removed-plugin>/` files remain — the build keeps referencing dead plugins. The skill detects this marker after apply and prints a WARNING. Mitigation: if the project hasn't had real user code yet, the cleanest fix is `create-project` from scratch with the new interface set; otherwise, manually clean stale `src-gen` subdirs matching removed plugin names. This is a Bosch-side bug that should be raised upstream — not something the skill can fix.
- **Two huge plugins**: `ISOPGN` (140) and `Implement` (634). Always Grep the detail file for the user's specific signal of interest rather than dumping the table. The user almost never wants "all of ISOPGN".
- **Empty result guard**: if after applying the patch the SSOT becomes an empty array, refuse to proceed (exit 2). An app with zero interfaces is almost certainly a mistake.

## Shared Components

- **Patch apply (jq)**: `scripts/edit-plugins.sh` (this skill)
- **Validate interface.json**: `skills/create-project/scripts/validate-interface-json.sh` (shared)
- **Regen FSP**: `skills/create-project/scripts/create-project.sh --regen-fsp-only` (shared)
- **Regen SDK skeleton**: `skills/regen-sdk-app/scripts/regen-sdk-app.sh` (shared)
- **Catalog data**: `skills/seamos-plugins/references/catalog.md` + `detail/*.md` (read-only)
- **offlineDB.json**: resolved via `SEAMOS_OFFLINEDB_PATH` env → `skills/create-project/assets/offlineDB.json` → `ref/00_HeadlessFD/offlineDB.json`

## Test Harness Flag (`--no-regen`)

For end-to-end tests it's useful to isolate the JSON-edit logic. The `--no-regen` flag on `apply` skips steps 5-6 (FSP + SDK_APP regen) so a test can assert on the resulting SSOT without spinning up Docker. **This flag is for the test harness only — do not surface it to users.** A real user who skips regen has no way to see their changes take effect, which is exactly the failure mode this skill was created to prevent.
