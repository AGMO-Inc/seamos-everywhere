---
name: seamos-plugins
description: >
  SEAMOS (NEVONEX) plugin reference and code generation guide for agricultural machinery app development.
  Provides plugin catalog, interface specs, signal field details, and language-specific code patterns.
  Use when developing SeamOS apps that interact with CAN signals, GPS, IMU, GPIO, or platform services.
  Triggers: "plugin", "플러그인", "CAN signal", "CAN 신호", "Machine object", "Provider",
  "steering", "조향", "GPS", "tractor", "트랙터", "signal read", "signal write",
  "신호 읽기", "신호 쓰기", "implement", "ISOPGN", "Platform_Service", "GPIO",
  "IMU", "gyro", "자이로", "QR scanner", "cloud upload", "AgriRouter",
  "TCOperations", "Task Controller", "태스크 컨트롤러", "NMEA", "serial GPS", "시리얼 GPS".
---

# SEAMOS Plugin Reference

Guide for developing SeamOS apps using NEVONEX plugin Machine objects.

## Quick Start

1. **Identify plugin** — Read [catalog.md](references/catalog.md) to find the plugin matching the user's need
2. **Load detail** — Read `references/detail/{PluginName}.md` for full interface spec
3. **Load patterns** — Detect project language, read `references/usage-patterns/{lang}.md`
4. **Generate code** — Apply pattern placeholders with signal data from the detail file

## Plugin Architecture

```
Provider (plugin) → Machine object (I{PluginName} interface) → Signal getter/setter → Controller (app logic)
```

- **13 plugins** available — see catalog for full list
- Each plugin exposes a **Machine object** with signal-level getter/setter methods
- Signals have direction: **In** (Subscribe/read) or **Out** (Publish/write)
- Platform_Service is special: uses **Method** invocations instead of signals

## Workflow

### Step 1: Plugin Selection

Read `references/catalog.md`. Match user intent to plugins using:
- **Selection Guide by Use Case** — e.g., "steering" → CAN_AGMO_SteerMotor
- **Selection Guide by Standard** — e.g., "J1939 PGN" → ISOPGN

If the user doesn't specify a plugin, ask or infer from context.

### Step 2: Interface Lookup

Read `references/detail/{PluginName}.md` for the selected plugin. This contains:
- Machine ID and Provider class
- Complete interface table (direction, signal name, standard, ID, mode, data type)
- Signal field details (field names, types, units for array-type signals)

### Step 3: Language Detection

Determine the project language:
- `.fgd` filename contains `_java` → Java
- `.fgd` filename contains `_cpp` → C++
- Check `.gen` folder for `.javajet` or `.cppjet` templates
- Fallback: check `FDProject.props`

Load the appropriate pattern file:
- Java → `references/usage-patterns/java.md`
- C++ → `references/usage-patterns/cpp.md` (placeholder — patterns pending)

### Step 4: Code Generation

Apply the usage pattern with concrete values from the detail file:
- Replace `{PluginName}` with actual plugin name (e.g., `GPSPlugin`)
- Replace `{SignalName}` with actual signal name (e.g., `GPSSensorPosition`)
- Replace `{type}` with the signal's data type
- Replace `{machine}` with the machine object variable name

## Notes

- **ISOPGN** has 140 signals and **Implement** has 634 signals — when working with these, ask the user which specific signals they need, then use Grep to search the detail file for matching rows only. Never load the entire file into context
- **Platform_Service** uses method calls, not getter/setter — see its detail file for the different interface format
- All plugin definitions are language-agnostic; only the usage patterns differ between Java and C++
- The `scripts/parse-fgd.py` script can regenerate detail files from any `.fgd` source file
