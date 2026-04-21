#!/bin/bash
# run_all.sh — Run all create-project skill tests and aggregate results.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0

run_suite() {
  local name="$1"
  local script="$2"

  echo ""
  echo "─────────────────────────────────────────────────────"
  echo " Running: $name"
  echo "─────────────────────────────────────────────────────"

  if [[ ! -x "$script" ]]; then
    echo "SKIP: $script not executable"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
    return
  fi

  set +e
  bash "$script"
  local rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    TOTAL_PASS=$((TOTAL_PASS+1))
    echo "→ $name: PASS"
  else
    TOTAL_FAIL=$((TOTAL_FAIL+1))
    echo "→ $name: FAIL (exit $rc)"
  fi
}

run_suite "test_cli.sh (D.5)" "${TESTS_DIR}/test_cli.sh"
run_suite "test_interface_synth.sh (E.4)" "${TESTS_DIR}/test_interface_synth.sh"

echo ""
echo "═════════════════════════════════════════════════════"
echo " Total: ${TOTAL_PASS} passed, ${TOTAL_FAIL} failed"
echo "═════════════════════════════════════════════════════"

[[ $TOTAL_FAIL -eq 0 ]] && exit 0 || exit 1
