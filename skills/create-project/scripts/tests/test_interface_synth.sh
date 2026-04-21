#!/bin/bash
# test_interface_synth.sh — Unit test for lib/interface.sh synth_interface_json().
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${TESTS_DIR}/../lib/interface.sh"
FIXTURE="${TESTS_DIR}/fixtures/offlineDB.small.json"

# shellcheck disable=SC1090
source "$LIB"

PASS=0
FAIL=0
assert() {
  local desc="$1"; shift
  if "$@"; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc" >&2; FAIL=$((FAIL+1))
  fi
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SEL="${TMPDIR}/selections.txt"
OUT="${TMPDIR}/out.json"

cat > "$SEL" <<'EOF'
# element_idx  interface_idx  rate_override
0 0 -
0 1 -
1 0 -
2 0 100
2 1 200
EOF

synth_interface_json "$FIXTURE" "$SEL" "$OUT"

# Array
assert "output is a JSON array" bash -c "jq -e 'type == \"array\"' '$OUT' >/dev/null"

# 5 entries
N=$(jq 'length' "$OUT")
assert "5 entries generated (got $N)" test "$N" = "5"

# Motor_Heartbeat → Adhoc (default)
assert "Motor_Heartbeat → Adhoc" bash -c "jq -e '.[] | select(.branch == \"CAN_AGMO_SteerMotor/Motor_Heartbeat\") | .config == \"Adhoc\"' '$OUT' >/dev/null"

# Cloud_Download → "" (empty updateRate)
assert "Cloud_Download → empty config" bash -c "jq -e '.[] | select(.branch == \"Platform_Service/Cloud_Download\") | .config == \"\"' '$OUT' >/dev/null"

# connectorgeometry_x → Cyclic/100ms (rate override)
assert "connectorgeometry_x → Cyclic/100ms" bash -c "jq -e '.[] | select(.branch == \"Implement/connectorgeometry_x\") | .config == \"Cyclic/100ms\"' '$OUT' >/dev/null"

# connectorgeometry_y → Cyclic/200ms
assert "connectorgeometry_y → Cyclic/200ms" bash -c "jq -e '.[] | select(.branch == \"Implement/connectorgeometry_y\") | .config == \"Cyclic/200ms\"' '$OUT' >/dev/null"

# Cyclic pattern grep
CYCLIC_COUNT=$(jq -r '.[].config' "$OUT" | grep -cE 'Cyclic/[0-9]+ms' || true)
assert "≥1 Cyclic/<N>ms entry" test "$CYCLIC_COUNT" -ge "1"

echo ""
echo "Total: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
