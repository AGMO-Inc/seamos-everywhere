# Mode Transition Matrix

This doc expands the 4-row matrix in `init-customui/SKILL.md` into per-transition step lists with pre-state, steps, post-state, and recovery guidance. Each transition below maps directly to the behaviors specified in the design doc sections "init-customui 처리" and "에러 / 가드" — do not deviate.

## Transition 1: `none → vanilla`

Pre-state:
- `.seamos-workspace.json.ui.defaultFramework` is `null` (or absent).
- `.seamos-workspace.json.ui.activeSrcPath` is `null` (or absent).
- Deep `ui/` exists (created by `create-project`); content may be empty (just `index.html` from skeleton) or already user-edited.

Steps:
1. Verify deep `ui/` exists; if absent → exit 64 ("create-project 먼저").
2. If deep `ui/` is empty (only contains `index.html` from skeleton, no user edits), drop `assets/vanilla-readme.md` to `ui/README.md`.
3. Update `.seamos-workspace.json`: `ui.defaultFramework="vanilla"`, `ui.activeSrcPath=<USER_ROOT-relative deep ui path>`.

Post-state:
- Deep `ui/` is the SSOT. Direct edits go to disk.
- No `customui-src/`.

## Transition 2: `none → react`

Pre-state:
- `.seamos-workspace.json.ui.defaultFramework` is `null` (or absent).
- `.seamos-workspace.json.ui.activeSrcPath` is `null` (or absent).
- Deep `ui/` exists (created by `create-project`).
- Network available for clone.

Steps:
1. Verify deep `ui/` exists; if absent → exit 64 ("create-project 먼저").
2. `git clone --depth 1 -b ${ui.react.templateRef} ${ui.react.templateRepo} ${USER_ROOT}/${PROJECT}/customui-src/`.
3. `rm -rf customui-src/.git/`.
4. `(cd customui-src && npm install)` — on failure exit 74; clone is preserved for retry.
5. Auto-patch deploy output path in `customui-src/vite.config.*` or `package.json#scripts.deploy` to point at deep `ui/` (USE relative path from `customui-src/` to deep `ui/`). On pattern miss → emit WARN + manual guide; continue.
6. Drop `assets/seamos-do-not-edit.md` to `${deep_ui}/.seamos-do-not-edit.md`.
7. Append `.gitignore` sentinel block:
   ```
   # BEGIN seamos-init-customui:<PROJECT>
   <PROJECT>/customui-src/dist/
   <PROJECT>/customui-src/node_modules/
   # END seamos-init-customui:<PROJECT>
   ```
8. Update workspace JSON: `ui.defaultFramework="react"`, `ui.activeSrcPath="<PROJECT>/customui-src"`.

Post-state:
- `customui-src/` is the SSOT.
- Deep `ui/` contains build artifacts only (overwritten by `npm run deploy`).
- `.seamos-do-not-edit.md` marker warns agents/users to edit at `customui-src/`.

## Transition 3: `vanilla → react` (`--reset`)

Pre-state: vanilla mode active. User wants to switch to React. **Destructive** — vanilla code in deep `ui/` must be backed up.

Steps:
1. Confirm with user (interactive prompt). In `--non-interactive` mode → exit 64 ("destructive transition requires interactive confirmation").
2. `mv "${deep_ui}" "${deep_ui_parent}/ui.bak.${UTC_ISO_NO_COLONS}"` — backup naming format: `ui.bak.2026-05-06T1203Z` (UTC ISO 8601 with colons removed).
3. `mkdir -p "${deep_ui}"` — empty directory ready for React build artifacts.
4. Run all steps from "Transition 2: none → react" starting at step 2.

Post-state: React mode active. Vanilla code preserved at `ui.bak.{ts}/` for manual recovery.

## Transition 4: `react → vanilla` (`--reset`)

Pre-state: react mode active. User wants vanilla.

Steps:
1. Confirm with user. Non-interactive → exit 64.
2. `mv "${deep_ui}" "${deep_ui_parent}/ui.bak.${UTC_ISO_NO_COLONS}"`.
3. `mkdir -p "${deep_ui}"`.
4. Remove `${deep_ui}/.seamos-do-not-edit.md` (it's now inside the backup; new dir is empty).
5. `rm -rf "${USER_ROOT}/${PROJECT}/customui-src/"`.
6. Update `.gitignore` — remove the matching `# BEGIN seamos-init-customui:<PROJECT>` … `# END` block (sentinel-cleanup). Other gitignore content untouched.
7. Run "Transition 1: none → vanilla" starting at step 2.

Post-state: Vanilla mode active. React build artifacts preserved at `ui.bak.{ts}/` for forensic recovery.

## Backup naming convention

- Format: `ui.bak.${UTC_ISO_NO_COLONS}` where the timestamp is UTC ISO 8601 with all `:` characters removed.
- Example: `ui.bak.2026-05-06T1203Z` (for 2026-05-06 12:03:00 UTC).
- Reason: filesystem-safe across all platforms; sortable; obviously-non-original; UTC avoids local-tz drift in multi-developer setups.

## Recovery guidance

- **Mid-transition crash (e.g., interrupted clone)**: re-run with same args. The script detects `customui-src/` partial state and either resumes (npm install) or exits with guidance.
- **Failed `npm install`**: `customui-src/` clone is preserved. User can `cd customui-src && npm install` manually then proceed.
- **Wrong-mode mistake**: backups at `ui.bak.{ts}/` allow `mv` rollback. Step-by-step:
  1. Stop. Do NOT re-run init-customui.
  2. Inspect `ui.bak.{ts}/` to find the right backup.
  3. Manually `rm -rf ${deep_ui}` (or back up first), then `mv ui.bak.{ts}/ ${deep_ui}` if reverting.
  4. Reset workspace JSON: `jq '.ui.defaultFramework=null | .ui.activeSrcPath=null' .seamos-workspace.json > .tmp && mv .tmp .seamos-workspace.json`.
  5. Re-run `init-customui --ui <correct-mode>`.
