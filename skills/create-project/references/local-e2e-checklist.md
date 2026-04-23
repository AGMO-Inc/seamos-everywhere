# Local E2E Checklist — create-project skill

Manual end-to-end verification procedure for developers to perform before merging a PR. **Local only** — not run automatically in CI (due to FD binary licensing and macOS compatibility constraints).

## Prerequisites

- `ref/Linux_HeadlessFD/FD_Headless-linux.gtk.x86_64-*.tar.gz` deployed locally
- Docker Desktop running (macOS Apple Silicon: Rosetta 2 must be enabled)
- Host tools: `docker`, `jq`, `shasum`/`sha256sum`, `timeout`/`gtimeout`

## Checklist

- [ ] **1. Preflight pass** — `bash skills/create-project/scripts/preflight.sh --check-only`
  - Expected: exit 0, multiple `[OK]` lines, no `[FAIL]`

- [ ] **2. Phase A image build** — `docker build --platform linux/amd64 -f docker/fd-headless/Dockerfile -t seamos-fd-headless:dev .`
  - Expected: image size < 500MB, tag `seamos-fd-headless:dev` created

- [ ] **3. Image integrity re-verification** — `(cd ref/Linux_HeadlessFD && shasum -a 256 -c $(pwd)/../../docker/fd-headless/checksums.txt)`
  - Expected: `OK` output

- [ ] **4. Prototype run (on Apple Silicon, defer to CI — this step may be skipped)** — `bash docker/fd-headless/prototype/run-prototype.sh PrototypeProject`
  - Expected (Linux/Intel host): `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY`, artifacts present under `workspace_out/`
  - Apple Silicon host: completion within practical time is not feasible under Rosetta 2 — verify in CI

- [ ] **5. `create-project.sh --help` check** — `bash skills/create-project/scripts/create-project.sh --help`
  - Expected: exit 0, all 8 flags printed to stdout

- [ ] **6. Normal run (dry-run)** — `bash skills/create-project/scripts/create-project.sh --project-name E2ETest --interface-json skills/create-project/references/interface-sample.json --dry-run`
  - Expected: exit 0, `[dry-run]` command printed to stdout

- [ ] **7. Interactive synthesis dry-run** — Run `/create-project --project-name E2EInteractive` via Claude (omit interface-json → interactive synthesis)
  - Expected: Claude follows the `references/interactive-prompts.md` algorithm, prompts for plugin/interface/updateRate, generates `<workspace>/_interface.json`, passes validator, then assembles the final command

- [ ] **8. Validator check** — `bash skills/create-project/scripts/validate-interface-json.sh skills/create-project/references/interface-sample.json ref/00_HeadlessFD/offlineDB.json`
  - Expected: exit 0, `OK (N entries validated)` output

- [ ] **9. Unit tests pass** — `bash skills/create-project/scripts/tests/run_all.sh`
  - Expected: exit 0, `Total: 2 passed, 0 failed`

- [ ] **10. `.seamos-context.json` check** (after a real successful run on Linux/Intel) — `jq .last_project .seamos-context.json`
  - Expected: Stage 1A + 1B fields present — `name`, `workspace_path`, `operation`, `image_tag`, `interface_json_sha256`, `created_at`, `fsp_completed_at`, `sdk_app_completed_at`, `app_project_name`, `codegen_type`, `app_project_path`

- [ ] **11. Offline bundle build verification** — `bash docker/fd-headless/scripts/build-offline-bundle.sh seamos-fd-headless:dev /tmp/offline-test && docker load -i /tmp/offline-test/seamos-fd-headless-*.tar`
  - Expected: tar created + SHA256 check passes + `docker load` succeeds

- [ ] **12. Cleanup** — `docker image prune -f`
  - Expected: unused layers removed, disk space reclaimed

## Unified layout E2E (create-project + build-fif, v4)

Tags: `[docs, test, requires-docker, manual]`. These steps require Docker and a complete FD toolchain. CI agents can run `FAST_CHECK=1` to substitute the Docker-free smoke harness (see **FAST_CHECK** below).

- [ ] **U1. Fresh USER_ROOT fixture** — `mkdir /tmp/seamos-e2e && cd /tmp/seamos-e2e && touch .mcp.json`

- [ ] **U2. Run create-project end-to-end** — `bash <repo>/skills/create-project/scripts/create-project.sh --project-name MyE2E --interface-json <repo>/skills/create-project/references/interface-sample.json --codegen-type JAVA`
  - Expected: Stage 1A + 1B + 1C all succeed. `seamos-assets/` bootstrapped. `.gitignore` sentinel block appended.

- [ ] **U3. Verify context timestamps** — `jq '.last_project.fsp_completed_at, .last_project.sdk_app_completed_at' /tmp/seamos-e2e/.seamos-context.json`
  - Expected: both non-null ISO-8601 UTC timestamps

- [ ] **U4. Build FIF** — `bash <repo>/skills/build-fif/scripts/build-fif.sh /tmp/seamos-e2e`
  - Expected: `/tmp/seamos-e2e/seamos-assets/builds/*.fif` generated

- [ ] **U5. Resume already-complete** — `bash <repo>/skills/create-project/scripts/create-project.sh --project-name MyE2E --resume`
  - Expected: `[resume] already complete` printed, exit 0

- [ ] **U6. Force-clean preserves SSOT and seamos-assets** — `bash <repo>/skills/create-project/scripts/create-project.sh --project-name MyE2E --force-clean --interface-json <...>`
  - Expected: workspace regenerated, `/tmp/seamos-e2e/seamos-assets/` intact, `/tmp/seamos-e2e/MyE2E-interface.json` SSOT still exists

- [ ] **U7. regen-sdk-app refreshes skeleton** (after U2) — touch a file under `<workspace>/<PROJECT>/<PROJECT>_<APP>/src/...` to simulate user edits, then run `cd /tmp/seamos-e2e && bash <repo>/skills/regen-sdk-app/scripts/regen-sdk-app.sh`
  - Expected: UPDATE_SDK_APP completes (`FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY` in `run-sdk-app-update.log`), `.seamos-context.json .last_project.operation == "UPDATE_SDK_APP"`, `sdk_app_updated_at` populated, `sdk_app_completed_at` preserved from U2, user-added file still present

## FAST_CHECK (Docker-free smoke)

Set `FAST_CHECK=1` to skip Docker-dependent steps (U2, U4, U6, U7) and substitute the Docker-free smoke harnesses:

```bash
FAST_CHECK=1 bash <repo>/skills/create-project/evals/smoke.sh
FAST_CHECK=1 bash <repo>/skills/regen-sdk-app/evals/smoke.sh
```

`create-project/evals/smoke.sh` (v4 CIMP-4) verifies create-project + build-fif dry-run emits `USER_ROOT=`, `PROJECT_NAME=`, `WORKSPACE=`, `FSP_PATH=`, `BUILD_DIR=`, `CONTEXT_FILE=`.

`regen-sdk-app/evals/smoke.sh` verifies (A) missing-context errors with exit 64, (B) partial-context enumerates missing fields, (C) full-context dry-run emits all 10 path vars + `FD_OPERATION=UPDATE_SDK_APP`, (D) upward `.mcp.json` search resolves `USER_ROOT` from a nested subdir, (E) `build-config-prop.sh` emits `app.project.path=` only when `--app-project-path` is passed.

## Notes

- Step order matters (2 → 3 → 4 → 6 → 9).
- If step 4 is skipped on Apple Silicon, note "Apple Silicon: step 4 deferred to CI" in the PR.
- Actual prototype execution is recommended on a Linux amd64 runner or Intel Mac/Linux host.
- The unified layout E2E (U1–U6) is the authoritative verification for v0.4.2 refactor changes. Legacy steps 6–10 remain for backward compatibility with earlier skill expectations.
