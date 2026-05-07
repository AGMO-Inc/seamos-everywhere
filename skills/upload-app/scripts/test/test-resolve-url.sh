#!/usr/bin/env bash
# Unit tests for resolve-marketplace-url.sh — A3 multi-source URL discovery.
set -uo pipefail

TMPDIR=$(mktemp -d /tmp/seamos-test-resolve-url-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

RESOLVER="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/upload-app/scripts/resolve-marketplace-url.sh"
[[ -x "$RESOLVER" ]] || chmod +x "$RESOLVER"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" got="$2" expected="$3"
  if [[ "$got" == "$expected" ]]; then
    PASS=$((PASS+1)); echo "  PASS ($name)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL ($name): expected '$expected', got '$got'"
  fi
}

run() {
  local dir="$1"; shift
  local got rc
  if got="$(env "$@" bash "$RESOLVER" "$dir" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  printf '%s\n%s\n' "$got" "$rc"
}

# Case 1: .seamos-workspace.json with endpointUrl wins, /mcp suffix stripped.
mkdir -p "$TMPDIR/c1"
cat > "$TMPDIR/c1/.seamos-workspace.json" <<'EOF'
{"schemaVersion":1,"marketplace":{"endpoint":"dev","endpointUrl":"https://dev.marketplace-api.seamos.io/mcp"}}
EOF
got_full="$(run "$TMPDIR/c1" -)"
got="$(printf '%s' "$got_full" | head -1)"
rc="$(printf '%s' "$got_full" | tail -1)"
assert_eq "case1: workspace JSON wins"      "$got" "https://dev.marketplace-api.seamos.io"
assert_eq "case1: rc=0"                     "$rc"  "0"

# Case 2: workspace JSON absent, .mcp.json (HTTP url field) wins.
mkdir -p "$TMPDIR/c2"
cat > "$TMPDIR/c2/.mcp.json" <<'EOF'
{"mcpServers":{"seamos-marketplace":{"url":"http://localhost:8088/mcp"}}}
EOF
got_full="$(run "$TMPDIR/c2" -)"
got="$(printf '%s' "$got_full" | head -1)"
rc="$(printf '%s' "$got_full" | tail -1)"
assert_eq "case2: .mcp.json url wins"       "$got" "http://localhost:8088"
assert_eq "case2: rc=0"                     "$rc"  "0"

# Case 3: .mcp.json (stdio + mcp-remote args) → fallback to last positional URL arg.
mkdir -p "$TMPDIR/c3"
cat > "$TMPDIR/c3/.mcp.json" <<'EOF'
{"mcpServers":{"seamos-marketplace":{"type":"stdio","command":"npx","args":["mcp-remote","https://dev.marketplace-api.seamos.io/mcp"]}}}
EOF
got_full="$(run "$TMPDIR/c3" -)"
got="$(printf '%s' "$got_full" | head -1)"
rc="$(printf '%s' "$got_full" | tail -1)"
assert_eq "case3: .mcp.json stdio args fallback" "$got" "https://dev.marketplace-api.seamos.io"
assert_eq "case3: rc=0"                          "$rc"  "0"

# Case 4: both files absent, env var present.
mkdir -p "$TMPDIR/c4"
got_full="$(run "$TMPDIR/c4" CLAUDE_MCP_SEAMOS_URL=https://custom.example.com/mcp)"
got="$(printf '%s' "$got_full" | head -1)"
rc="$(printf '%s' "$got_full" | tail -1)"
assert_eq "case4: env var fallback"          "$got" "https://custom.example.com"
assert_eq "case4: rc=0"                      "$rc"  "0"

# Case 5: nothing → exit 64 with remediation.
mkdir -p "$TMPDIR/c5"
got_full="$(run "$TMPDIR/c5" -)"
rc="$(printf '%s' "$got_full" | tail -1)"
remed_seen=0
printf '%s' "$got_full" | grep -q "invoke the \`setup\` skill" && remed_seen=1
assert_eq "case5: rc=64"                     "$rc" "64"
assert_eq "case5: remediation hint surfaced" "$remed_seen" "1"

# Case 6: workspace JSON precedence — endpointUrl wins over .mcp.json url.
mkdir -p "$TMPDIR/c6"
cat > "$TMPDIR/c6/.seamos-workspace.json" <<'EOF'
{"schemaVersion":1,"marketplace":{"endpoint":"dev","endpointUrl":"https://from-workspace.example/mcp"}}
EOF
cat > "$TMPDIR/c6/.mcp.json" <<'EOF'
{"mcpServers":{"seamos-marketplace":{"url":"https://from-mcpjson.example/mcp"}}}
EOF
got_full="$(run "$TMPDIR/c6" -)"
got="$(printf '%s' "$got_full" | head -1)"
assert_eq "case6: workspace beats .mcp.json" "$got" "https://from-workspace.example"

echo ""
echo "[A3 URL resolver] PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
