---
name: upload-app
description: Upload a SeamOS app (.fif) to the SeamOS marketplace. Use this skill whenever the user wants to publish, upload, deploy, or register an app to the marketplace. Triggers on "앱 업로드", "앱 등록", "마켓플레이스에 올려", "upload app", "publish app", "deploy app", "앱 배포". Also use when the user has a .fif file and wants to get it onto the SeamOS marketplace, even if they don't say "upload" explicitly (테스트 버전 게시 포함).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--dry-run]"
---

# Upload App to SeamOS Marketplace

For end-to-end app coordination, follow the shared playbook:
[`vibe-seamos-app-agent.md`](../../shared-references/vibe-seamos-app-agent.md).

Upload a SeamOS app package (.fif) with metadata and assets to the SeamOS marketplace via REST API.

## Prerequisites

Before running this skill, the user's project must have:
1. **At least one workspace marker** at project root (USER_ROOT). One of:
   - `.seamos-workspace.json` with `marketplace.endpointUrl` (written by `setup` for both project and user scope) — **preferred**.
   - `.mcp.json` with `mcpServers.seamos-marketplace.url` (project-scope only — written by `setup` when scope=project).
   - Plugin-registered `mcp-servers.json` (user-scope; v0.7.5+ embeds the dev URL directly — registered automatically on plugin install).
2. `seamos-assets/` directory at project root with the required files.

Authentication is OAuth (PKCE) — the first MCP call triggers a one-time browser login; no API key required. If the user has not yet run `setup`, do that first; do NOT instruct them to hand-author `.mcp.json`.

## Asset Convention

`{project root}` below is **USER_ROOT** — the directory containing the workspace marker (`.seamos-workspace.json` and/or `.mcp.json`). The skill expects files in this structure:

```
{project root}/                <- USER_ROOT (workspace marker present)
├── .seamos-workspace.json     # always written by setup (both scopes)
├── .mcp.json                  # only in project-scope installs
└── seamos-assets/
    ├── config.json            # App metadata (auto-generated on first run)
    ├── mainImage.png          # Main image (required)
    ├── iconImage.png          # Icon image (required)
    ├── screenshots/           # Screenshots (at least 1 required)
    │   ├── screenshot0.png
    │   └── screenshot1.png
    └── builds/                # App packages (at least 1 required)
        └── {feuType}.fif      # e.g., AUTO-IT_RV-C1000.fif (produced by build-fif)
```

## Execution Flow

Performance is critical — minimize user wait time and interaction rounds.

### Step 1: Parallel Initialization (do ALL three in a single turn)

Run these three operations simultaneously:

**A. Get endpoint schema + one-time upload token:**
Call the `create_app` MCP tool (mcp__seamos-marketplace__create_app). This returns:
- the REST endpoint schema (all required/optional parameters)
- `endpoint.authentication.uploadToken` — a 5-minute, one-time-use token (`ut_*`) bound to this user, used as `Authorization: Bearer <token>` on the multipart upload in Step 4
- `endpoint.authentication.uploadTokenExpiresAt` — ISO-8601 expiry

**B. Resolve marketplace base URL (multi-source — A3):**
Use the bundled helper script — it implements the priority order below and prints the base URL (no `/mcp` suffix) on stdout, or exits 64 with an actionable remediation hint:
```bash
bash skills/upload-app/scripts/resolve-marketplace-url.sh "$USER_ROOT"
```
Priority order (first success wins, `/mcp` suffix stripped automatically):
1. `.seamos-workspace.json` → `.marketplace.endpointUrl` (preferred — written by `setup` for both project and user scope; uniform across scope).
2. `.mcp.json` → `.mcpServers["seamos-marketplace"].url` (project-scope fallback). For older 0.7.x stdio templates, the helper also pulls the last URL arg from `args[]`.
3. `CLAUDE_MCP_SEAMOS_URL` env var (legacy fallback — set by Claude Code in some configurations when the plugin's `mcp-servers.json` registers the MCP server at runtime). When the env var is absent but the running session still has `mcp__seamos-marketplace__create_app` registered, Step 1A's `create_app` response itself carries the canonical endpoint — use that and skip file parsing entirely.
4. **None of the above** → helper exits 64 with a remediation hint. Surface it: tell the user to run the `setup` skill first, or `setup --reconfigure` if `.seamos-workspace.json` is stale and missing `marketplace.endpointUrl`. Do **not** ask the user to hand-author `.mcp.json`.

The MCP-level OAuth token is managed by Claude Code automatically; no API key extraction is needed here.

**C. Scan asset directory:**
Scan `seamos-assets/` and categorize found files:
- `config.json` — app metadata configuration
- `mainImage.*` — main image
- `iconImage.*` — icon image  
- `screenshots/screenshot*.*` — screenshots
- `builds/*.fif` — app packages

### Step 2: Validation & Routing

After all three complete, check for issues:

**Hard stop:**
- All four URL discovery sources from Step 1B failed (no `.seamos-workspace.json` with `marketplace.endpointUrl`, no `.mcp.json` with `seamos-marketplace`, no plugin-registered MCP server, no `create_app` response). Tell the user:
  - "Run the `setup` skill first to bootstrap workspace markers and MCP server registration."
  - If they previously ran 0.7.1 setup and the file lacks `marketplace.endpointUrl`: "Run `setup --reconfigure` to migrate."
  - Do NOT ask the user to hand-author `.mcp.json` — `setup` is the supported entry point.

**If `seamos-assets/` directory is missing** → auto-scaffold:
1. Create directory structure: `seamos-assets/`, `seamos-assets/builds/`, `seamos-assets/screenshots/`
2. Generate `seamos-assets/config.json` via Step 3A (live schema or fallback)
3. Show the user:
   ```
   ## seamos-assets 디렉토리 생성 완료

   다음 구조를 자동 생성했습니다:
   seamos-assets/
   ├── config.json        ← 메타데이터 (값을 채워주세요)
   ├── builds/            ← .fif 앱 패키지를 여기에 넣어주세요
   └── screenshots/       ← 스크린샷 이미지를 여기에 넣어주세요

   추가로 프로젝트 루트의 seamos-assets/ 에 다음 파일을 직접 넣어주세요:
   - mainImage.png (메인 이미지, 필수)
   - iconImage.png (아이콘 이미지, 필수)
   - screenshots/ 폴더에 screenshot0.png 등 최소 1개
   - builds/ 폴더에 {feuType}.fif 파일

   파일을 넣고 다시 앱 업로드를 요청해주세요.
   ```
4. **STOP here** — user needs to place files and fill config first.

**If `seamos-assets/` exists but required files are missing:**
- No .fif file in `builds/` → tell user to place their .fif build file
- No mainImage or iconImage → tell user which required image is missing
- No screenshots → tell user at least 1 screenshot is needed

**Routing by config.json status:**
- `config.json` missing → go to Step 3A (Generate from Live Schema)
- `config.json` exists → go to Step 3B (Schema Diff & Validation)

### Step 3A: Generate Config from Live Schema (first-time setup)

When `config.json` doesn't exist yet:

1. **Parse the live schema** from Step 1A's `create_app` response. Extract all fields (both required and optional) from `parameters.request.schema`.
2. **Build config.json dynamically** — for each field in the schema, generate a key with the appropriate default value:
   - `string` → `""`
   - `number` → `0`
   - `boolean` → `false`
   - `array` → `[]` (with one template item if `itemSchema` exists)
   - Nested `itemSchema` → recurse and generate defaults for inner fields
   - **Enum fields** — if a field has enum values, set the default to `""` (empty string). The available options will be listed in the field guide (Step 3A-5) so the user knows what to choose.
   - **Example values from schema** — for non-enum fields, if the schema provides an `example` value, use it as the default. Example: `"email": "sksjsksh22@gmail.com"`, `"feuType": "AUTO-IT_RV-C1000, RCU4-3Q/20, RCU4-3X/10"`. This lets users see the expected format and replace with their own values.
3. **Fallback** — if Step 1A failed (MCP server unreachable), read the static template from `skills/upload-app/references/config-template.json` instead. The fallback template intentionally leaves all enum-typed fields as empty strings (`""`) and arrays as `[]` so it cannot be silently uploaded with placeholder values; consult `references/config-enum-values.md` for the valid values when filling them in.
4. **Write** the generated JSON to `seamos-assets/config.json`
5. **Show field guide** — list each field with its description, type, required/optional status, and enum values (if any) from the schema. Group by required first, then optional. For enum fields, prominently display all valid options (e.g., `categories`: "Options: EASY_WORK, FARM_MANAGEMENT, DEVICE_MANAGEMENT, ENTERTAINMENT, TEST"; `deviceTypes`: "Options: TRACTOR, RICE_TRANSPLANTER, CULTIVATOR, COMBINE, MULTI_CULTIVATOR"; `ownershipType`: "Options: ORGANIZATION, DEVELOPER") so the user can pick the correct value. Always parse enum values from the live schema's `itemSchema.type` / `type` string rather than hardcoding — backend may add or remove options.
6. **STOP here** — do not proceed to upload. The user needs to fill in the config first.

### Step 3B: Schema Diff & Validation

When `config.json` exists:

#### 3B-1. Schema Diff (detect API changes)

Compare the live schema from Step 1A against the existing `config.json`:

- **New fields in schema but missing from config.json** → auto-add them with default values and notify the user:
  ```
  ## config.json 자동 업데이트

  API 스키마에 새로운 필드가 추가되어 config.json에 반영했습니다:
  - {fieldName}: {description} (기본값: {default})

  필요 시 값을 수정해주세요.
  ```
- **Fields in config.json but removed from schema** → warn the user but do NOT delete:
  ```
  ⚠️ 다음 필드가 현재 API 스키마에 없습니다: {fieldNames}
  config.json에서 제거해도 됩니다. (자동 삭제하지 않음)
  ```
- **No diff** → proceed silently.

If the MCP schema was unavailable (Step 1A failed), skip the diff and proceed with validation only.

#### 3B-2. Validate Required Fields

1. Check required fields are present and non-empty (see `references/config-enum-values.md` for the SSOT enum lists):
   - Always required: `info`, `variants`
   - Required when `isForTest=false`: `email`, `phoneNumber`, `categories`, `deviceTypes`, `pricingType`, `countries`, `languages`
   - **`isForTest=true` (TESTING 채널 게시) 인 경우**: backend 가 `email`, `phoneNumber`, `categories`, `deviceTypes`, `pricingType`, `countries`, `languages` 메타데이터를 옵션으로 수용한다 — TESTING 은 published metadata 가 불필요하므로 검증 우회. 자세한 워크플로우는 `shared-references/seamos-test-channel.md` 참조.
   - `categories` must be a non-empty array of enum values (`EASY_WORK | FARM_MANAGEMENT | DEVICE_MANAGEMENT | ENTERTAINMENT | TEST`)
   - `deviceTypes` must be a non-empty array of enum values (`TRACTOR | RICE_TRANSPLANTER | CULTIVATOR | COMBINE | MULTI_CULTIVATOR`)
   - `ownershipType` (optional) must be `ORGANIZATION | DEVELOPER` if present
   - Each item in `info` must have `locale`, `appName`, `shortDescription`, `detailDescription`
   - Each item in `variants` must have `feuType`, `version`, and `info` array (each with `locale`, `title`, `updateDescription`)
   - Authoritative enum values come from Step 1A's live schema (`itemSchema.type` / `type`). The lists above mirror the values observed at the time of writing — if the live schema disagrees, the schema wins and the user should be prompted with the schema's options.
2. Cross-check: each `feuType` in variants should have a matching `.fif` file in `builds/`
3. If validation fails → show which fields are missing/invalid and stop

#### 3B-2a. Legacy `category` field & retired enum migration hint

Two breaking changes have shipped on the marketplace schema. **Do not auto-convert** in either case — surface the guidance and stop, because the user's original intent (which domain(s) the app belongs to, single vs. multi-category) cannot be inferred safely.

**Case 1 — legacy single-string `category`:** if `config.json` has a `category` (string) field, the API still accepts it but marks it `deprecated`. Move to `categories` (array):

```
config.json has legacy `category` (string). API marks it deprecated — use `categories` (array of strings).
Migration: replace  "category": "FARM_MANAGEMENT"  with  "categories": ["FARM_MANAGEMENT"].
No automatic conversion is performed — please update manually and rerun.
```

**Case 2 — retired enum values:** the previous enum set (`AGRICULTURE`, `CONSTRUCTION`, `DRONE`, `DIAGNOSTICS`, `MATERIALS`) is no longer valid. Current values are `EASY_WORK | FARM_MANAGEMENT | DEVICE_MANAGEMENT | ENTERTAINMENT | TEST`. If a retired value is detected in `category` or `categories`, surface this and stop:

```
config.json uses a retired category value: {oldValue}. Current enum: EASY_WORK, FARM_MANAGEMENT, DEVICE_MANAGEMENT, ENTERTAINMENT, TEST.
Closest mapping is a user decision — common renames:
  AGRICULTURE  → FARM_MANAGEMENT (most apps)
  DIAGNOSTICS  → DEVICE_MANAGEMENT
  CONSTRUCTION / DRONE / MATERIALS → no direct successor; pick the best fit.
No automatic conversion is performed — please update manually and rerun.
```

Rationale: the schema change is user-visible (multi-category support, renamed taxonomy). Automatic conversion would silently lose intent — e.g., a `CONSTRUCTION` app has no clean successor, and `AGRICULTURE → FARM_MANAGEMENT` is a guess the user must confirm.

#### 3B-3. Confirm Upload

If validation passes, show summary:

```
## 앱 업로드 준비 완료

### 파일 확인
- 메인 이미지: mainImage.png ✓
- 아이콘: iconImage.png ✓  
- 스크린샷: screenshot0.png, screenshot1.png (2개) ✓
- 앱 패키지: AUTO-IT_RV-C1000.fif ✓

### 메타데이터 (config.json)
- 앱 이름: {info[0].appName}
- 카테고리: {categories | join(", ")}
- 호환 기기 타입: {deviceTypes | join(", ")}
- 가격: {pricingType}
- 기기 (feuType): {variants[0].feuType} v{variants[0].version}
- 이메일: {email}

업로드를 진행할까요?
```

Wait for user confirmation before proceeding.

### Step 4: Build and Execute curl

Assemble the multipart/form-data curl command using the script. Pass the `uploadToken` from Step 1A (preferred). The token is one-time and expires in 5 minutes — call this script promptly after `create_app`.

```bash
bash skills/upload-app/scripts/upload.sh \
  --base-url "{base_url}" \
  --upload-token "{upload_token}" \
  --request '{json_from_config}' \
  --main-image "{path}" \
  --icon-image "{path}" \
  --screenshots "{path1}" "{path2}" \
  --app-file "{feuType}" "{fif_path}"
```

The `--request` JSON is built from config.json fields, mapped to the API schema from Step 1A.

### Step 5: Report Result

- **Success (2xx)**: Show the response body, confirm app was registered
- **Failure**: Show HTTP status + response body, suggest fixes based on common errors:
  - 401: upload token expired, already used, or malformed → call `create_app` again to get a fresh token, then retry within 5 minutes
  - 403: token-to-app scope mismatch (server-side check) — re-run `create_app`
  - 400: Missing required field (show which one)
  - 413: File too large
  - 5xx: Server issue, suggest rerunning the skill (which will fetch a fresh token)

## Important Notes

For shared rules (API key masking, feuType matching, file path conventions), see `skills/shared-references/seamos-common-rules.md`.
For TESTING channel workflow (publish → install → promote), see `skills/shared-references/seamos-test-channel.md`.

**Upload-app specific rules:**
- When generating the config template, use the MCP schema from `create_app` to ensure field names match the API exactly. The template must include ALL fields from the schema — both required and optional — with appropriate default values (empty string for strings, 0 for numbers, false for booleans, empty array for arrays). Users should see every available option upfront so they can fill in what they need without guessing what fields exist.
- The feuType MUST be explicitly specified by the user in config.json. Do NOT guess or derive it from the .fif filename — feuType is a server-registered value (e.g., `AUTO-IT_RV-C1000`) that may not match the filename.
