# Interface JSON Validation Rules

Rules applied by `validate-interface-json.sh`.

## Structural Rules

1. JSON root must be an **array** (`type == "array"`).
2. Each element is an object with `branch` (string) and `config` (string) fields.

## `branch` Validation

- Slash-separated path. Examples: `CAN_AGMO_SteerMotor/Motor_Heartbeat`, `Implement/Connector/connectorgeometry_x`.
- The **first token** (element name) must exactly match one of the `elements[].name` values in `offlineDB.json`.
- The **last token** (interface name) must match an `interfaceName` anywhere in the full tree (all nesting levels) of `offlineDB.json`.

This is a **loose validation**. Accuracy of intermediate path segments is verified by FD itself at runtime. The purpose of this script is **early blocking of obvious typos and invalid paths**.

## `config` Allowed Values

Fixed values:
- `` (empty string)
- `Adhoc`
- `Adhoc/Cyclic`
- `Cyclic`
- `Process`

Pattern allowed:
- `Cyclic/<N>ms` — `<N>` is one or more digits, positive integer (e.g., `Cyclic/100ms`, `Cyclic/250ms`).

## Failure Output Format

On failure, each entry is written to stderr in the following format:

```
branch="..." config="..." reason=<error>
```

Possible `reason` values:
- `missing_branch`
- `unknown_element:<first_token>`
- `unknown_interface:<last_token>`
- `invalid_config`

## Exit Code

- `0`: all entries valid
- `1`: one or more failures (details in stderr)
- `64`: insufficient CLI arguments

## Out of scope

- `enumDetails` value parsing and enum check (separate TODO)
- Intermediate path accuracy validation (delegated to FD)
- `childelements` recursive traversal (YAGNI)
