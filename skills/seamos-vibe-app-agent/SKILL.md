---
name: seamos-vibe-app-agent
description: >
  Thin coordinator for end-to-end SeamOS app work. Use when the user asks to
  make, build, publish, or iterate on a SeamOS app from a high-level product
  idea, especially when the request spans project creation, plugin signals,
  backend REST/DB/WebSocket work, CustomUI, FIF build, and marketplace upload
  or update. Routes to existing SeamOS skills; does not replace them.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# SeamOS Vibe App Agent

Coordinate an end-to-end SeamOS app by routing to the owning skills. Keep this
skill thin; do not duplicate long snippets or implementation templates from
child skills.

## Required Playbook

Read the shared playbook first:

[`shared-references/vibe-seamos-app-agent.md`](../../shared-references/vibe-seamos-app-agent.md)

Use it to decide which existing skill owns the next step:

- `create-project` for new FSP + SDK/APP skeletons and interface JSON setup
- `seamos-plugins` for provider, Machine object, and signal selection
- `seamos-app-framework` for REST, WebSocket, DB, lifecycle, and cloud-proxy backend patterns
- `seamos-customui-ux` for ADS/operator UX rules
- `seamos-customui-client` for CustomUI port discovery, REST base URL, WS frames, and browser cloud-proxy behavior
- `build-fif` for packaging
- `upload-app` for first marketplace publish
- `update-app` for existing app version upload

## Operating Rule

At each step, name the owning skill, load only the references needed for that
step, execute or edit through that skill's documented workflow, then return to
the playbook flow map.
