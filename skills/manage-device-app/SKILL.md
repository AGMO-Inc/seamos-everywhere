---
name: manage-device-app
description: Manage apps on SeamOS devices — install, update, or uninstall apps via SDM MCP tools. Use this skill whenever the user wants to install an app on their device, update an installed app to the latest version, remove/uninstall an app from a device, check installed apps, or view their device list. Triggers on "디바이스에 앱 설치", "앱 설치해줘", "앱 업데이트", "앱 삭제", "앱 제거", "install app on device", "uninstall app", "update app on device", "내 디바이스", "설치된 앱", "device app manage". Also triggers when the user mentions a specific device and wants to do something with apps on it, even if they don't say "install" explicitly.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[install|update|uninstall] [--device <id>] [--app <id>]"
---

# Manage Device Apps

Install, update, or uninstall apps on SeamOS devices using the SDM local MCP server.

This skill is about managing apps **on physical devices** — it's different from `upload-app` (publishing a new app to the marketplace) and `update-app` (uploading a new version to the marketplace).

| Want to... | Skill |
|---|---|
| Publish a brand-new app to the marketplace | `upload-app` |
| Upload a new version to the marketplace | `update-app` |
| Install/update/uninstall an app **on a device** | **this skill** |

## Prerequisites

`.mcp.json` at project root with `sdm-marketplace-local` server configured.

## MCP Tools Used

All tools are from the `sdm-marketplace-local` server:

| Tool | Purpose |
|---|---|
| `list_devices` | Get user's device list |
| `list_apps` | Get user's app list (for install) |
| `list_installed_apps` | Get apps on a specific device |
| `install_app_on_device` | Install an app (latest approved version) |
| `update_app_on_device` | Update an installed app to latest version |
| `uninstall_app_from_device` | Remove an app from device |
| `get_task_status` | Poll installation/update/uninstall progress |

## Execution Flow

### Step 1: Initialization

Call `list_devices` to get the user's device list. This is always needed regardless of the action.

If the user already specified a device (by ID, name, or serial number) and an action in their message, skip ahead to the relevant step.

### Step 2: Device Selection

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

Before showing the confirmation, verify the selected device is online. If the device status was `offline` in the `list_devices` response, block the action:

```
## ⚠️ 디바이스 오프라인

선택하신 디바이스 RV-C1000 (ID: 42)이 현재 오프라인 상태입니다.
오프라인 상태에서는 앱 설치/업데이트/삭제를 진행할 수 없습니다.

다른 온라인 디바이스를 선택해주세요:

| # | Device ID | 모델명 | 시리얼 번호 | 상태 |
|---|-----------|--------|------------|------|
| 1 | 43        | RCU4-3Q  | SN-002   | 🟢 온라인 |
```

Then wait for the user to select a different device and restart from Step 3.

If the device is online, show a summary and ask for confirmation:

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

Poll strategy:
1. Wait 2 seconds, then call `get_task_status`
2. If status is `RUNNING` or `PENDING` → report progress and poll again (up to 5 times, 3-second intervals)
3. If status is `COMPLETED` → report success
4. If status is `NOT_FOUND` → warn and suggest retrying

```
## 작업 진행 중...

상태: RUNNING ⏳

(자동으로 상태를 확인하고 있습니다)
```

When complete:

```
## 완료 ✓

Test App이 디바이스 RV-C1000에 설치되었습니다.
```

If polling times out (5 attempts without COMPLETED), inform the user:

```
## 작업이 아직 진행 중입니다

작업이 완료되지 않았지만, 백그라운드에서 계속 진행됩니다.
나중에 상태를 확인하려면 "작업 상태 확인해줘"라고 말씀해주세요.
```

## Shortcut Handling

If the user provides enough context upfront (e.g., "디바이스 42에 앱 10250 설치해줘"), skip the interactive selection steps and go straight to confirmation (Step 5). Parse device ID, app ID, and action from the user's message. However, still check the device's online status first — if it's offline, inform the user and suggest online alternatives instead of proceeding.

Similarly, simple queries like "내 디바이스 보여줘" or "설치된 앱 확인" should just call the relevant MCP tool and display the result — no need to walk through the full workflow.

## Error Handling

- **MCP server unreachable**: "SDM 로컬 서버에 연결할 수 없습니다. `.mcp.json` 설정과 서버 상태를 확인해주세요."
- **No devices**: "등록된 디바이스가 없습니다."
- **No apps**: "등록된 앱이 없습니다. 먼저 `upload-app` 스킬로 앱을 마켓플레이스에 등록해주세요."
- **Install fails**: Show the error from the MCP response and suggest checking device connectivity.

## Important Notes

- This skill uses `sdm-marketplace-local` MCP tools, not `sdm-marketplace`. The local server handles device-specific operations.
- Always show device online/offline status so the user knows what to expect.
- The `install_app_on_device` installs the **latest approved version** — there's no version selection for install.
- When the user just wants to check status (devices, installed apps), respond directly without walking through the full install/update/uninstall flow.
