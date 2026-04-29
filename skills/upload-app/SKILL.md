---
name: upload-app
description: Upload a SeamOS app (.fif) to the SeamOS marketplace. Use this skill whenever the user wants to publish, upload, deploy, or register an app to the marketplace. Triggers on "앱 업로드", "앱 등록", "마켓플레이스에 올려", "upload app", "publish app", "deploy app", "앱 배포". Also use when the user has a .fif file and wants to get it onto the SeamOS marketplace, even if they don't say "upload" explicitly.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[--dry-run]"
---

# Upload App to SeamOS Marketplace

Upload a SeamOS app package (.fif) with metadata and assets to the SeamOS marketplace via REST API.

## Prerequisites

Before running this skill, the user's project must have:
1. `.mcp.json` at project root with `seamos-marketplace` server configured (API key with APP_DEPLOY scope)
2. `seamos-assets/` directory at project root with the required files

## Asset Convention

`{project root}` below is **USER_ROOT** — the directory containing `.mcp.json`. The skill expects files in this structure:

```
{project root}/                <- USER_ROOT (directory containing .mcp.json)
├── .mcp.json
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

**A. Get endpoint schema:**
Call the `create_app` MCP tool (mcp__seamos-marketplace__create_app). This returns the REST endpoint schema with all required/optional parameters.

**B. Parse MCP config:**
Read `.mcp.json` from the project root. Extract:
- `url` from `mcpServers.seamos-marketplace.url` — strip the `/mcp` suffix to get the base URL (e.g., `http://localhost:8088`)
- `X-API-Key` from `mcpServers.seamos-marketplace.headers.X-API-Key`

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
- `.mcp.json` missing or no seamos-marketplace config → guide user to create it

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
3. **Fallback** — if Step 1A failed (MCP server unreachable), read the static template from `skills/upload-app/references/config-template.json` instead.
4. **Write** the generated JSON to `seamos-assets/config.json`
5. **Show field guide** — list each field with its description, type, required/optional status, and enum values (if any) from the schema. Group by required first, then optional. For enum fields, prominently display all valid options (e.g., "Options: CONSTRUCTION, AGRICULTURE, DRONE, ENTERTAINMENT, DIAGNOSTICS, MATERIALS") so the user can pick the correct value.
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

1. Check required fields are present and non-empty:
   - `email`, `phoneNumber`, `categories`, `pricingType`, `countries`, `languages`, `info`, `variants`
   - `categories` must be a non-empty array of enum values (`AGRICULTURE | CONSTRUCTION | DRONE | ENTERTAINMENT | DIAGNOSTICS | MATERIALS`)
   - Each item in `info` must have `locale`, `appName`, `shortDescription`, `detailDescription`
   - Each item in `variants` must have `feuType`, `version`, and `info` array (each with `locale`, `title`, `updateDescription`)
2. Cross-check: each `feuType` in variants should have a matching `.fif` file in `builds/`
3. If validation fails → show which fields are missing/invalid and stop

#### 3B-2a. Legacy `category` field migration hint

If the existing `config.json` contains a legacy `category` (string) instead of `categories` (array), **do not auto-convert**. Instead, surface this guidance and stop:

```
config.json has legacy `category` (string). API now expects `categories` (array of strings).
Migration: replace  "category": "AGRICULTURE"  with  "categories": ["AGRICULTURE"].
No automatic conversion is performed — please update manually and rerun.
```

Rationale: the schema change is user-visible (multi-category support). Automatic conversion would silently lose the user's intent if they originally meant multiple domains or a different default.

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
- 가격: {pricingType}
- 기기: {variants[0].feuType} v{variants[0].version}
- 이메일: {email}

업로드를 진행할까요?
```

Wait for user confirmation before proceeding.

### Step 4: Build and Execute curl

Assemble the multipart/form-data curl command using the script:

```bash
bash skills/upload-app/scripts/upload.sh \
  --base-url "{base_url}" \
  --api-key "{api_key}" \
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
  - 401: API key invalid or missing APP_DEPLOY scope
  - 400: Missing required field (show which one)
  - 413: File too large
  - 5xx: Server issue, suggest retrying or checking server status

## Important Notes

For shared rules (API key masking, feuType matching, file path conventions), see `skills/shared-references/seamos-common-rules.md`.

**Upload-app specific rules:**
- When generating the config template, use the MCP schema from `create_app` to ensure field names match the API exactly. The template must include ALL fields from the schema — both required and optional — with appropriate default values (empty string for strings, 0 for numbers, false for booleans, empty array for arrays). Users should see every available option upfront so they can fill in what they need without guessing what fields exist.
- The feuType MUST be explicitly specified by the user in config.json. Do NOT guess or derive it from the .fif filename — feuType is a server-registered value (e.g., `AUTO-IT_RV-C1000`) that may not match the filename.
