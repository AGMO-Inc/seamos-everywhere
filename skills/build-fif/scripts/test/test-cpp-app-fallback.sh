#!/usr/bin/env bash
#
# test-cpp-app-fallback.sh — Unit tests for build-fif.sh A2 fix.
#
# 0.7.1 의 FD Headless 가 신규 프로젝트에 잘못된 'App' suffix 가 붙은
# CPP_APP_PATH 를 FDProject.props 에 기록하는 회귀가 있었다. 본 테스트는
# build-fif.sh 의 fallback 경로가:
#   (a) props 의 CPP_APP_PATH 가 가리키는 디렉토리가 존재하면 그대로 사용 (no WARN)
#   (b) 부재하면 PROJ_ROOT 하위에서 CMakeLists.txt 보유 디렉토리 자동 검색 + WARN
#   (c) 검색해도 못 찾으면 ERROR 로 종료
# 세 branch 가 모두 의도대로 동작하는지 검증.
set -uo pipefail

TMPDIR=$(mktemp -d /tmp/seamos-test-cpp-app-fallback-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# Standalone resolver mirroring build-fif.sh's CPP_APP_PATH branch.
RESOLVER="$TMPDIR/resolve.sh"
cat > "$RESOLVER" <<'RESOLVER_EOF'
#!/usr/bin/env bash
set -uo pipefail
PROJ_ROOT="$1"
FEATURE_NAME="$2"
FSP_PATH="$PROJ_ROOT/com.bosch.fsp.$FEATURE_NAME"

CPP_APP_DIR=""
FDPROPS="$FSP_PATH/FDProject.props"
if [ -f "$FDPROPS" ]; then
    CPP_APP_DIR=$(grep "^CPP_APP_PATH=" "$FDPROPS" 2>/dev/null \
      | sed 's/^CPP_APP_PATH="\{0,1\}cmake|\{0,1\}//' \
      | sed 's/"\{0,1\}$//')
fi

APP_PATH=""
if [ -n "$CPP_APP_DIR" ] && [ -d "$PROJ_ROOT/$CPP_APP_DIR" ] && [ -f "$PROJ_ROOT/$CPP_APP_DIR/CMakeLists.txt" ]; then
    APP_PATH="$PROJ_ROOT/$CPP_APP_DIR"
fi

if [ -z "$APP_PATH" ]; then
    for d in "$PROJ_ROOT"/*/; do
        dname=$(basename "$d")
        [ "$dname" = "com.bosch.fsp.$FEATURE_NAME" ] && continue
        [ "$dname" = "${FEATURE_NAME}_CPP_SDK" ] && continue
        [ "$dname" = "output" ] && continue
        if [ -f "$d/CMakeLists.txt" ]; then
            APP_PATH="${d%/}"
            break
        fi
    done

    if [ -n "$APP_PATH" ]; then
        if [ -n "$CPP_APP_DIR" ]; then
            echo "WARN: FDProject.props CPP_APP_PATH=\"cmake|$CPP_APP_DIR\" points to non-existent directory ($PROJ_ROOT/$CPP_APP_DIR)."
            echo "WARN: auto-resolved C++ app directory → $APP_PATH"
        fi
    else
        echo "ERROR: C++ app directory not found."
        exit 1
    fi
fi
echo "APP_PATH=$APP_PATH"
RESOLVER_EOF
chmod +x "$RESOLVER"

PASS=0
FAIL=0

run_case() {
  local name="$1" feature="$2" expect_app_basename="$3" expect_warn="$4"
  local out rc got_app got_warn

  if out="$(bash "$RESOLVER" "$TMPDIR/$name" "$feature" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi

  got_app="$(printf '%s\n' "$out" | grep -E '^APP_PATH=' | head -1 | cut -d= -f2-)"
  got_warn=0
  printf '%s\n' "$out" | grep -q "WARN: .*non-existent" && got_warn=1

  local case_ok=1
  if [[ "$expect_app_basename" == "ERROR" ]]; then
    [[ $rc -ne 0 ]] || { echo "  FAIL ($name): expected ERROR exit, got rc=$rc"; case_ok=0; }
  else
    [[ "$got_app" == "$TMPDIR/$name/$expect_app_basename" ]] \
      || { echo "  FAIL ($name): expected APP_PATH=$expect_app_basename, got '$got_app'"; case_ok=0; }
  fi
  if [[ "$expect_warn" == "1" ]]; then
    [[ $got_warn -eq 1 ]] \
      || { echo "  FAIL ($name): expected WARN about non-existent CPP_APP_PATH, got none"; case_ok=0; }
  else
    [[ $got_warn -eq 0 ]] \
      || { echo "  FAIL ($name): unexpected WARN about non-existent CPP_APP_PATH"; case_ok=0; }
  fi

  if [[ $case_ok -eq 1 ]]; then
    PASS=$((PASS+1)); echo "  PASS ($name)"
  else
    FAIL=$((FAIL+1))
    echo "    --- output ---"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

# Case 1: stale CPP_APP_PATH with App suffix (0.7.1 FD bug) — fallback finds + WARN.
mkdir -p "$TMPDIR/case1/com.bosch.fsp.myproj" \
         "$TMPDIR/case1/myproj_CPP_SDK" \
         "$TMPDIR/case1/myproj"
echo "cmake_minimum_required(VERSION 3.10)" > "$TMPDIR/case1/myproj/CMakeLists.txt"
cat > "$TMPDIR/case1/com.bosch.fsp.myproj/FDProject.props" <<'EOF'
PROJECT_NAME=myproj
CPP_APP_PATH="cmake|myprojApp"
EOF
run_case "case1" "myproj" "myproj" "1"

# Case 2: correct CPP_APP_PATH — uses props value, no WARN.
mkdir -p "$TMPDIR/case2/com.bosch.fsp.myproj" \
         "$TMPDIR/case2/myproj_CPP_SDK" \
         "$TMPDIR/case2/myproj"
echo "cmake_minimum_required(VERSION 3.10)" > "$TMPDIR/case2/myproj/CMakeLists.txt"
cat > "$TMPDIR/case2/com.bosch.fsp.myproj/FDProject.props" <<'EOF'
PROJECT_NAME=myproj
CPP_APP_PATH="cmake|myproj"
EOF
run_case "case2" "myproj" "myproj" "0"

# Case 3: missing CPP_APP_PATH entirely — auto-search finds it, no WARN
# (WARN fires only when props pointed somewhere wrong, not when it was absent).
mkdir -p "$TMPDIR/case3/com.bosch.fsp.myproj" \
         "$TMPDIR/case3/myproj_CPP_SDK" \
         "$TMPDIR/case3/myproj"
echo "cmake_minimum_required(VERSION 3.10)" > "$TMPDIR/case3/myproj/CMakeLists.txt"
echo "PROJECT_NAME=myproj" > "$TMPDIR/case3/com.bosch.fsp.myproj/FDProject.props"
run_case "case3" "myproj" "myproj" "0"

# Case 4: no app dir anywhere — must ERROR.
mkdir -p "$TMPDIR/case4/com.bosch.fsp.myproj" \
         "$TMPDIR/case4/myproj_CPP_SDK"
echo "PROJECT_NAME=myproj" > "$TMPDIR/case4/com.bosch.fsp.myproj/FDProject.props"
run_case "case4" "myproj" "ERROR" "0"

echo ""
echo "[A2 fallback] PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
