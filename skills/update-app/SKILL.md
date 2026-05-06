---
name: update-app
description: Upload a new version of an existing SeamOS app to the SeamOS marketplace. Use this skill whenever the user wants to update, upgrade, or push a new version of their app. Triggers on "앱 업데이트", "버전 업데이트", "새 버전 올려", "update app", "new version", "버전 업로드", "앱 버전". Also use when the user mentions updating a .fif file for an app that already exists on the marketplace, or wants to deploy a patch/update to a released app.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[appId] [--feu-type FEU] [--arch ARCH] [--dry-run]"
---

# Update App Version on SeamOS Marketplace

Upload a new version (.fif) of an existing app to the SeamOS marketplace. Unlike `upload-app` (which creates a brand-new app with full metadata and images), this skill only requires variant info and the app package file.

This skill does NOT use config.json. All version info is collected interactively from the user, one question at a time.

## When to Use This vs upload-app

| Scenario | Skill |
|---|---|
| First time publishing an app | `upload-app` |
| Pushing a new version of an already-published app | **this skill** (`update-app`) |

## Prerequisites

1. `.mcp.json` at project root with `seamos-marketplace` server configured. Authentication is OAuth (PKCE) — the first MCP call triggers a one-time browser login; no API key required.
2. The app must already exist on the marketplace (use `upload-app` first)
3. A `.fif` app package in `seamos-assets/builds/`

## Context Caching

This skill uses `.seamos-context.json` for app selection caching. For cache structure and shared ownership rules, see `skills/shared-references/seamos-context-cache.md`.

This skill only reads/writes `appId`, `appName`, and `updatedAt` — it preserves `deviceId` and `deviceName` if already present.

## Execution Flow

### Step 1: Parallel Initialization (do ALL in a single turn)

**A. Parse MCP config:**
Read `.mcp.json` from project root. Extract:
- `url` from `mcpServers.seamos-marketplace.url` — strip `/mcp` suffix to get base URL (e.g., `http://localhost:8088`). MCP-level OAuth token is managed by Claude Code automatically; no API key extraction is needed here. The one-time multipart `uploadToken` is fetched in Step 5 from `update_app`.

**B. List user's apps:**
Call `list_apps` MCP tool (`mcp__seamos-marketplace__list_apps`). This returns two groups:
- `personalApps` — apps owned by the user directly
- `organizationApps` — apps belonging to the user's organization (may be empty if user has no org)

Each entry has `appId`, `appName`, and `status`.

**C. Scan builds directory:**
Scan `seamos-assets/builds/` for `.fif` files.

### Step 2: App Selection & Status

After initialization completes:

**Hard stops (check first):**
- `.mcp.json` missing or no seamos-marketplace config → guide user to create it
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

Once the appId is determined, immediately call `get_app_status` MCP tool (`mcp__seamos-marketplace__get_app_status`) with the selected appId. Extract:
- Current version number(s) per feuType *(if available — see fallback below)*
- List of registered feuTypes for this app *(if available — see fallback below)*

If appId is not found → warn user and go back to selection.

### 3-0. Fallback — `get_app_status` 응답에 `feuType` 이 없는 경우

응답에 `feuType` 키가 누락된 경우, 파일명에서 feuType 값을 도출하는 절차를 두지 않는다. 대신 다음 두 단계로 분리한다.

1. **ARCH 토큰 파싱**: `.fif` 파일명에서 ARCH 부분만 분리한다. 컨벤션은 `<ARCH>-<VERSION>.fif` — 마지막 `-` 앞까지가 ARCH, 뒤가 version. 예: `RCU4-3Q-20.fif` → ARCH=`RCU4-3Q`, version=`20`. 컨벤션을 따르지 않는 파일명(예: `myapp.fif`) 은 ARCH 인식에 실패한다.

2. **feuType 명시 질문**: 사용자에게 다음 형식으로 묻는다 — "이 .fif 는 ARCH `<ARCH>` 빌드입니다. 어느 feuType 에 등록할까요?" 후보 목록은 (a) 컨텍스트 캐시의 `last_app_register.feuType` (해당 appId 일치 시, "(last used)" 라벨 부착), (b) `get_app_status` 가 부분적으로라도 반환한 기존 feuType 목록 — 합집합으로 제시. 후보가 없으면 빈 목록 + 직접 입력 안내. **후보를 임의 선택하지 않으며 — 항상 사용자 확인을 거친다.**

3. **ARCH 인식 실패 fallback**: ARCH 토큰 파싱이 실패한 경우 "ARCH 를 자동 인식하지 못했습니다. 어느 ARCH 와 feuType 에 등록할까요?" 라는 메시지로 ARCH 와 feuType 둘 다 직접 입력 받는다.

4. **`--feu-type` 명시 인자**: 호출 시 `--feu-type` 옵션이 주어졌다면 본 fallback 블록 전체를 skip 하고 해당 값을 그대로 사용한다 (ARCH 도 `--arch` 인자 우선). 자동화 파이프라인 대응 경로. 본 스킬 인자는 `update.sh` 의 동일 이름 인자(`--feu-type FEU` / `--arch ARCH`) 로 그대로 전달 가능 — 인터랙티브 단계 없이 호출하려면 `--feu-type FEU --fif PATH` 또는 `--feu-type FEU --arch ARCH` (BUILD_DIR 의 `<ARCH>-*.fif` 단일 매칭 자동 해석) 조합 사용.

### 3-0a. FeuType 캐시 흐름

컨텍스트 캐시(`.seamos-context.json`) 의 `last_app_register` 영역을 읽고 쓴다.

- **읽기 (fallback 단계)**: `last_app_register.feuType`, `last_app_register.arch`, `last_app_register.appId`, `last_app_register.updatedAt` 4개 필드를 읽는다. 현재 호출의 appId 와 캐시의 `last_app_register.appId` 가 *일치하는 경우에만* 후보 목록의 첫 항목으로 `<feuType> (last used)` 를 제시한다. **사용자 선택 없이 캐시 값을 그대로 반영하지 않으며 — 제시(suggest) 만 한다.**
- **appId 불일치**: 캐시의 appId 와 다르면 lastFeuType 후보를 노출하지 않는다 — 다른 앱의 등록 흔적이므로 무용.
- **쓰기 (등록 성공 후)**: 등록이 성공적으로 끝나면 같은 4개 필드를 갱신한다 (`updatedAt` 은 ISO 8601). 실패한 등록 시도는 캐시에 쓰지 않는다.
- 본 영역은 다른 스킬이 사용하지 않는다 — `last_project`, 디바이스/앱 캐시 영역과 분리되어 있다 (`shared-references/seamos-context-cache.md` 참고).

### Step 3: Interactive Info Collection (one question at a time)

Collect version info sequentially. Ask one question, wait for the answer, then ask the next. This keeps the interaction simple since there are only a few fields.

#### 3-1. feuType Selection

**다중 ARCH 빌드가 BUILD_DIR 에 공존하는 경우**: 한 워크스페이스에 `RCU4-3Q-20.fif` 와 `RCU4-7Q-20.fif` 처럼 여러 ARCH 의 `.fif` 가 동시에 존재할 수 있다. 이 경우 "여러 .fif 가 발견되었습니다. 어느 ARCH 를 등록하시겠습니까?" 형식으로 명시 선택을 받는다 — 자동으로 첫 번째를 고르지 않는다.

본 호출은 한 번에 *하나의 feuType* 에만 대응한다 (one feuType per invocation). 여러 feuType 에 등록하려면 update-app 을 다시 실행한다.

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

확인 프롬프트 예시:
```
appId=app_test_001, feuType=arable/cabin, ARCH=RCU4-3Q, version=20 으로 업로드합니다. 진행할까요? [y/N]
```

위 4-tuple (appId, feuType, ARCH, target version) 을 모두 표시하여 사용자에게 최종 확인을 받는다.

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

#### 5-0. Get one-time upload token

Call the `update_app` MCP tool (`mcp__seamos-marketplace__update_app`) with the selected `appId`. This returns the REST endpoint info plus a one-time multipart upload token bound to that `appId`:

- `endpoint.authentication.uploadToken` — `ut_*` token, 5-minute TTL, single-use, scoped to this `appId`
- `endpoint.authentication.uploadTokenExpiresAt` — ISO-8601 expiry

Call this **immediately before** running `update.sh` so the token does not expire mid-flight. If the user pauses between confirmation and execution and the token has aged, simply call `update_app` again to obtain a fresh token.

#### 5-1. Build request JSON

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

#### 5-2. Execute upload

Execute the upload using the update script. Pass the `uploadToken` from Step 5-0 — the script wraps it as `Authorization: Bearer ut_...`:

```bash
bash skills/update-app/scripts/update.sh \
  --base-url "{base_url}" \
  --upload-token "{upload_token}" \
  --app-id {appId} \
  --request '{variants_json}' \
  --app-file "{feuType}" "{fif_path}"
```

자동화 파이프라인이 단일 variant 만 등록하는 경우 `--feu-type` + (`--fif` | `--arch`) 조합도 사용 가능 — 결과적으로 동일한 multipart 요청 생성:

```bash
bash skills/update-app/scripts/update.sh \
  --base-url "{base_url}" \
  --upload-token "{upload_token}" \
  --app-id {appId} \
  --request '{variants_json}' \
  --feu-type "{feuType}" \
  --arch "{arch}"   # 또는 --fif "{fif_path}"
```

`--feu-type` / `--fif` / `--arch` 는 `--app-file` 과 혼용 불가. `--arch` 만 주어지면 BUILD_DIR (기본 `./seamos-assets/builds`) 에서 `<ARCH>-*.fif` 단일 매칭을 찾아 사용 — 0 매칭 / 다중 매칭은 명시 에러.

Do NOT build or display the curl command yourself — always use the script, which handles upload-token masking internally.

**If `--dry-run` argument was provided**: Run the script with `--dry-run` flag first to show what will be sent. Then ask the user if they want to proceed with the actual upload.

### Step 6: Report Result

- **Success (2xx)**: Show response, confirm version was uploaded. Suggest running `get_app_status` to verify deployment status.
- **Failure**: Show HTTP status + response body with fix suggestions:
  - 401: upload token expired, already used, or malformed → call `update_app` again to get a fresh token, then retry within 5 minutes
  - 403: Not the app owner (no WRITE permission), or token-to-app scope mismatch (server-side check) — re-run `update_app`
  - 400: Missing required field or invalid version format
  - 404: App ID not found
  - 5xx: Backend transient — the upload token has already been consumed, so rerun the skill to get a fresh token and retry

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

For shared rules (API key masking, feuType matching, file path conventions), see `skills/shared-references/seamos-common-rules.md`.

**Update-app specific:** No config.json dependency. This skill collects all input interactively and does not read or write `seamos-assets/config.json` — that file belongs to `upload-app`.
