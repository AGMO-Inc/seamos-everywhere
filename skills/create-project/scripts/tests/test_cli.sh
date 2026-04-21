#!/bin/bash
# test_cli.sh — Dry-run based smoke tests for create-project.sh.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/../../../.." && pwd)"
CP="${REPO_ROOT}/skills/create-project/scripts/create-project.sh"
SAMPLE="${REPO_ROOT}/skills/create-project/references/interface-sample.json"

PASS=0
FAIL=0

run_case() {
  local name="$1"; shift
  local expected_code="$1"; shift
  local expected_regex="${1:-}"; shift || true

  local out err rc
  set +e
  out=$( "$@" 2>/tmp/test_cli.err )
  rc=$?
  err=$(cat /tmp/test_cli.err)
  set -e

  local ok=1
  if [[ "$rc" != "$expected_code" ]]; then
    echo "FAIL: $name — expected exit=$expected_code, got $rc"
    echo "  stdout: $out"
    echo "  stderr: $err"
    ok=0
  fi
  if [[ -n "$expected_regex" && $ok -eq 1 ]]; then
    if ! echo "${out}${err}" | grep -qE "$expected_regex"; then
      echo "FAIL: $name — output did not match: $expected_regex"
      echo "  output: ${out} | ${err}"
      ok=0
    fi
  fi
  if [[ $ok -eq 1 ]]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
}

# Case 1: --help
run_case "help" "0" "Options:" bash "$CP" --help

# Case 2: no args
run_case "no args" "64" "" bash "$CP"

# Case 3: invalid operation
run_case "invalid operation" "64" "invalid --operation" bash "$CP" \
  --project-name "Foo" --operation "INVALID_OP" --interface-json "$SAMPLE" --dry-run

# Case 4: valid dry-run
TMPWS=$(mktemp -d)
run_case "valid dry-run" "0" "dry-run" bash "$CP" \
  --project-name "Foo" --interface-json "$SAMPLE" --workspace "$TMPWS" --dry-run
rm -rf "$TMPWS"

# Case 5: nonexistent interface-json path
TMPWS=$(mktemp -d)
run_case "missing interface-json" "1" "not readable" bash "$CP" \
  --project-name "Foo" --interface-json "/nonexistent/path/iface.json" --workspace "$TMPWS" --dry-run
rm -rf "$TMPWS"

echo ""
echo "Total: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
