---
name: update-app
description: Upload a new version of an existing SeamOS app to the SDM marketplace. Use this skill whenever the user wants to update, upgrade, or push a new version of their app. Triggers on "앱 업데이트", "버전 업데이트", "새 버전 올려", "update app", "new version", "버전 업로드", "앱 버전". Also use when the user mentions updating a .fif file for an app that already exists on the marketplace, or wants to deploy a patch/update to a released app.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[appId] [--dry-run]"
---

# Update App Version on SDM Marketplace

Upload a new version (.fif) of an existing app to the SDM marketplace. Unlike `upload-app` (which creates a brand-new app with full metadata and images), this skill only requires variant info and the app package file.

This skill does NOT use config.json. All version info is collected interactively from the user, one question at a time.

## When to Use This vs upload-app

| Scenario | Skill |
|---|---|
| First time publishing an app | `upload-app` |
| Pushing a new version of an already-published app | **this skill** (`update-app`) |

## Prerequisites

1. `.mcp.json` at project root with `sdm-marketplace` server configured (API key with APP_DEPLOY scope)
2. The app must already exist on the marketplace (use `upload-app` first)
3. A `.fif` app package in `seamos-assets/builds/`

## Context Caching

This skill uses `.seamos-context.json` for app selection caching. For cache structure and shared ownership rules, see `skills/shared-references/seamos-context-cache.md`.

This skill only reads/writes `appId`, `appName`, and `updatedAt` — it preserves `deviceId` and `deviceName` if already present.

## Execution Flow

### Step 1: Parallel Initialization (do ALL in a single turn)

**A. Parse MCP config:**
Read `.mcp.json` from project root. Extract:
- `url` from `mcpServers.sdm-marketplace.url` — strip `/mcp` suffix to get base URL (e.g., `http://localhost:8088`)
- `X-API-Key` from `mcpServers.sdm-marketplace.headers.X-API-Key`

**B. List user's apps:**
Call `list_apps` MCP tool (`mcp__sdm-marketplace__list_apps`). This returns two groups:
- `personalApps` — apps owned by the user directly
- `organizationApps` — apps belonging to the user's organization (may be empty if user has no org)

Each entry has `appId`, `appName`, and `status`.

**C. Scan builds directory:**
Scan `seamos-assets/builds/` for `.fif` files.

### Step 2: App Selection & Status

After initialization completes:

**Hard stops (check first):**
- `.mcp.json` missing or no sdm-marketplace config → guide user to create it
- No `.fif` files in `seamos-assets/builds/` → tell user to place their build file

#### 2-1. Select App

**Cache check:** Before presenting the app list, read `.seamos-context.json` from the workspace root. If the file exists and contains `appId`:

1. Verify the cached appId exists in the `list_apps` result from Step 1B
2. If found → show confirmation prompt:
   ```
   이전에 사용한 앱: {appName} (ID: {appId}) — 이대로 진행할까요? (Y/다른 앱 선택)
   ```
   - User confirms → use cached appId, proceed to Step 2-2 (fetch app status)
   - User declines → proceed with full app list below
3. If not found in list → ignore cache, proceed with full app list below

**If the user provided an appId** (via argument or in their message) → use it directly.

**If not** → present the app list from Step 1B, grouped by ownership:

```
## 업데이트할 앱을 선택해주세요

### 내 앱
| # | App ID | 이름 | 상태 |
|---|--------|------|------|
| 1 | 10250  | Test App | RELEASED |
| 2 | 10249  | 스킬 테스트 | RELEASED |

### 조직 앱
| # | App ID | 이름 | 상태 |
|---|--------|------|------|
| 3 | 10252  | 스킬테스트3 | RELEASED |
| 4 | 150    | AGMO Solution | RELEASED |

번호 또는 App ID를 입력해주세요.
```

If `organizationApps` is empty, skip the "조직 앱" section entirely and only show "내 앱". Number the rows sequentially across both sections so the user can pick by number.

**Wait for user response.** Do not proceed until the user selects an app.

#### 2-2. Fetch App Status

Once the appId is determined, immediately call `get_app_status` MCP tool (`mcp__sdm-marketplace__get_app_status`) with the selected appId. Extract:
- Current version number(s) per feuType *(if available — see fallback below)*
- List of registered feuTypes for this app *(if available — see fallback below)*

If appId is not found → warn user and go back to selection.

**Fallback when `get_app_status` does not include feuType info:**
The current backend response only returns a `versions` array — it does **not** carry a `feuType` field per version, so step 3-1 cannot show "현재 등록된 기기 타입" from this call alone. Detect this case and fall back gracefully:

1. After parsing the response, check whether any version entry exposes a `feuType` (or equivalent) field.
2. If **none** do, treat the registered-feuType list as **unknown** and skip the "이 앱에 등록된 기기 타입" subsection in step 3-1. Show only the .fif files found in `seamos-assets/builds/` and ask the user to either pick one of those filenames or type the feuType directly:
   ```
   현재 백엔드 응답에는 등록된 기기 타입 정보가 포함되어 있지 않습니다.
   builds/ 폴더에서 발견한 파일을 기준으로 선택하거나 직접 입력해주세요:
   1. AUTO-IT_RV-C1000.fif → feuType: AUTO-IT_RV-C1000
   2. RCU4-3Q-20.fif       → feuType: RCU4-3Q/20  (파일명의 `-` 는 보통 `/` 로 환원되니 확인 필요)
   직접 입력하려면 feuType 문자열을 그대로 적어주세요.
   ```
3. The same fallback applies to the **current version** lookup in step 3-2 — if the response does not include a per-feuType current version, ask the user for the version directly without an auto-suggested next-patch.

This data is used in the next step for feuType selection and version suggestion.

### Step 3: Interactive Info Collection (one question at a time)

Collect version info sequentially. Ask one question, wait for the answer, then ask the next. This keeps the interaction simple since there are only a few fields.

#### 3-1. feuType Selection

Present the feuTypes registered for this app (from Step 2-2) and the .fif files available in `seamos-assets/builds/`:

```
## 기기 타입(feuType)을 선택해주세요

이 앱에 등록된 기기 타입:
1. AUTO-IT_RV-C1000 (현재 버전: 1.0.0)
2. RCU4-3Q/20 (현재 버전: 1.0.0)

builds/ 폴더의 .fif 파일:
- AUTO-IT_RV-C1000.fif
- RCU4-3Q-20.fif

번호를 선택하거나 새 feuType을 입력해주세요.
```

**Wait for user response.**

After selection, match the chosen feuType to a .fif file in builds/. If no matching file is found, tell the user which filename is expected and stop.

#### 3-2. Version Number

Suggest an auto-incremented version based on the current version from Step 2-2. Use patch increment by default:

```
## 버전을 입력해주세요

현재 버전: 1.0.0
제안: 1.0.1

Enter를 누르면 1.0.1로 설정됩니다. 다른 버전을 원하시면 입력해주세요. (예: 1.1.0, 2.0.0)
```

**Wait for user response.** If the user sends an empty message or confirms, use the suggested version.

#### 3-3. Update Notes

Ask for update title and description in a single prompt:

```
## 업데이트 노트를 작성해주세요

제목: (예: "버그 수정", "신기능 추가")
설명: (예: "안정성을 개선했습니다.")
```

**Wait for user response.**

The locale is set to `ko` by default. If the app's info from get_app_status shows multiple locales, ask if the user wants to add additional locale entries.

### Step 4: Confirm Update

Show full summary before proceeding:

```
## 앱 버전 업데이트 준비 완료

### 대상 앱
- App ID: {appId}
- 앱 이름: {appName}

### 새 버전
- 기기: {feuType}
- 버전: {currentVersion} → {newVersion}
- 앱 패키지: {filename}.fif

### 업데이트 노트
- 제목: {title}
- 설명: {updateDescription}

업데이트를 진행할까요?
```

**Wait for user confirmation.** Do not execute until the user says yes.

### Step 5: Build and Execute

The request JSON structure for update is fixed:
```json
{
  "variants": [
    {
      "feuType": "{selected feuType}",
      "version": "{new version}",
      "isForTest": false,
      "info": [
        {
          "locale": "ko",
          "title": "{update title}",
          "updateDescription": "{update description}"
        }
      ]
    }
  ]
}
```

Assemble the request JSON using the values collected in Steps 3-4:

```json
{
  "variants": [
    {
      "feuType": "AUTO-IT_RV-C1000",
      "version": "1.0.1",
      "isForTest": false,
      "info": [
        {
          "locale": "ko",
          "title": "버그 수정",
          "updateDescription": "안정성을 개선했습니다."
        }
      ]
    }
  ]
}
```

Execute the upload using the update script:

```bash
bash skills/update-app/scripts/update.sh \
  --base-url "{base_url}" \
  --api-key "{api_key}" \
  --app-id {appId} \
  --request '{variants_json}' \
  --app-file "{feuType}" "{fif_path}"
```

Do NOT build or display the curl command yourself — always use the script, which handles API key masking internally.

**If `--dry-run` argument was provided**: Run the script with `--dry-run` flag first to show what will be sent. Then ask the user if they want to proceed with the actual upload.

### Step 6: Report Result

- **Success (2xx)**: Show response, confirm version was uploaded. Suggest running `get_app_status` to verify deployment status.
- **Transient backend error (5xx, JPA, "Could not open EntityManager"): retry once automatically.**
  The script (`update.sh`) already retries `5xx` and JPA-shaped error bodies once after a 2-second sleep before reporting failure. If the second attempt also fails, surface the original status code to the user with the guidance below.
  Observed in practice: a fresh `update_app_on_device` / `versions` POST occasionally returns `Could not open JPA EntityManager for transaction` on first call right after the backend boots, then succeeds on retry. Do not surface the first transient as an error to the user — only the final outcome.
- **Failure**: Show HTTP status + response body with fix suggestions:
  - 401: API key invalid or missing APP_DEPLOY scope
  - 403: Not the app owner (no WRITE permission)
  - 400: Missing required field or invalid version format
  - 404: App ID not found
  - 5xx (after retry): Server issue still persisting, suggest waiting and retrying manually

### Cache Update

After a successful upload (2xx response), update `.seamos-context.json` at the workspace root:

1. Read the existing `.seamos-context.json` (if it exists) to preserve `deviceId` and `deviceName`
2. Update `appId`, `appName`, and `updatedAt`:
   ```json
   {
     "deviceId": "{preserved from existing file, or omit if not present}",
     "deviceName": "{preserved from existing file, or omit if not present}",
     "appId": "{selected appId}",
     "appName": "{selected app name}",
     "updatedAt": "{ISO 8601 timestamp}"
   }
   ```
3. Write the file using the Write tool

This ensures the next skill invocation (whether `update-app` or `manage-device-app`) can reuse the app selection.

## Important Notes

For shared rules (API key masking, feuType matching, file path conventions), see `skills/shared-references/sdm-common-rules.md`.

**Update-app specific:** No config.json dependency. This skill collects all input interactively and does not read or write `seamos-assets/config.json` — that file belongs to `upload-app`.
