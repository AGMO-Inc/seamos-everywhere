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
  - Expected: all 6 fields present: `name`, `workspace_path`, `operation`, `image_tag`, `interface_json_sha256`, `created_at`

- [ ] **11. Offline bundle build verification** — `bash docker/fd-headless/scripts/build-offline-bundle.sh seamos-fd-headless:dev /tmp/offline-test && docker load -i /tmp/offline-test/seamos-fd-headless-*.tar`
  - Expected: tar created + SHA256 check passes + `docker load` succeeds

- [ ] **12. Cleanup** — `docker image prune -f`
  - Expected: unused layers removed, disk space reclaimed

## Notes

- Step order matters (2 → 3 → 4 → 6 → 9).
- If step 4 is skipped on Apple Silicon, note "Apple Silicon: step 4 deferred to CI" in the PR.
- Actual prototype execution is recommended on a Linux amd64 runner or Intel Mac/Linux host.
