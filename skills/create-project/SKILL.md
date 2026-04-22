---
name: create-project
description: Create a new SeamOS project (FSP) via FD Headless. Triggers: "프로젝트 생성", "create project", "FSP 생성", "skeleton generate", "SeamOS 프로젝트 만들어", "create-project".
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "--project-name <NAME> [--interface-json <PATH>] [--operation GENERATE_FSP] [--workspace <PATH>] [--force-clean] [--resume]"
---

# Create SeamOS Project (FSP)

The first step in SeamOS app development — create a new FSP project using the FD Headless 8.6.0 Docker image. UI type is fixed to "Custom UI". Supported platforms: Windows (WSL2 / Git Bash), Linux, macOS (Apple Silicon included, requires Rosetta 2).

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

## Asset Convention

### Workspace Layout

Project files are isolated under a dedicated **workspace directory**.

- **Default path**: `$REPO_ROOT/create-project-workspace/{PROJECT_NAME}/`
  (`$REPO_ROOT` is the `seamos-everywhere` repo root)
- **Override**: specify an arbitrary path with the `--workspace <path>` flag

> **Warning** — When running the skill from outside the repo directory, always provide `--workspace` explicitly. Without it, the default path is computed relative to the current directory and may pollute the repo tree.

Workspace layout after success:

```
{WORKSPACE}/
├── _interface.json          # Validated interface definition (passed to Docker)
├── run.log                  # FD Headless stdout tee
├── .project                 # FD project metadata
├── .settings/               # FD settings directory
└── *.arxml  |  *.xdm        # Generated FSP files (format depends on operation)
```

### Interface JSON

Resolution rule for the interface definition file passed to Docker:

| Scenario | Behavior |
|----------|----------|
| `--interface-json <path>` provided | Copies specified file to `{WORKSPACE}/_interface.json` and validates |
| Omitted (interactive synthesis) | Synthesized in Step 2 and saved to `{WORKSPACE}/_interface.json` |

Only files that pass `validate-interface-json.sh` are forwarded to the Docker container.

### offlineDB Resolution

During interactive synthesis (Step 2), the `offlineDB.json` element catalog is resolved in the following priority order:

1. Environment variable `SEAMOS_OFFLINEDB_PATH` — absolute or relative path
2. Skill bundle: `skills/create-project/assets/offlineDB.json`
3. Repo copy: `ref/00_HeadlessFD/offlineDB.json` (when running inside the repo)

### Output Artifacts

On successful FSP generation, the following files are created under `{WORKSPACE}/`:

```
{WORKSPACE}/
├── .project                 # FD project metadata
├── .settings/               # FD internal settings
├── <ProjectName>.arxml      # FSP file (AUTOSAR XDM or arxml)
└── run.log                  # Full FD Headless execution log (stdout tee)
```

`run.log` is the primary artifact for determining Step 4 outcome and the first file to check during debugging.

### Context Handoff

On successful exit, atomically upserts the `last_project` field in `$REPO_ROOT/.seamos-context.json` (`flock` + `.tmp` + `mv`).

Updated fields:

```json
{
  "last_project": {
    "name": "<PROJECT_NAME>",
    "workspace": "/absolute/path/to/workspace",
    "operation": "GENERATE_FSP",
    "interface_json_sha256": "<sha256-of-_interface.json>",
    "completed_at": "2025-01-01T00:00:00Z"
  }
}
```

`operation` is one of `GENERATE_FSP` | `GENERATE_SDK_APP` | `UPDATE_SDK_APP`. Downstream skills (`seamos-app-framework`, `build-fif`, `manage-device-app`, etc.) automatically read this file to load project context, so users do not need to re-enter the project path on each invocation.

### Docker Image

| Field | Value |
|-------|-------|
| Default image | `public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest` |
| Override (flag) | `--image-tag <ref>` |
| Override (env var) | `SEAMOS_FD_IMAGE=<ref>` |
| Local dev build | `--image-tag seamos-fd-headless:dev` |

> ECR alias: `g0j5z0m9`

## Execution Flow

### Step 1: Argument parsing & interface JSON branching

User invokes `/create-project --project-name <name> [--interface-json <path>] ...`. If `--interface-json` is **provided**, that file is used as-is (Step 2 skipped). If **omitted**, proceed to Step 2 for interactive synthesis.

### Step 2: Interactive interface JSON synthesis (optional)

If `--interface-json` is absent, Claude synthesizes `<workspace>/_interface.json` interactively with the user following the algorithm in `references/interactive-prompts.md`. See that file for the detailed procedure (element list → interface selection → updateRate configuration → validation).

### Step 3: Run create-project.sh

```bash
bash skills/create-project/scripts/create-project.sh \
  --project-name <name> \
  --interface-json <workspace>/_interface.json \
  --operation GENERATE_FSP \
  --workspace <workspace>
```

Internal script flow:
1. `preflight.sh` detects host tools → aborts immediately on FAIL
2. Aborts if workspace exists (or proceeds with `--force-clean` / `--resume`)
3. Preflight validation of interface JSON via `validate-interface-json.sh`
4. Wraps `docker run` with `TIMEOUT_BIN="$(command -v gtimeout || command -v timeout)"` (600s)
5. Tees stdout to `<workspace>/run.log`

### Step 4: Outcome determination

Grep `run.log` to determine one of: success / failure / unknown / timeout:

- `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY` → exit 0 (success)
- `FD HEADLESS EXECUTION EXITED WITH ERRORS` → exit 1 (FD-reported failure)
- Neither found → exit 2 (unknown)
- `timeout 124` → exit 3 (exceeded 600s)

### Step 5: Update `.seamos-context.json` & handoff guidance

On success, atomically upsert `last_project` field in project root `.seamos-context.json` (flock + `.tmp` + `mv`). Downstream skills (`build-fif`, `manage-device-app`, etc.) reference this value automatically (see `## Important Notes`).

## Important Notes

### Context handoff to downstream skills

`create-project` atomically upserts the `last_project` field in project root `.seamos-context.json` on successful exit. Downstream skills (`build-fif`, `manage-device-app`, and other FD chain skills) reference this value automatically, so users do not need to specify the project path or name on each invocation.

For schema and read examples, see the `## create-project` section in [`shared-references/seamos-context-cache.md`](../shared-references/seamos-context-cache.md#create-project).

To target a different project on re-run, execute again with `--project-name <other>` to update `last_project`.

### Offline (air-gapped) usage

The first run requires online access for `docker pull public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest`. For fully offline/air-gapped environments, transfer a bundle (`.tar` + `.sha256`) built with `docker/fd-headless/scripts/build-offline-bundle.sh`, then load it with `docker load -i`.

Detailed procedure:
```bash
# (online host)
bash docker/fd-headless/scripts/build-offline-bundle.sh \
  public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest \
  ./dist

# (air-gapped host)
shasum -a 256 -c seamos-fd-headless-<...>.tar.sha256
docker load -i seamos-fd-headless-<...>.tar
bash skills/create-project/scripts/create-project.sh --project-name <Name> --interface-json <...>
```

### Concurrency

Running two invocations concurrently with the same project name is not supported. To prevent workspace conflicts, the default behavior is **abort if workspace exists**. If re-running is intentional, specify either `--force-clean` (rm -rf then recreate) or `--resume` (keep existing state).

`.seamos-context.json` writes are guaranteed atomic via `flock` + `.tmp` + `mv`.

### UI Type

This skill always fixes UI Type to `"Custom UI"`. For other UI types (e.g., `"Standard UI"`), use a separate skill or consider the low-level path of running `docker/fd-headless/entrypoint.sh` directly.

### Redistribution approval

The Docker image is distributed via AWS Public ECR, and `STATUS: APPROVED` in `LEGAL.md` is enforced as a CI blocking gate. When upgrading to a new FD binary version, update `docker/fd-headless/checksums.txt`, `skills/create-project/references/fd-version.json`, and the Binary section of `LEGAL.md` together, then rebuild CI.
