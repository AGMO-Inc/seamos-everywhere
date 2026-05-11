# SeamOS Test Channel Workflow

Shared reference describing how SeamOS marketplace separates TESTING and APPROVED release channels, and how publish / install / promotion flows route through that split. Consumed by `update-app`, `upload-app`, and `manage-device-app`.

## 1. Concept

SeamOS marketplace versions live on one of two channels: **APPROVED** (the default channel that any end-user device receives) or **TESTING** (a pre-validation channel intended for developer or organization-internal devices).

- The channel of a given version is decided at publish time by the `isForTest` flag on the `variants[]` entry of the multipart `--request` JSON. `isForTest=true` routes the version to TESTING; `isForTest=false` (or absent) routes it to APPROVED.
- TESTING versions can be published **without** the full `published` metadata block that APPROVED versions require — this is intentional so that internal builds can ship rapidly without finalized release notes / screenshots.
- APPROVED is what every general user pulls down. TESTING exists so the developer or the issuing organization can validate the build on a real device before promoting it to general availability.
- A **prerelease SemVer** (for example `1.0.1-rc1`, `1.0.1-beta.1`, `2.3.0-alpha.2`) is the recommended convention for TESTING versions, but it is **not enforced** by the backend — the channel is determined solely by `isForTest`, not by the SemVer string.

> Related skills: [update-app](../update-app/SKILL.md), [upload-app](../upload-app/SKILL.md), [manage-device-app](../manage-device-app/SKILL.md)

## 2. Publish Flow

Publishing a TESTING build follows the same MCP-then-multipart shape as a normal APPROVED upload, with the channel flag flipped on the variant.

- Call `update_app` (for an existing app) to obtain the multipart endpoint URL and a one-time upload token. `upload-app` / `create_app` follows the equivalent shape for a first-ever release.
- In the multipart `--request` JSON, serialize the target variant with `variants[].isForTest = true`. This is the single source of truth for the channel — there is no separate "publish to test" endpoint.
- Use a prerelease SemVer for the version string by convention (e.g. `1.0.1-rc1`). This makes the channel obvious at a glance in status output and download history, but the backend treats the SemVer as opaque.
- The `update-app` skill's channel-selection sub-step is where the user picks TESTING vs APPROVED; that choice flows directly into the `isForTest` field of the request JSON.

> Related skills: [update-app](../update-app/SKILL.md), [upload-app](../upload-app/SKILL.md)

## 3. Install Flow

Installing onto a device must respect the channel of the target version.

- `get_app_status(appId)` returns each version with its channel status (APPROVED or TESTING). This is the canonical place to enumerate which TESTING builds exist for a given app.
- When the status response shows one or more TESTING versions in addition to APPROVED, surface a channel-selection prompt to the user instead of silently defaulting to APPROVED.
- `install_app_version_on_device(deviceId, appId, version)` supports **both** APPROVED and TESTING versions — pass the exact version string (including any prerelease suffix) to install a TESTING build.
- The older `install_app_on_device` tool only resolves to the latest APPROVED version and **cannot** install a TESTING build. Skills must route through `install_app_version_on_device` whenever the user has selected a TESTING version.
- The `manage-device-app` skill's install branch (Step 4A — channel selection) is responsible for asking the user which channel to install from and dispatching to the correct tool.

> Related skill: [manage-device-app](../manage-device-app/SKILL.md)

## 4. Promotion / Rollback

Once a TESTING build has been validated, promoting it to APPROVED is another `update_app` upload — not a state-change call.

- Re-invoke `update_app` with the same effective SemVer but with the prerelease suffix removed (e.g. `1.0.1-rc1` → `1.0.1`) and `variants[].isForTest = false`. This re-publishes the build on the APPROVED channel.
- To move an existing device from the TESTING version onto the newly-promoted APPROVED version, use either `update_app_on_device` (which targets the latest APPROVED) or `install_app_version_on_device(deviceId, appId, version)` with the clean (non-prerelease) SemVer.
- For rollback, locate the prior APPROVED version in `get_app_status` and re-install it explicitly via `install_app_version_on_device` — there is no implicit "previous version" pointer. Treat rollback as an explicit, version-pinned install.

> Related skills: [update-app](../update-app/SKILL.md), [manage-device-app](../manage-device-app/SKILL.md)
