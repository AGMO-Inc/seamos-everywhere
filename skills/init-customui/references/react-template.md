# React Template Reference

This doc captures the contract between `init-customui` and the React template repo. Anything `init-customui` assumes about the template's layout or build config goes here. If the template ever diverges, the auto-patch logic must be updated.

## Template repo & ref

- **repo** (default): `https://github.com/AGMO-Inc/custom-ui-react-template`
- **ref** (default): `main` (branch tip; `--depth 1` clone is sufficient).
- Both are configurable via `.seamos-workspace.json.ui.react.{templateRepo, templateRef}` so users can fork and override without modifying the skill.

## Expected layout

Tree (the parts `init-customui` reads or patches):

```
custom-ui-react-template/
├── package.json           # has `scripts.deploy` (or `scripts.build` + post-build copy)
├── vite.config.ts | .js   # has `build.outDir` referencing the deploy target
├── src/                   # user code lives here
├── index.html             # vite entry
├── node_modules/          # created by `npm install` (gitignored)
└── dist/                  # build output (gitignored; copied to deep ui/ on deploy)
```

Notes:
- Template ships with a default `outDir` of `dist/`. After scaffold, `init-customui` patches it (or the deploy script) to point at the project-specific deep `ui/` path.
- `.git/` is removed after clone — `customui-src/` is a regular directory inside the user's project, not a submodule.

## Deploy output path config

Two patterns the template may use; `init-customui` checks both in priority order:

**Pattern A (preferred): `vite.config.ts` / `vite.config.js` — `build.outDir`**
```ts
export default defineConfig({
  build: {
    outDir: 'dist',          // ← patched to relative path of deep ui/
    emptyOutDir: true,
  }
})
```
Auto-patch via `sed`-style substitution on the literal `'dist'` (or `"dist"`) value within `build.outDir`. The replacement is the relative path from `customui-src/` to deep `ui/`, computed as:
```bash
realpath --relative-to="${USER_ROOT}/${PROJECT}/customui-src" "${deep_ui}"
# Typical result: ../${PROJECT}/${app_project_name}/ui
```

**Pattern B (fallback): `package.json#scripts.deploy`**
```json
"scripts": {
  "deploy": "npm run build && cp -r dist/* ../<deep-ui-relative>/"
}
```
If `vite.config.*` does not exist, `init-customui` patches the deploy script's `cp -r dist/*` target.

If neither pattern matches → emit WARN + manual guide (see "Patch failure recovery" below).

## Auto-patch logic

Pseudocode:
```
DEEP_UI_REL=$(realpath --relative-to="${customui_src}" "${deep_ui}")
# macOS bash 3.2 has no realpath --relative-to → use `python3 -c 'import os.path; print(os.path.relpath(...))'` fallback.

if [[ -f customui-src/vite.config.ts || -f customui-src/vite.config.js ]]; then
  # Pattern A
  cfg=$(ls customui-src/vite.config.{ts,js} 2>/dev/null | head -1)
  sed -i.bak -E "s|outDir:[[:space:]]*['\"]dist['\"]|outDir: '${DEEP_UI_REL}'|" "$cfg"
  rm -f "${cfg}.bak"
  echo "[deploy-patch] vite outDir → ${DEEP_UI_REL}"
elif jq -e '.scripts.deploy' customui-src/package.json >/dev/null 2>&1; then
  # Pattern B
  jq --arg dir "${DEEP_UI_REL}" '.scripts.deploy = "npm run build && cp -r dist/* \($dir)/"' \
    customui-src/package.json > /tmp/pkg.json && mv /tmp/pkg.json customui-src/package.json
  echo "[deploy-patch] package.json deploy → ${DEEP_UI_REL}"
else
  echo "WARN: deploy output target not auto-patched — see references/react-template.md 'Patch failure recovery'" >&2
fi
```

## Patch failure recovery

If auto-patch could not find a known pattern, the user must manually:

1. Compute the correct relative path:
   ```bash
   cd customui-src/
   python3 -c "import os.path; print(os.path.relpath('${USER_ROOT}/${PROJECT}/${app_project_name}/ui', '$(pwd)'))"
   # Or substitute the Bash equivalent.
   ```
2. Edit `vite.config.*` and replace the `outDir` literal with the relative path string from step 1.
3. Verify: `npm run build` and confirm files appear in deep `ui/`.

## Out of scope

- **Caching the cloned template** locally (`~/.cache/seamos/ui-templates/`) — deferred until first-clone speed becomes a measured pain point. Design doc explicitly defers this.
- **Vue / Svelte / SolidJS templates** — deferred. Single-template assumption (React + Vite) keeps `init-customui` small. New frameworks would require their own skills or a `--template-type` flag.
- **Forking the template** as a project-side option — not supported. Users can override `templateRepo` to a fork via workspace JSON if needed.
