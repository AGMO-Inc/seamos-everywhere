---
name: regen-sdk-app
description: Re-run FD Headless UPDATE_SDK_APP on an existing SeamOS project to refresh the generated SDK/skeleton layer while preserving the user's hand-written app code. Use this skill whenever the user says "SDK 재생성", "APP 재생성", "SDK 업데이트", "skeleton 갱신", "FSP 바뀌었는데 앱에 반영", "인터페이스 바꿨는데 앱", "interface 반영", "regen sdk", "regen app", "re-sync SDK", "UPDATE_SDK_APP", or similar phrasings. Also use when the user has an existing create-project workspace, modified their FSP, and wants the generated SDK + skeleton layer merged into the existing app project WITHOUT losing their custom code. Do NOT use this for uploading a new marketplace version — that is `update-app` (different layer entirely).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--project-name NAME] [--codegen-type JAVA|CPP] [--dry-run]"
---

# Regenerate SDK + APP Skeleton (FD Headless UPDATE_SDK_APP)

Re-runs FD Headless in **UPDATE_SDK_APP** mode against an existing workspace. Bosch's contract: the FSP project is read as-is, and the generated SDK hooks + skeleton wiring are merged into the **existing** app project — your own source files are preserved.

## When to Use This vs. Alternatives

| Scenario | Skill |
|---|---|
| Brand-new project, no workspace yet | `create-project` (Stage 1A + 1B) |
| FSP/interface unchanged, just want a clean app skeleton from scratch | `create-project --resume` (re-runs Stage 1B = GENERATE_SDK_APP — **destroys** local app edits) |
| FSP changed (via regenerated FSP) → merge into existing app project, keep user code | **this skill** (`regen-sdk-app`) |
| Interface JSON itself changed — FSP must be regenerated first | `create-project --force-clean` **then** `regen-sdk-app` |
| Upload a new `.fif` version to the SDM marketplace | `update-app` — wrong layer, different concept |

## Prerequisites

1. **USER_ROOT**: a directory containing `.mcp.json` (discovered by upward traversal from `$PWD`).
2. **Context populated**: `$USER_ROOT/.seamos-context.json` must have `last_project.{name, workspace_path, app_project_name, codegen_type, app_project_path, sdk_app_completed_at}`. This means `create-project` (including Stage 1B) was already executed successfully. If context is missing or stale, tell the user to run `create-project` first.
3. **FSP current**: Whatever is in `<workspace>/<PROJECT>/com.bosch.fsp.<PROJECT>/` is taken as truth. This skill will NOT touch the FSP or re-validate interface JSON. If the user's reason for regen is "I changed interface.json", route them to `create-project --force-clean` first.
4. **Docker**: running with the pinned image `seamos-fd-headless:0.4.2` (or local build / `--image-tag` override).

## Execution Flow

### Step 1: Resolve USER_ROOT + context

```bash
USER_ROOT=$(find_user_root)                  # upward search for .mcp.json
CONTEXT="$USER_ROOT/.seamos-context.json"
```

If either is missing → exit 64 with the corrective command to run.

### Step 2: Derive parameters

Read from context; CLI flags override. Required fields and resolution order:

| Field | Flag | Context key | Fallback |
|---|---|---|---|
| `PROJECT_NAME` | `--project-name` | `last_project.name` | error exit 64 |
| `APP_PROJECT_NAME` | `--app-project-name` | `last_project.app_project_name` | = `PROJECT_NAME` |
| `CODEGEN_TYPE` | `--codegen-type` | `last_project.codegen_type` | `JAVA` |
| `PROCESS_TIMER` | `--process-timer` | `last_project.process_timer` | `1s` |
| `MVN_ARGS` | `--mvn-args` | `last_project.mvn_args` | `""` |
| `APP_PROJECT_PATH` | `--app-project-path` (host path) | `last_project.app_project_path` | error exit 64 |
| `WORKSPACE` | — | `last_project.workspace_path` | error exit 64 |

**Why `APP_PROJECT_PATH` is required without a fallback**: Bosch's UPDATE_SDK_APP needs to know where the existing app project lives. Unlike GENERATE, it cannot infer — the path may have been renamed, and it is the sole difference vs. GENERATE in the config.prop schema (PDF §4).

### Step 3: Write config.prop

Delegate to the shared helper (shared with `create-project` Stage 1B):

```bash
bash ../create-project/scripts/build-config-prop.sh \
  --project-name      "$PROJECT_NAME" \
  --app-project-name  "$APP_PROJECT_NAME" \
  --codegen-type      "$CODEGEN_TYPE" \
  --process-timer     "$PROCESS_TIMER" \
  --mvn-args          "$MVN_ARGS" \
  --app-project-path  "/workspace/$PROJECT_NAME/${PROJECT_NAME}_${APP_PROJECT_NAME}" \
  --output            "$WORKSPACE/_config.prop"
```

The `--app-project-path` flag (optional on the helper) is what flips config.prop from GENERATE format to UPDATE format by adding the `app.project.path=...` line. Always pass the **container-internal** path (`/workspace/...`) — the `-v` mount handles the host mapping.

### Step 4: docker run UPDATE_SDK_APP

Same pattern as Stage 1B, but with `FD_OPERATION=UPDATE_SDK_APP`:

```bash
timeout 600 docker run --rm --platform linux/amd64 \
  -v "$WORKSPACE:/workspace" \
  -e FD_WORKSPACE=/workspace \
  -e FD_OPERATION=UPDATE_SDK_APP \
  -e FD_CONFIG_PROP=/workspace/_config.prop \
  "$IMAGE_TAG" 2>&1 | tee "$WORKSPACE/run-sdk-app-update.log"
```

The entrypoint (`docker/fd-headless/entrypoint.sh`) already branches `GENERATE_SDK_APP|UPDATE_SDK_APP` together, so no image changes are required.

**Success detection**: grep the log for FD's exit markers — `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY` vs. `FD HEADLESS EXECUTION EXITED WITH ERRORS`.

### Step 5: Context upsert on success

Merge-write (preserving all other fields):

```json
{
  "last_project": {
    "operation": "UPDATE_SDK_APP",
    "sdk_app_updated_at": "<ISO-8601 UTC>"
  }
}
```

Rationale for a **new** `sdk_app_updated_at` field (not overwriting `sdk_app_completed_at`): the original Stage 1B completion timestamp remains as the "first generation" marker; each UPDATE_SDK_APP run refreshes only `_updated_at`. This matches the semantics in `shared-references/seamos-context-cache.md` (field ownership: each skill owns its own timestamp).

Use the same `acquire_context_lock` pattern (flock → mkdir fallback → `.tmp` + `mv`) as the rest of the suite to stay concurrency-safe.

### Step 6: Dry-run mode (`--dry-run`)

No docker invocation, no disk mutation. Emit these path variables to stdout (mirrors create-project's convention for the smoke harness):

```
[dry-run] USER_ROOT=...
[dry-run] PROJECT_NAME=...
[dry-run] WORKSPACE=...
[dry-run] FSP_PATH=...
[dry-run] APP_PROJECT_PATH=...            # host path
[dry-run] APP_PROJECT_PATH_CONTAINER=...  # /workspace/... path written into config.prop
[dry-run] CONFIG_PROP=...
[dry-run] CONTEXT_FILE=...
[dry-run] operation=UPDATE_SDK_APP codegen_type=<...>
[dry-run] docker cmd: timeout 600 docker run --rm ... seamos-fd-headless:0.4.2
```

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | UPDATE_SDK_APP succeeded, context updated |
| 1 | FD Headless reported `EXITED WITH ERRORS` (see `run-sdk-app-update.log`) |
| 2 | FD log contained neither success nor failure marker (investigate) |
| 3 | `timeout` fired (600s) |
| 64 | Usage error — missing context, missing `app_project_path`, invalid flags |
| 69 | Docker image unavailable (pull failed and not cached locally) |

## Important Notes

- **This skill refuses to run FSP regeneration**. FSP drift is handled explicitly by `create-project --force-clean` to keep responsibilities clean (single-responsibility per skill). If the user mentions interface changes, surface the two-step recipe instead of silently chaining.
- **Backing up app code**: UPDATE_SDK_APP is supposed to preserve your source, but since we cannot audit Bosch's merge logic, suggest the user commit or snapshot `<WORKSPACE>/<PROJECT>/<PROJECT>_<APP>/` before running — especially on the first use.
- **`build-config-prop.sh` is shared** with `create-project` and lives under `skills/create-project/scripts/`. The only difference: this skill always passes `--app-project-path`; `create-project` Stage 1B never does.
- **Context schema**: see `skills/shared-references/seamos-context-cache.md` — this skill adds `sdk_app_updated_at` (preserves `sdk_app_completed_at`).
- **Shared rules for FD image pinning, `timeout` fallback (`gtimeout`), and Rosetta 2**: see the `Prerequisites` + `ensure_image` sections of `skills/create-project/SKILL.md` — the same invariants apply here.
