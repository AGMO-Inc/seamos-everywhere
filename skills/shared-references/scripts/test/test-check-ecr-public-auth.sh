#!/usr/bin/env bash
# Unit tests for check-ecr-public-auth.sh — A1 stale ECR token defuser.
set -uo pipefail

TMPDIR=$(mktemp -d /tmp/seamos-test-ecr-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

HELPER="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/shared-references/scripts/check-ecr-public-auth.sh"
[[ -x "$HELPER" ]] || chmod +x "$HELPER"

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

# Helper: run check-ecr-public-auth.sh and capture out+rc.
# Sets globals OUT and RC on each call.
run_helper() {
  local home="$1"; shift
  if OUT="$(HOME="$home" bash "$HELPER" "$@" 2>&1)"; then RC=0; else RC=$?; fi
}

# Case 1: no config file → STATUS_OK exit 0
mkdir -p "$TMPDIR/c1"
run_helper "$TMPDIR/c1"
assert_eq "case1: rc=0"        "$RC" "0"
printf '%s\n' "$OUT" | grep -qx 'STATUS_OK' && r=1 || r=0
assert_eq "case1: STATUS_OK"   "$r"  "1"

# Case 2: config without public.ecr.aws → STATUS_OK
mkdir -p "$TMPDIR/c2/.docker"
echo '{"auths":{"index.docker.io":{"auth":"abc"}}}' > "$TMPDIR/c2/.docker/config.json"
run_helper "$TMPDIR/c2"
assert_eq "case2: clean config rc=0" "$RC" "0"

# Case 3: stale entry, warn-only → exit 2
mkdir -p "$TMPDIR/c3/.docker"
echo '{"auths":{"public.ecr.aws":{"auth":"stale"},"index.docker.io":{"auth":"abc"}}}' > "$TMPDIR/c3/.docker/config.json"
run_helper "$TMPDIR/c3"
assert_eq "case3: warn-only rc=2" "$RC" "2"
printf '%s\n' "$OUT" | grep -q "STATUS_WARN: stale public.ecr.aws auth" && r=1 || r=0
assert_eq "case3: STATUS_WARN line surfaced" "$r" "1"
# File untouched (warn-only).
remained="$(jq -e '.auths | has("public.ecr.aws")' "$TMPDIR/c3/.docker/config.json" >/dev/null 2>&1 && echo true || echo false)"
assert_eq "case3: warn-only does not mutate config" "$remained" "true"

# Case 4: stale entry, --auto-clean → entry removed, exit 0
mkdir -p "$TMPDIR/c4/.docker"
echo '{"auths":{"public.ecr.aws":{"auth":"stale"},"index.docker.io":{"auth":"abc"}}}' > "$TMPDIR/c4/.docker/config.json"
run_helper "$TMPDIR/c4" --auto-clean
assert_eq "case4: auto-clean rc=0" "$RC" "0"
remained="$(jq -e '.auths | has("public.ecr.aws")' "$TMPDIR/c4/.docker/config.json" >/dev/null 2>&1 && echo true || echo false)"
assert_eq "case4: public.ecr.aws removed" "$remained" "false"
# Other entries preserved.
others="$(jq -e '.auths | has("index.docker.io")' "$TMPDIR/c4/.docker/config.json" >/dev/null 2>&1 && echo true || echo false)"
assert_eq "case4: other auth entries preserved" "$others" "true"

echo ""
echo "[ECR helper] PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
