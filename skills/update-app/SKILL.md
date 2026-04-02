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

## Execution Flow

### Step 1: Parallel Initialization (do ALL in a single turn)

**A. Get endpoint schema:**
Call `update_app` MCP tool (`mcp__sdm-marketplace__update_app`) with a dummy appId (e.g., `1`). This returns the REST endpoint schema — the appId in the URL will be replaced later with the real one.

**B. Parse MCP config:**
Read `.mcp.json` from project root. Extract:
- `url` from `mcpServers.sdm-marketplace.url` — strip `/mcp` suffix to get base URL (e.g., `http://localhost:8088`)
- `X-API-Key` from `mcpServers.sdm-marketplace.headers.X-API-Key`

**C. List user's apps:**
Call `list_apps` MCP tool (`mcp__sdm-marketplace__list_apps`). This returns all apps owned by the authenticated user with appId, appName, and status.

**D. Scan builds directory:**
Scan `seamos-assets/builds/` for `.fif` files.

### Step 2: App Selection & Status

After initialization completes:

**Hard stops (check first):**
- `.mcp.json` missing or no sdm-marketplace config → guide user to create it
- No `.fif` files in `seamos-assets/builds/` → tell user to place their build file

#### 2-1. Select App

**If the user provided an appId** (via argument or in their message) → use it directly.

**If not** → present the app list from Step 1C:

```
## 업데이트할 앱을 선택해주세요

| # | App ID | 이름 | 상태 |
|---|--------|------|------|
| 1 | 10250  | Test App | RELEASED |
| 2 | 10249  | 스킬 테스트 | RELEASED |

번호 또는 App ID를 입력해주세요.
```

**Wait for user response.** Do not proceed until the user selects an app.

#### 2-2. Fetch App Status

Once the appId is determined, immediately call `get_app_status` MCP tool (`mcp__sdm-marketplace__get_app_status`) with the selected appId. Extract:
- Current version number(s) per feuType
- List of registered feuTypes for this app

If appId is not found → warn user and go back to selection.

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

Ask for update title and description:

```
## 업데이트 노트를 작성해주세요

업데이트 제목: (예: "버그 수정", "신기능 추가")
```

**Wait for user response** (title).

Then:

```
업데이트 설명: (예: "안정성을 개선했습니다.")
```

**Wait for user response** (description).

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

Assemble the request JSON:

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

First, show the user what will be sent by running a dry-run. The script automatically masks the API key in dry-run output, so it is safe to display directly:

```bash
bash skills/update-app/scripts/update.sh \
  --base-url "{base_url}" \
  --api-key "{api_key}" \
  --app-id {appId} \
  --request '{variants_json}' \
  --app-file "{feuType}" "{fif_path}" \
  --dry-run
```

Show the dry-run output to the user. Then execute the actual upload (same command without `--dry-run`). Do NOT build or display the curl command yourself — always use the script, which handles API key masking internally.

### Step 6: Report Result

- **Success (2xx)**: Show response, confirm version was uploaded. Suggest running `get_app_status` to verify deployment status.
- **Failure**: Show HTTP status + response body with fix suggestions:
  - 401: API key invalid or missing APP_DEPLOY scope
  - 403: Not the app owner (no WRITE permission)
  - 400: Missing required field or invalid version format
  - 404: App ID not found
  - 5xx: Server issue, suggest retrying

## Important Notes

- **No config.json dependency.** This skill collects all input interactively. It does not read or write `seamos-assets/config.json` — that file belongs to `upload-app`.
- **API Key Masking**: When displaying output to the user, ALWAYS mask the API key. Show only first 6 characters followed by `***` (e.g., `sdm_ak_***`). The full key should only appear inside the actual curl execution within `update.sh`.
- The `feuType` part name in the multipart request MUST exactly match the feuType in the variants JSON.
- The `feuType` is selected from the app's registered types via `get_app_status`, not guessed from filenames.
- All file paths should be relative to the project root for portability.
