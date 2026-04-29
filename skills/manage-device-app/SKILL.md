---
name: manage-device-app
description: Manage apps on SeamOS devices — install, update, or uninstall apps via SeamOS MCP tools. Use this skill whenever the user wants to install an app on their device, update an installed app to the latest version, remove/uninstall an app from a device, check installed apps, or view their device list. Triggers on "디바이스에 앱 설치", "앱 설치해줘", "앱 업데이트", "앱 삭제", "앱 제거", "install app on device", "uninstall app", "update app on device", "내 디바이스", "설치된 앱", "device app manage". Also triggers when the user mentions a specific device and wants to do something with apps on it, even if they don't say "install" explicitly.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[install|update|uninstall] [--device <id>] [--app <id>]"
---

# Manage Device Apps

Install, update, or uninstall apps on SeamOS devices using the SeamOS local MCP server.

This skill is about managing apps **on physical devices** — it's different from `upload-app` (publishing a new app to the marketplace) and `update-app` (uploading a new version to the marketplace).

| Want to... | Skill |
|---|---|
| Publish a brand-new app to the marketplace | `upload-app` |
| Upload a new version to the marketplace | `update-app` |
| Install/update/uninstall an app **on a device** | **this skill** |

## Prerequisites

`.mcp.json` at project root with `seamos-marketplace-local` server configured.

## MCP Tools Used

All tools are from the `seamos-marketplace-local` server:

| Tool | Purpose |
|---|---|
| `list_devices` | Get user's device list |
| `list_apps` | Get user's app list (for install) |
| `list_installed_apps` | Get apps on a specific device |
| `install_app_on_device` | Install an app (latest approved version) |
| `update_app_on_device` | Update an installed app to latest version |
| `uninstall_app_from_device` | Remove an app from device |
| `get_task_status` | Poll installation/update/uninstall progress |

## Context Caching

This skill uses `.seamos-context.json` for device and app selection caching. For cache structure and shared ownership rules, see `skills/shared-references/seamos-context-cache.md`.

This skill reads/writes all fields (`deviceId`, `deviceName`, `appId`, `appName`, `updatedAt`) and overwrites the entire cache after any successful action.

## Execution Flow

### Step 1: Initialization

Call `list_devices` to get the user's device list. This is always needed regardless of the action.

**Shortcut path:** If the user provides enough context upfront (e.g., "디바이스 42에 앱 10250 설치해줘"), parse device ID, app ID, and action from the message. Verify the device is online via `list_devices`, then skip directly to Step 5 (Confirm and Execute). If the device is offline, inform the user and fall through to Step 2 for alternative selection.

**Simple queries:** For read-only queries like "내 디바이스 보여줘" or "설치된 앱 확인", call the relevant MCP tool and display the result directly — no need for the full workflow.

If the user didn't specify a device or action, proceed to Step 2.

### Step 2: Device Selection

**Cache check:** Before presenting the device list, read `.seamos-context.json` from the workspace root. If the file exists and contains `deviceId`:

1. Find the cached device in the `list_devices` result
2. If the device is **online** → show confirmation prompt:
   ```
   이전에 사용한 디바이스: {deviceName} (ID: {deviceId}) — 이대로 진행할까요? (Y/다른 디바이스 선택)
   ```
   - User confirms → use cached deviceId, skip to Step 3
   - User declines → proceed with full device list below
3. If the device is **offline** → ignore cache, proceed with full device list below (inform the user: "이전 디바이스 {deviceName}이 오프라인 상태입니다. 다른 디바이스를 선택해주세요.")
4. If the device is **not found** in `list_devices` result → ignore cache, proceed with full device list

**If no cache exists**, proceed with the normal flow:

Present the device list:

```
## 디바이스를 선택해주세요

| # | Device ID | 모델명 | 시리얼 번호 | 상태 |
|---|-----------|--------|------------|------|
| 1 | 42        | RV-C1000 | SN-001   | 🟢 온라인 |
| 2 | 43        | RCU4-3Q  | SN-002   | 🔴 오프라인 |

번호 또는 Device ID를 입력해주세요.
```

**Offline device handling**: If the user selects (or specifies) a device that is offline, do NOT proceed with install/update/uninstall. Instead, explain that the device is offline and operations cannot be executed, then suggest selecting a different online device from the list. Re-display the device table so the user can pick an alternative. Simple read-only queries (e.g., "설치된 앱 확인") can still proceed on offline devices since they only fetch cached data from the server.

**Wait for user response** if device wasn't specified upfront.

### Step 3: Action Selection

If the user already stated what they want to do (install, update, uninstall), skip this step.

Otherwise, call `list_installed_apps` with the selected deviceId to see what's currently on the device, then ask:

```
## 어떤 작업을 할까요?

현재 디바이스에 설치된 앱: 3개

1. 앱 설치 (새 앱 추가)
2. 앱 업데이트 (설치된 앱 최신 버전으로)
3. 앱 삭제 (설치된 앱 제거)

번호를 선택해주세요.
```

**Wait for user response.**

### Step 4: App Selection

**Cache check:** Before presenting the app list, check `.seamos-context.json` for `appId`. If cached:

1. Show confirmation prompt:
   ```
   이전에 사용한 앱: {appName} (ID: {appId}) — 이대로 진행할까요? (Y/다른 앱 선택)
   ```
   - User confirms → use cached appId, skip to Step 5
   - User declines → proceed with full app list below
2. For **install** action: if the cached app is already installed on the selected device, skip cache and show the uninstalled app list
3. For **uninstall** action: if the cached app is NOT installed on the selected device, skip cache and show the installed app list

**If no cache exists**, proceed with the normal flow:

The app selection flow depends on the chosen action:

#### 4A. Install (새 앱 설치)

Call both `list_apps` and `list_installed_apps` in parallel.

Compare the two lists and show apps that are **not yet installed** on the device. If an app has no approved version, mark it so the user knows it can't be installed yet.

```
## 설치할 앱을 선택해주세요

| # | App ID | 앱 이름 | 상태 |
|---|--------|---------|------|
| 1 | 10250  | Test App | RELEASED ✓ |
| 2 | 10251  | New App  | PENDING (설치 불가 — 승인 대기 중) |

번호 또는 App ID를 입력해주세요.
```

**Wait for user response.**

#### 4B. Update (설치된 앱 업데이트)

Use the `list_installed_apps` result (already fetched in Step 3, or fetch now).

Show only apps that **have updates available**:

```
## 업데이트 가능한 앱

| # | App ID | 앱 이름 | 현재 버전 | 최신 버전 | 상태 |
|---|--------|---------|----------|----------|------|
| 1 | 10250  | Test App | 1.0.0   | 1.1.0    | 업데이트 가능 |

번호 또는 App ID를 입력해주세요.
```

If no updates are available, tell the user: "모든 앱이 최신 버전입니다." and stop.

**Wait for user response.**

#### 4C. Uninstall (앱 삭제)

Use the `list_installed_apps` result.

Show installed apps:

```
## 삭제할 앱을 선택해주세요

| # | App ID | 앱 이름 | 버전 |
|---|--------|---------|------|
| 1 | 10250  | Test App | 1.0.0 |
| 2 | 10249  | My App   | 2.1.0 |

번호 또는 App ID를 입력해주세요.
```

**Wait for user response.**

### Step 5: Confirm and Execute

Show a summary and ask for confirmation:

```
## 작업 확인

- 디바이스: RV-C1000 (ID: 42)
- 작업: 앱 설치
- 대상 앱: Test App (ID: 10250)

진행할까요?
```

**Wait for user confirmation.** Do not execute until the user says yes.

After confirmation, call the appropriate MCP tool:
- Install → `install_app_on_device(deviceId, appId)`
- Update → `update_app_on_device(deviceId, appId)`
- Uninstall → `uninstall_app_from_device(deviceId, appId)`

### Step 6: Status Polling

After the action is triggered, poll `get_task_status(deviceId, appId)` to track progress.

Poll strategy (bounded by an absolute wall-clock budget, not just attempt count):
1. Wait 2 seconds, then call `get_task_status`
2. If status is `RUNNING` or `PENDING` → report progress and poll again every 3 seconds
3. If status is `COMPLETED` → report success
4. If status is `NOT_FOUND` → warn and suggest retrying
5. **Hard timeout: 5 minutes total** (≈100 attempts at 3-second intervals). Stop polling once the budget is exhausted regardless of how many attempts have been made.

> **Important — `task-status` is sometimes stuck on `RUNNING` even after the device finished.** A known marketplace-side bug leaves `get_task_status` reporting `RUNNING` indefinitely while the device has already completed the install/update/uninstall. Do **not** treat a stuck `RUNNING` as failure. If the timeout fires:
> 1. Call `list_installed_apps(deviceId)` once and compare against the action:
>    - **install/update**: the target appId should now appear (and for update, with the new version) — treat as success.
>    - **uninstall**: the target appId should be **gone** — treat as success.
> 2. Surface the discrepancy to the user with the device-side check as the source of truth, not the marketplace task-status.

```
## 작업 진행 중...

상태: RUNNING ⏳

(자동으로 상태를 확인하고 있습니다 — 최대 5분)
```

When complete:

```
## 완료 ✓

Test App이 디바이스 RV-C1000에 설치되었습니다.
```

If polling hits the 5-minute timeout, run the device-side reconciliation above and report whichever outcome it shows:

```
## task-status 가 갱신되지 않습니다 (마켓플레이스 알려진 이슈)

5분 동안 task-status 가 RUNNING 으로 머물러 있어, 디바이스에서 직접 확인했습니다:

- list_installed_apps 결과: Test App 1.1.0 ← **새 버전이 설치됨**
- 따라서 작업은 사실상 성공했습니다.

마켓플레이스의 task-status 갱신은 백엔드 이슈로 보이며, 디바이스 동작과 무관합니다.
다시 확인하려면 "설치된 앱 확인해줘"라고 말씀해주세요.
```

If the device check is also inconclusive (target app not present after install, or still present after uninstall), then the action genuinely did not complete:

```
## 작업이 완료되지 않았을 수 있습니다

5분 폴링 후에도 task-status 가 RUNNING 이고, 디바이스에서도 변경이 확인되지 않았습니다.
잠시 후 "설치된 앱 확인해줘"로 다시 점검하거나, 디바이스 네트워크 상태를 확인해주세요.
```

### Cache Update

After any successful action (install, update, or uninstall), update `.seamos-context.json` with the selected device and app info. See `skills/shared-references/seamos-context-cache.md` for the exact structure and write rules.

**Note on uninstall:** Even after uninstalling, cache the appId — the user may want to reinstall or manage the same app on a different device.

## Error Handling

- **MCP server unreachable**: "SeamOS 로컬 서버에 연결할 수 없습니다. `.mcp.json` 설정과 서버 상태를 확인해주세요."
- **No devices**: "등록된 디바이스가 없습니다."
- **No apps**: "등록된 앱이 없습니다. 먼저 `upload-app` 스킬로 앱을 마켓플레이스에 등록해주세요."
- **Install fails**: Show the error from the MCP response and suggest checking device connectivity.

## Important Notes

- This skill uses `seamos-marketplace-local` MCP tools, not `seamos-marketplace`. The local server handles device-specific operations.
- Always show device online/offline status so the user knows what to expect.
- The `install_app_on_device` installs the **latest approved version** — there's no version selection for install.
- When the user just wants to check status (devices, installed apps), respond directly without walking through the full install/update/uninstall flow.
