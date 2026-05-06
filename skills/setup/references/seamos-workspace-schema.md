# `.seamos-workspace.json` schema

## Overview

`.seamos-workspace.json` is the workspace marker file written at USER_ROOT during plugin bootstrap. It records workspace-level configuration (UI default framework, active UI source path, marketplace endpoint) so that downstream skills can resolve a single source of truth without re-prompting the user. It is created and maintained by the `setup` skill, read by `init-customui` and the `seamos-customui-*` skills, and may also be consulted by `create-project` as an additional USER_ROOT marker (alongside `.mcp.json`) for marker discovery.

## Schema reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `schemaVersion` | int | yes | `1` | Schema migration anchor. |
| `createdAt` | string (ISO8601) | yes | — | UTC timestamp of bootstrap. |
| `scope` | enum: `project` \| `user` | yes | — | Plugin install scope (auto-detected). |
| `ui.defaultFramework` | enum: `vanilla` \| `react` \| `null` | no | `null` | Workspace UI default; init-customui uses this when `--ui` is not given. |
| `ui.activeSrcPath` | string (USER_ROOT-relative) \| `null` | no | `null` | **SSOT path for all customui-* skills.** vanilla → deep `ui/`, react → `<PROJECT>/customui-src/`. Updated by `init-customui`. |
| `ui.react.templateRepo` | string (URL) | no | `https://github.com/AGMO-Inc/custom-ui-react-template` | Source of React scaffold. |
| `ui.react.templateRef` | string | no | `main` | Branch / tag / SHA. |
| `marketplace.endpoint` | enum: `dev` \| `local` \| `custom` | yes | `dev` | Logical endpoint name. |
| `marketplace.endpointUrl` | string (URL) | yes | `https://dev.marketplace-api.seamos.io/mcp` | Resolved URL written into `.mcp.json` template. |

## Example

```json
{
  "schemaVersion": 1,
  "createdAt": "2026-05-06T12:00:00Z",
  "scope": "project",
  "ui": {
    "defaultFramework": "vanilla",
    "activeSrcPath": "MyProj/MyProj/MyProj_App/ui",
    "react": {
      "templateRepo": "https://github.com/AGMO-Inc/custom-ui-react-template",
      "templateRef": "main"
    }
  },
  "marketplace": {
    "endpoint": "dev",
    "endpointUrl": "https://dev.marketplace-api.seamos.io/mcp"
  }
}
```

## Migration / version policy

`schemaVersion` bumps only when fields are removed, renamed, or re-typed in an incompatible way (breaking change). Adding optional fields is a non-breaking change and does NOT bump `schemaVersion`. The `setup` skill auto-migrates older schemas when it detects a lower `schemaVersion`; on migration failure it backs up the existing file to `*.bak.{timestamp}` and rewrites a fresh marker at the current schema version.

## Consumed by

| Skill | Fields read | Fields written |
|---|---|---|
| `setup` | (creates / updates all) | all |
| `create-project` | `scope` (advisory) | — |
| `init-customui` | `ui.defaultFramework`, `ui.activeSrcPath`, `ui.react.*` | `ui.defaultFramework`, `ui.activeSrcPath` |
| `seamos-customui-client` | `ui.activeSrcPath` (advisory) | — |
| `seamos-customui-ux` | `ui.activeSrcPath` (advisory) | — |
