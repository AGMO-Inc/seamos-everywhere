---
name: seamos-app-framework
description: >
  SeamOS (NEVONEX) app framework code generation guide for REST API, WebSocket, DB persistence,
  and feature lifecycle patterns. Supports Java and C++ projects.
  Use when developing SeamOS apps that need HTTP endpoints, WebSocket communication,
  database storage, or lifecycle management.
  Triggers: "REST", "API", "endpoint", "라우트", "route", "WebSocket", "소켓", "socket",
  "DB", "database", "데이터베이스", "영속성", "persistence", "H2", "SQLite",
  "lifecycle", "라이프사이클", "CRUD", "테이블", "table", "repository",
  "saveToDisk", "persistToDisk", "handleFeatureStart".
---

# SeamOS App Framework

Guide for developing SeamOS apps with REST APIs, WebSocket communication, database persistence, and feature lifecycle management.

## Quick Start

1. **Identify pattern** — Determine which pattern the user needs (REST, WebSocket, DB, Lifecycle)
2. **Detect language** — Check project language (Java/C++) using same detection as seamos-plugins
3. **Load patterns** — Read `references/usage-patterns/{lang}.md`
4. **Generate code** — Apply the relevant section's patterns

## Patterns

| Pattern | Java | C++ | Use Case |
|---------|------|-----|----------|
| REST API | NevonexRoute + Spark | NevonexRoute + Poco | HTTP endpoints, CRUD |
| WebSocket | Jetty @WebSocket | WebSocketRouteFactory | Real-time communication |
| DB Persistence | H2 + FCALFileProvider | SQLite + FileProvider | Data storage with container survival |
| Feature Lifecycle | AbstractFeatureNotification | FeatureManagerListener + IgnitionStateListener | App start/stop hooks |

## Workflow

### Step 1: Pattern Selection

Determine which pattern the user needs:
- **REST API** — HTTP endpoints, CRUD operations, request/response handling
- **WebSocket** — Real-time bidirectional communication between app and client
- **DB Persistence** — Structured data storage that survives NEVONEX container restarts
- **Feature Lifecycle** — Hooks for app start, stop, and ignition state changes

### Step 2: Language Detection

Determine the project language:
- `.fgd` filename contains `_java` → Java
- `.fgd` filename contains `_cpp` → C++
- Check `.gen` folder for `.javajet` or `.cppjet` templates
- Fallback: check `FDProject.props`

Load the appropriate pattern file:
- Java → `references/usage-patterns/java.md`
- C++ → `references/usage-patterns/cpp.md`

### Step 3: Code Generation

Read the pattern file and find the `##` section matching the selected pattern. Apply the code template directly — no placeholder substitution beyond class and variable names.

## Notes

- DB Persistence uses a dual-path architecture due to NEVONEX runc container ephemeral filesystem. The `saveToDisk(file, true)` API copies DB to a host-mounted path that survives container restarts. **overwrite parameter must be `true`.**
- Java H2 requires `WRITE_DELAY=0` to ensure data is flushed before `saveToDisk`.
- C++ FileProvider `overwrite` defaults to `false` — always pass `true` explicitly.
- REST/WebSocket patterns are NEVONEX-specific (NevonexRoute, UIWebServiceProvider). Standard HTTP frameworks do not apply.
