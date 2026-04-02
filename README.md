# seamos-everywhere

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Org: AGMO-Inc](https://img.shields.io/badge/org-AGMO--Inc-blue)](https://github.com/AGMO-Inc)

A Claude Code plugin for building, testing, and deploying agricultural machinery (농기계) apps to the SeamOS marketplace.

## Overview

**seamos-everywhere** is an open-source Claude Code plugin for the SeamOS AI Native developer ecosystem. It enables developers to create, test, and publish SeamOS apps — designed for agricultural machinery — directly through natural language with Claude Code.

The plugin bridges Claude Code to the SeamOS Development Marketplace (SDM), providing skills for validating and uploading `.fif` app packages to the SeamOS marketplace.

## Installation

### Internal (AGMO-Inc)

```
/plugin marketplace add AGMO-Inc/seamos-everywhere
/plugin install seamos-everywhere@seamos-plugins
```

### From GitHub (public)

```
/plugin marketplace add AGMO-Inc/seamos-everywhere
/plugin install seamos-everywhere@seamos-plugins
```

### Local development

```bash
claude --plugin-dir ./seamos-everywhere
```

## Configuration

After installation, configure your SDM credentials using the plugin's user config:

| Key | Description |
|-----|-------------|
| `sdm_api_url` | Your SDM API base URL (e.g., `https://marketplace-api.seamos.io`) |
| `sdm_api_key` | Your API key with `APP_DEPLOY` scope |

> **Security note:** API keys are stored securely by Claude Code and are never committed to the repository. Do not hardcode your API key anywhere in your project files.

## Skills

### upload-app

Upload a SeamOS app package (`.fif`) to the SDM marketplace.

**Trigger phrases:**
- `앱 업로드`
- `upload app`
- `publish app`
- `앱 등록`
- `deploy app`

**Direct invocation:**
```
/seamos-everywhere:upload-app
```

**What it does:**
1. Validates required assets (`config.json`, images, screenshots, `.fif` build)
2. Uploads the package to the SDM marketplace via multipart REST API

**Expected directory structure:**

```
{project root}/
└── seamos-assets/
    ├── config.json
    ├── mainImage.png
    ├── iconImage.png
    ├── screenshots/
    │   └── screenshot0.png
    └── builds/
        └── {feuType}.fif
```

## Project Structure

```
seamos-everywhere/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── skills/
│   └── upload-app/
│       ├── SKILL.md          # Skill definition
│       ├── scripts/
│       │   └── upload.sh     # Upload script
│       └── references/
│           └── config-template.json
├── mcp-servers.json          # MCP server config template
├── marketplace.json          # Marketplace registration
├── CLAUDE.md                 # Project instructions
├── LICENSE                   # MIT License
└── README.md                 # This file
```

## Contributing

Contributions are welcome. Please open an issue to discuss your idea before submitting a pull request.

- **Bug reports & feature requests:** [Open an issue](https://github.com/AGMO-Inc/seamos-everywhere/issues)
- **Pull requests:** Fork the repo, create a feature branch, and submit a PR against `main`
- Follow the existing code style and keep changes focused

## License

[MIT](./LICENSE) — Copyright (c) AGMO-Inc
