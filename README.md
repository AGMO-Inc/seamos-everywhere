<div align="center">

<img src="assets/Agriman_2.png" alt="Agriman" width="120" />

# SeamOS Everywhere

**Claude Code plugin for the SeamOS AI Native developer ecosystem**

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/AGMO-Inc/seamos-everywhere/releases)
[![Skills](https://img.shields.io/badge/skills-7-orange.svg)](#skills)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)
[![Org](https://img.shields.io/badge/org-AGMO--Inc-green.svg)](https://github.com/AGMO-Inc)

*Build, publish, and deploy agricultural machinery apps to the SeamOS marketplace — entirely through natural language.*

</div>

---

## Overview

**seamos-everywhere** bridges Claude Code to the SeamOS Development Marketplace (SDM). It covers the full app lifecycle: publishing a new app, pushing version updates, and managing apps on physical devices — all without leaving the terminal.

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| **Claude Code** | Yes | Anthropic official CLI |
| **SDM API Key** | Yes | `APP_DEPLOY` scope required |

## Installation

```bash
# 1. Register marketplace source
/plugin marketplace add AGMO-Inc/seamos-everywhere

# 2. Install plugin
/plugin install seamos-everywhere@AGMO-Inc/seamos-everywhere
```

### Local development

```bash
claude --plugin-dir ./seamos-everywhere
```

## Configuration

After installation, configure your SDM credentials:

| Key | Description |
|-----|-------------|
| `sdm_api_url` | SDM API base URL (e.g., `https://dev.marketplace-api.seamos.io`) |
| `sdm_api_key` | API key with `APP_DEPLOY` scope |

> **Security:** API keys are stored securely by Claude Code and never committed to the repository.

---

## Asset Directory

Skills that interact with the marketplace expect a `seamos-assets/` directory at your project root. This is where app metadata, images, and build packages live.

```
{project root}/
└── seamos-assets/
    ├── config.json            # App metadata (auto-generated on first upload)
    ├── mainImage.png          # Main image (required for upload-app)
    ├── iconImage.png          # Icon image (required for upload-app)
    ├── screenshots/           # At least 1 screenshot (required for upload-app)
    │   ├── screenshot0.png
    │   └── screenshot1.png
    └── builds/                # App packages
        └── {feuType}.fif      # e.g., AUTO-IT_RV-C1000.fif
```

| File | Used by | Required |
|------|---------|----------|
| `config.json` | `upload-app` | Yes — auto-generated from live API schema on first run |
| `mainImage.png` | `upload-app` | Yes |
| `iconImage.png` | `upload-app` | Yes |
| `screenshots/*` | `upload-app` | Yes (min 1) |
| `builds/*.fif` | `upload-app`, `update-app` | Yes |

> `update-app` only needs the `.fif` file in `builds/` — no images or config.json required.
>
> `manage-device-app` does not use `seamos-assets/` at all. It operates via MCP tools directly.

---

## Skills

### upload-app

Publish a brand-new SeamOS app to the SDM marketplace. Validates all required assets, auto-generates `config.json` from the live API schema, and uploads the complete package via multipart REST API.

**Triggers:** `앱 업로드` · `upload app` · `publish app` · `앱 등록` · `deploy app`

```
/seamos-everywhere:upload-app
```

**Flow:**
1. Scans `seamos-assets/` for required files — scaffolds the directory if missing
2. Auto-generates `config.json` from the live API schema on first run
3. Validates metadata and cross-checks feuType against build files
4. Uploads the complete app package to the marketplace

---

### update-app

Upload a new version of an existing app. Only requires the `.fif` package and version info — no images or full metadata needed.

**Triggers:** `앱 업데이트` · `버전 업데이트` · `새 버전 올려` · `update app` · `new version`

```
/seamos-everywhere:update-app
```

**Flow:**
1. Lists your registered apps and lets you select the target
2. Shows registered feuTypes with current versions
3. Collects version number and update notes interactively
4. Uploads the new `.fif` package to the marketplace

---

### manage-device-app

Install, update, or uninstall apps on physical SeamOS devices. Manages apps **on devices**, not on the marketplace.

**Triggers:** `디바이스에 앱 설치` · `앱 설치해줘` · `앱 삭제` · `install app on device` · `uninstall app` · `내 디바이스`

```
/seamos-everywhere:manage-device-app
```

**Flow:**
1. Lists your registered devices with online/offline status
2. Guides through device selection, action choice, and app selection
3. Executes the operation and polls for completion status
4. Detects offline devices and suggests online alternatives

| Action | Description |
|--------|-------------|
| Install | Install the latest approved version of an app on a device |
| Update | Update an installed app to the latest version |
| Uninstall | Remove an app from a device |

---

### seamos-plugins

SEAMOS plugin reference and code generation guide. Provides a catalog of 13 NEVONEX plugins with full interface specs, and language-specific code patterns for both **Java** and **C++** projects. Covers CAN signals, GPS, IMU, GPIO, Platform Services, and more.

**Triggers:** `plugin` · `플러그인` · `CAN signal` · `Machine object` · `GPS` · `tractor` · `steering` · `IMU`

```
/seamos-everywhere:seamos-plugins
```

**Flow:**
1. Reads plugin catalog — identifies the target plugin from user intent
2. Loads the plugin's interface spec (signals, data types, directions)
3. Detects project language (Java / C++) and loads the matching code patterns
4. Generates code using placeholders filled with actual signal data

| Feature | Details |
|---------|---------|
| Plugins | 13 (CAN, GPS, IMU, GPIO, Implement, ISOPGN, Platform Service, etc.) |
| Languages | Java, C++ |
| Signals | 634 (Implement) · 140 (ISOPGN) · 3–15 (others) |

---

### seamos-app-framework

SeamOS app framework code generation guide. Provides language-specific patterns for **REST API**, **WebSocket**, **DB persistence** (with NEVONEX container survival), and **Feature Lifecycle** management. Supports both **Java** and **C++** projects.

**Triggers:** `REST` · `API` · `endpoint` · `WebSocket` · `DB` · `database` · `persistence` · `lifecycle` · `CRUD` · `saveToDisk`

```
/seamos-everywhere:seamos-app-framework
```

**Flow:**
1. Identifies the needed pattern (REST, WebSocket, DB, Lifecycle)
2. Detects project language (Java / C++)
3. Loads language-specific framework patterns
4. Generates code using NEVONEX-specific conventions

| Feature | Details |
|---------|---------|
| Patterns | 4 (REST API, WebSocket, DB Persistence, Feature Lifecycle) |
| Languages | Java, C++ |
| DB Persistence | NEVONEX container-aware (FCALFileProvider / FileProvider) |

---

### build-fif

Build a deployable FIF (Feature Installation File) package using Docker. Supports both Java (Maven) and C++ (CMake) SeamOS projects with auto-detection.

**Triggers:** `build fif` · `fif 빌드` · `배포 빌드` · `앱 빌드` · `패키지 빌드`

```
/seamos-everywhere:build-fif
```

**Flow:**
1. Auto-detects project type (Java / C++) from project structure
2. Runs Docker-based cross-compilation (aarch64 target)
3. Packages the build artifact into a `.fif` file
4. Outputs to `seamos-assets/builds/*.fif`

---

### create-project

Create a new SeamOS project (FSP) via a Dockerized FD Headless binary. Supports natural-language interface selection against the offlineDB catalog, or direct consumption of an `fd_user_selected_interface.json`. UI type is fixed to `Custom UI`.

**Triggers:** `프로젝트 생성` · `create project` · `FSP 생성` · `skeleton generate` · `SeamOS 프로젝트 만들어`

```
/seamos-everywhere:create-project
```

**Flow:**
1. Preflight check — host tools (`docker`, `jq`, `shasum`, `timeout`) + Apple Silicon Rosetta 2 detection
2. Interactive interface JSON synthesis from `offlineDB.json` (or accepts `--interface-json <path>`)
3. Validates the synthesized JSON before any container run
4. Runs `public.ecr.aws/g0j5z0m9/seamos-fd-headless` image with the chosen FD operation
5. Detects success/failure via stdout grep, writes `.seamos-context.json` atomically for downstream skills

| Feature | Details |
|---------|---------|
| FD operations | `GENERATE_FSP`, `GENERATE_SDK_APP`, `UPDATE_SDK_APP` |
| Image | `linux/amd64` — compressed ~293 MB / uncompressed ~934 MB |
| Offline | `docker save`/`load` air-gapped bundle supported |
| Blocking gates | supply-chain (SHA256) · legal (LEGAL.md) · compat (preflight) · validity (JSON validator) |

---

### Skill comparison

| Want to... | Skill |
|---|---|
| Create a new SeamOS project (FSP) | `create-project` |
| Generate REST, WebSocket, DB, or Lifecycle framework code | `seamos-app-framework` |
| Look up plugin interfaces and generate signal code | `seamos-plugins` |
| Build a `.fif` deployment package | `build-fif` |
| Publish a brand-new app to the marketplace | `upload-app` |
| Push a new version of an existing app | `update-app` |
| Install / update / uninstall an app on a device | `manage-device-app` |

---

## Contributing

Contributions are welcome. Please open an issue to discuss your idea before submitting a pull request.

- **Bug reports & feature requests:** [Open an issue](https://github.com/AGMO-Inc/seamos-everywhere/issues)
- **Pull requests:** Fork the repo, create a feature branch, and submit a PR against `main`

## License

[MIT](./LICENSE) — Copyright (c) AGMO-Inc
