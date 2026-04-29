#!/usr/bin/env bash
#
# test-disk-policy.sh — Unit tests for build-fif.sh disk_packaging_policy()
#
# Validates:
#   (a) apply mode emits "Excluded N files from disk/, retained M files in disk/seed/"
#   (b) apply mode keeps disk/seed/ files and removes disk/cache/, disk/persistence/, etc.
#   (c) --dry-run emits "would exclude ..." and performs no deletion
#   (d) absent disk/ directory yields "(no disk/ directory)"
#
# Sandbox: all mock workspaces live under mktemp -d /tmp/seamos-test-disk-XXXXXX
# and are removed via trap on EXIT. No Docker. No user-home writes.
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/seamos-test-disk-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

BUILD_FIF_SH="/Users/sungmincho/Desktop/Backend/seamos-everywhere/skills/build-fif/scripts/build-fif.sh"

# Extract only the disk_packaging_policy() function body to avoid triggering
# build-fif.sh's main flow on source. The function contains no nested function
# definitions, so the awk range terminates at the first top-level "}" line.
FUNC_FILE="$TMPDIR/func.sh"
awk '/^disk_packaging_policy\(\)/,/^}$/' "$BUILD_FIF_SH" > "$FUNC_FILE"

if [[ ! -s "$FUNC_FILE" ]]; then
  echo "FAIL: failed to extract disk_packaging_policy from $BUILD_FIF_SH"
  exit 1
fi

# shellcheck disable=SC1090
source "$FUNC_FILE"

if ! type disk_packaging_policy >/dev/null 2>&1; then
  echo "FAIL: disk_packaging_policy not sourced as function"
  exit 1
fi

PASS_COUNT=0
FAIL_LIST=()

assert() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL_LIST+=("$name")
  fi
}

# ─── (a) apply mode — stdout format ─────────────────────────────────────────
mkdir -p "$TMPDIR/myapp/disk/seed" "$TMPDIR/myapp/disk/cache" "$TMPDIR/myapp/disk/persistence"
echo '{}' > "$TMPDIR/myapp/disk/seed/init.json"
echo 'cache' > "$TMPDIR/myapp/disk/cache/foo.bin"
echo 'runtime' > "$TMPDIR/myapp/disk/persistence/runtime.db"

OUT=$(disk_packaging_policy "$TMPDIR/myapp")
assert "(a) apply mode stdout format" "$OUT" "Excluded 2 files from disk/, retained 1 files in disk/seed/"

# ─── (b) only disk/seed/ files retained ─────────────────────────────────────
KEPT=$(find "$TMPDIR/myapp/disk" -type f | wc -l | tr -d ' ')
assert "(b) only disk/seed/ files retained" "$KEPT" "1"
if [[ ! -f "$TMPDIR/myapp/disk/seed/init.json" ]]; then FAIL_LIST+=("(b) init.json missing"); fi
if [[ -f "$TMPDIR/myapp/disk/cache/foo.bin" ]]; then FAIL_LIST+=("(b) cache file not removed"); fi
if [[ -f "$TMPDIR/myapp/disk/persistence/runtime.db" ]]; then FAIL_LIST+=("(b) persistence file not removed"); fi

# ─── (c) dry-run — count only, no deletion ──────────────────────────────────
mkdir -p "$TMPDIR/myapp2/disk/seed" "$TMPDIR/myapp2/disk/cache"
echo 'a' > "$TMPDIR/myapp2/disk/seed/a.json"
echo 'b' > "$TMPDIR/myapp2/disk/seed/b.json"
echo 'c' > "$TMPDIR/myapp2/disk/cache/c.bin"

OUT2=$(disk_packaging_policy --dry-run "$TMPDIR/myapp2")
assert "(c) dry-run stdout format" "$OUT2" "would exclude 1 files from disk/, would retain 2 files in disk/seed/"

KEPT2=$(find "$TMPDIR/myapp2/disk" -type f | wc -l | tr -d ' ')
assert "(c) dry-run does not delete" "$KEPT2" "3"

# ─── (d) absent disk/ directory ─────────────────────────────────────────────
mkdir -p "$TMPDIR/myapp3"
OUT3=$(disk_packaging_policy "$TMPDIR/myapp3")
assert "(d) absent disk/ message" "$OUT3" "(no disk/ directory)"

# ─── Summary ────────────────────────────────────────────────────────────────
if [[ ${#FAIL_LIST[@]} -eq 0 ]]; then
  echo ""
  echo "PASS ($PASS_COUNT assertions)"
  exit 0
else
  echo ""
  echo "FAIL"
  for f in "${FAIL_LIST[@]}"; do echo "  - $f"; done
  exit 1
fi
