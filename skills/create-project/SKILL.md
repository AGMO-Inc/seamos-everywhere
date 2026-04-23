---
name: create-project
description: Create a new SeamOS project (FSP + SDK/APP skeleton) via FD Headless. Triggers — "프로젝트 생성", "create project", "앱 생성", "create app", "create-app", "SDK 생성", "create-project", "FSP 생성", "skeleton generate", "SeamOS 프로젝트 만들어".
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "--project-name <NAME> [--skip-sdk-app] [--codegen-type JAVA|CPP] [--interface-json <PATH>] [--force-clean|--resume]"
---

# Create SeamOS Project (FSP + SDK/APP skeleton)

The first step in SeamOS app development. Generates an FSP project and — by default — the SDK / APP skeleton in a single invocation. Pass `--skip-sdk-app` to stop after FSP generation.

UI type is fixed to `"Custom UI"`. Platforms: Windows (WSL2 / Git Bash), Linux, macOS (Apple Silicon included, requires Rosetta 2).

## Agent Preflight (REQUIRED)

Before invoking `create-project.sh`, an LLM agent MUST confirm the following with the user — these are user-owned decisions, not defaults to assume:

1. **`--project-name`** — the project name.
2. **`--codegen-type`** — `JAVA` or `CPP`. The script will exit `64` if this is missing in non-interactive mode. Ask explicitly; do not guess.
3. **Interface JSON source** — whether an existing `<PROJECT>-interface.json` SSOT should be reused, a new file provided via `--interface-json`, or synthesized interactively from offlineDB.

Only proceed to `Bash` invocation once these three are unambiguous.

## Prerequisites

- **Docker Desktop** (macOS/Windows) or Docker Engine (Linux)
- **macOS Apple Silicon users**: Rosetta 2 must be enabled
  ```bash
  softwareupdate --install-rosetta --agree-to-license
  ```
  Docker Desktop → Settings → Features in Development → **Use Rosetta for x86/amd64 emulation** recommended.
- **Windows users**: WSL2 or Git Bash required — PowerShell / cmd alone is not supported (depends on Bash / jq / shasum).
- **Required host tools**: `docker`, `jq`, `shasum` (or `sha256sum`), `timeout` (or macOS `gtimeout` via `brew install coreutils`). `scripts/preflight.sh` blocks execution if any are missing.
- **First run (online)**: `docker pull public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest`. For fully offline environments, use a separate offline bundle (see Important Notes).

## USER_ROOT

All paths referenced by this skill are anchored at `USER_ROOT` — the directory containing `.mcp.json`. The script walks upward from `$PWD` to locate it. If no `.mcp.json` is found, the script exits `64`; set `SEAMOS_ALLOW_PWD_FALLBACK=1` to opt into using `$PWD` as a test-fixture escape hatch.

USER_ROOT hosts:

| Location | Purpose |
|----------|---------|
| `USER_ROOT/<PROJECT_NAME>/` | Workspace (FSP + SDK/APP output) |
| `USER_ROOT/<PROJECT_NAME>-interface.json` | SSOT — user-editable interface definition |
| `USER_ROOT/seamos-assets/` | Build + upload assets (shared across skills) |
| `USER_ROOT/.seamos-context.json` | Shared project context (consumed by build-fif / upload-app / manage-device-app) |

## Asset Convention

### Workspace Layout

- **Default path**: `$USER_ROOT/{PROJECT_NAME}/`
- **Override**: `--workspace <path>` — must be a subdirectory of `USER_ROOT`, not `USER_ROOT` itself.

Layout after success (Stage 1A + 1B + 1C):

```
{USER_ROOT}/
├── .mcp.json
├── .seamos-context.json                 # context handoff
├── {PROJECT_NAME}-interface.json        # SSOT (user-editable)
├── seamos-assets/                       # bootstrapped in Stage 1C if absent
│   ├── builds/                          # consumed by upload-app
│   └── screenshots/
└── {PROJECT_NAME}/                      # workspace (Docker /workspace mount)
    ├── _interface.json                  # FD runtime copy (overwritten by SSOT on conflict)
    ├── _config.prop                     # GENERATE_SDK_APP config
    ├── run.log                          # Stage 1A stdout tee
    ├── run-sdk-app.log                  # Stage 1B stdout tee
    └── {PROJECT_NAME}/                  # FD Eclipse auto depth
        ├── com.bosch.fsp.<name>/        # FSP
        ├── com.bosch.fsp.<name>.gen/    # Java codegen
        └── {PROJECT_NAME}_{APP_PROJECT_NAME}/  # SDK/APP skeleton
```

### Interface JSON (SSOT policy)

`<USER_ROOT>/<PROJECT>-interface.json` is the SSOT (Single Source of Truth). `<WORKSPACE>/_interface.json` is a runtime copy FD reads.

| Scenario | Behavior |
|----------|----------|
| `--interface-json <path>` provided | Copy into SSOT, then copy into workspace |
| SSOT exists, no flag | Workspace is overwritten by SSOT on content mismatch |
| Workspace only (no SSOT) | Workspace promoted to SSOT with stderr warning |
| Neither exists | Claude flow must synthesize interactively before invoking |

`--force-clean` wipes the workspace but **preserves** the SSOT, `seamos-assets/`, and `.seamos-context.json`.

### offlineDB Resolution

`SEAMOS_OFFLINEDB_PATH` env → `skills/create-project/assets/offlineDB.json` (bundle) → `ref/00_HeadlessFD/offlineDB.json` (repo fallback).

### Context Handoff

On successful exit, atomically upserts `last_project` in `$USER_ROOT/.seamos-context.json` via `flock` (with `mkdir`-based fallback when `flock` is unavailable).

```json
{
  "last_project": {
    "name": "<PROJECT_NAME>",
    "workspace_path": "<abs-path>",
    "operation": "GENERATE_SDK_APP",
    "image_tag": "public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest",
    "interface_json_sha256": "<sha256>",
    "created_at": "<ISO-8601 UTC>",
    "fsp_completed_at": "<ISO-8601 UTC>",
    "sdk_app_completed_at": "<ISO-8601 UTC>",
    "app_project_name": "<APP_NAME>",
    "codegen_type": "JAVA",
    "app_project_path": "<USER_ROOT>/<PROJECT>/<PROJECT>/<PROJECT>_<APP_NAME>"
  }
}
```

`fsp_completed_at` and `sdk_app_completed_at` are the two source-of-truth timestamps driving resume behavior. See [`shared-references/seamos-context-cache.md`](../shared-references/seamos-context-cache.md#create-project) for consumers.

### Docker Image

| Field | Value |
|-------|-------|
| Default image | `public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest` |
| Override (flag) | `--image-tag <ref>` |
| Override (env var) | `SEAMOS_FD_IMAGE=<ref>` |
| Local dev build | `--image-tag seamos-fd-headless:dev` |

> Default tag: `:latest` — maintainers push new builds to this tag. For reproducibility, override with `--image-tag` to a specific FD version or `@sha256:...` digest.
> ECR alias: `g0j5z0m9`

## Execution Flow

### Stage 1A — GENERATE_FSP

1. Resolve USER_ROOT via upward `.mcp.json` walk.
2. Interface JSON SSOT resolution (see table above).
3. `validate-interface-json.sh` gate.
4. `docker run -v $USER_ROOT/$PROJECT_NAME:/workspace ... FD_OPERATION=GENERATE_FSP`.
5. Record `fsp_completed_at` in `.seamos-context.json`.

### Stage 1B — GENERATE_SDK_APP (default; skipped with `--skip-sdk-app`)

6. Write `_config.prop` via `build-config-prop.sh`.
7. `docker run ... FD_OPERATION=GENERATE_SDK_APP FD_CONFIG_PROP=/workspace/_config.prop`.
8. Record `sdk_app_completed_at`, `codegen_type`, `app_project_path`, `app_project_name`.

### Stage 1C — seamos-assets/ bootstrap + .gitignore append

9. `mkdir -p $USER_ROOT/seamos-assets/{builds,screenshots}` (idempotent; no-op if present).
10. Append the per-project sentinel block to `$USER_ROOT/.gitignore` (BEGIN/END pair validated; malformed state exits `2` with manual-repair guidance).

## Resume Matrix

Resume behavior is driven by `(workspace-exists, fsp_completed_at, sdk_app_completed_at)`:

| # | Workspace | `fsp_completed_at` | `sdk_app_completed_at` | Action |
|---|-----------|--------------------|------------------------|--------|
| 1 | ✓ | ✓ | ✓ | `[resume] already complete` → exit 0 |
| 2 | ✓ | ✓ | ✗ | Resume Stage 1B (skip 1A) |
| 3 | ✓ | ✗ | — | Stale workspace — error, suggest `--force-clean` |
| 4 | ✗ | ✓ | ✓ | State mismatch — error, suggest `--force-clean` |
| 5 | ✗ | ✓ | ✗ | State mismatch — error, suggest `--force-clean` |
| 6 | ✗ | ✗ | ✗ | Normal fresh run |

`--force-clean` bypasses the matrix entirely (wipes workspace, preserves SSOT / seamos-assets / context).

## `.gitignore` Auto-Management (Policy 1)

On successful Stage 1C, `create-project.sh` appends / replaces a sentinel block to `$USER_ROOT/.gitignore`:

```
# BEGIN seamos-create-project:<PROJECT>
<PROJECT>/_interface.json
<PROJECT>/_config.prop
<PROJECT>/IDT_OFFLINE_DATA/
<PROJECT>/run*.log
<PROJECT>/<PROJECT>/com.bosch.fsp.*/
# END seamos-create-project:<PROJECT>
```

Build artifacts are ignored; user-editable skeleton sources (e.g., `<PROJECT>_<APP>/`) are committable. If the existing `.gitignore` contains malformed sentinel counts (e.g., `BEGIN=2, END=0`), the script exits `2` and asks for manual repair — it does not attempt auto-repair.

## Important Notes

### `--operation` vs `--skip-sdk-app`

`--skip-sdk-app` is the public flag; `--operation` is advanced / hidden. When both are specified, `--operation` wins (with a stderr warning). `--skip-sdk-app` is semantically equivalent to `--operation GENERATE_FSP`.

### Offline (air-gapped) usage

First run requires `docker pull public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest`. For air-gapped usage, transfer an offline bundle built with `docker/fd-headless/scripts/build-offline-bundle.sh`, then `docker load -i`.

```bash
# online host
bash docker/fd-headless/scripts/build-offline-bundle.sh \
  public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest \
  ./dist

# air-gapped host
shasum -a 256 -c seamos-fd-headless-<...>.tar.sha256
docker load -i seamos-fd-headless-<...>.tar
bash skills/create-project/scripts/create-project.sh --project-name <Name> --interface-json <...>
```

### Concurrency

`.seamos-context.json` writes are atomic via `flock` (with a `mkdir`-based lock-directory fallback when `flock` is absent). Running two invocations concurrently on the same workspace is not supported — the state matrix and workspace-exists gate block overlap.

### UI Type

Fixed to `"Custom UI"`.

### Redistribution approval

The Docker image is distributed via AWS Public ECR. `STATUS: APPROVED` in `LEGAL.md` is enforced as a CI blocking gate. When upgrading the FD binary, update `docker/fd-headless/checksums.txt`, `skills/create-project/references/fd-version.json`, and the Binary section of `LEGAL.md` together, then rebuild CI.

### ECR image drift fallback

If the published ECR `:latest` image lags behind repo source (e.g., entrypoint / Dockerfile changes not yet rebuilt via CI), symptoms include:

- Stage 1B fails with "FD_CONFIG_PROP not recognized" or similar → entrypoint is stale.
- JAVA codegen compilation fails inside the container (`javac`/`mvn` missing) → image was built on JRE instead of JDK.

Workaround until maintainer re-triggers `.github/workflows/build-fd-image.yml`:

```bash
# Build locally from current repo source
docker build --platform linux/amd64 \
  -f docker/fd-headless/Dockerfile \
  -t seamos-fd-headless:dev .

# Invoke the skill with the override
bash skills/create-project/scripts/create-project.sh \
  --project-name <Name> \
  --codegen-type JAVA \
  --image-tag seamos-fd-headless:dev
```
