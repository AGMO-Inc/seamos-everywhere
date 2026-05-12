#!/bin/bash
# edit-plugins.sh — Add or remove plugin interfaces on an existing SeamOS
# project, then chain create-project --regen-fsp-only and regen-sdk-app so the
# change reaches the running app.
#
# Usage:
#   edit-plugins.sh inspect
#   edit-plugins.sh apply --patch <patch.json> [--reset-tests] [--image-tag TAG]
#                                              [--dry-run] [--no-regen]
#
# Subcommands:
#   inspect            Print current SSOT state as JSON.
#   apply              Apply add/remove patch, validate, regen.
#
# Flags (apply):
#   --patch FILE       JSON describing { add: [...], remove: [...] }   (required)
#   --reset-tests      Pass --reset-tests through to regen-sdk-app
#                      (regenerates .gen.tests/ to match new interfaces).
#   --image-tag TAG    Override FD Headless docker image. Passed through to
#                      both create-project --regen-fsp-only and regen-sdk-app
#                      so the chained regens stay on the same image. Also
#                      respected via env: SEAMOS_FD_IMAGE.
#   --dry-run          Validate + print diff + planned regen commands; no writes.
#   --no-regen         Test-harness only — apply patch + validate but skip
#                      FSP / SDK regen. Real users must NEVER pass this; it
#                      defeats the entire purpose of the skill.
#
# Exit codes:
#   0   success
#   1   regen failure (SSOT restored from backup)
#   2   validation failure
#   3   docker timeout during regen
#   64  usage error
#   69  docker image unavailable
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$(cd "$SKILL_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILLS_DIR/.." && pwd)"

CREATE_PROJECT_SH="$SKILLS_DIR/create-project/scripts/create-project.sh"
REGEN_SDK_APP_SH="$SKILLS_DIR/regen-sdk-app/scripts/regen-sdk-app.sh"
VALIDATE_SH="$SKILLS_DIR/create-project/scripts/validate-interface-json.sh"

# ─── find_user_root (mirror create-project / regen-sdk-app) ────────────────
find_user_root() {
  local dir
  dir="$(pwd -P)"
  while true; do
    if [[ -f "$dir/.mcp.json" ]]; then
      echo "$dir"; return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  if [[ "${SEAMOS_ALLOW_PWD_FALLBACK:-0}" == "1" ]]; then
    echo "WARN: no .mcp.json found upward from \$PWD — using \$PWD (test fallback)" >&2
    pwd -P; return 0
  fi
  echo "ERROR: no .mcp.json found upward from \$PWD" >&2
  echo "       edit-plugins requires a USER_ROOT marked by .mcp.json." >&2
  return 64
}

# ─── acquire_context_lock (flock → mkdir fallback) ─────────────────────────
acquire_context_lock() {
  local target="$1"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"${target}.lock"
    flock -x 9
    return 0
  fi
  local lockdir="${target}.lock.d"
  local tries=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries + 1))
    if (( tries > 300 )); then
      echo "ERROR: lock timeout on $lockdir" >&2
      return 1
    fi
    sleep 0.1
  done
  trap 'rmdir "'"$lockdir"'" 2>/dev/null || true' EXIT
  return 0
}

# ─── resolve_offlinedb (mirror validate-interface-json.sh) ─────────────────
resolve_offlinedb() {
  if [[ -n "${SEAMOS_OFFLINEDB_PATH:-}" && -f "${SEAMOS_OFFLINEDB_PATH}" ]]; then
    echo "${SEAMOS_OFFLINEDB_PATH}"; return 0
  fi
  if [[ -f "$SKILLS_DIR/create-project/assets/offlineDB.json" ]]; then
    echo "$SKILLS_DIR/create-project/assets/offlineDB.json"; return 0
  fi
  if [[ -f "$REPO_ROOT/ref/00_HeadlessFD/offlineDB.json" ]]; then
    echo "$REPO_ROOT/ref/00_HeadlessFD/offlineDB.json"; return 0
  fi
  return 1
}

# ─── load_context — read project name + ssot path from .seamos-context.json ─
load_context() {
  local user_root="$1"
  local ctx="$user_root/.seamos-context.json"
  if [[ ! -f "$ctx" ]]; then
    echo "ERROR: $ctx not found." >&2
    echo "       Run 'create-project' first; this skill mutates an existing project." >&2
    return 64
  fi
  local name
  name="$(jq -r '.last_project.name // empty' "$ctx")"
  if [[ -z "$name" ]]; then
    echo "ERROR: .seamos-context.json missing last_project.name" >&2
    return 64
  fi
  echo "$name"
}

# ─── inspect subcommand ────────────────────────────────────────────────────
cmd_inspect() {
  local user_root project_name ssot
  user_root="$(find_user_root)" || exit $?
  project_name="$(load_context "$user_root")" || exit $?
  ssot="$user_root/${project_name}-interface.json"

  if [[ ! -f "$ssot" ]]; then
    echo "ERROR: SSOT not found at $ssot" >&2
    echo "       Run 'create-project --regen-fsp-only' to materialize it from the workspace." >&2
    exit 64
  fi

  jq -n \
    --arg user_root "$user_root" \
    --arg project_name "$project_name" \
    --arg ssot_path "$ssot" \
    --slurpfile entries "$ssot" \
    '{
      user_root: $user_root,
      project_name: $project_name,
      ssot_path: $ssot_path,
      current_entries: ($entries[0]),
      current_plugins: ($entries[0] | map(.branch | split("/")[0]) | unique)
    }'
}

# ─── apply subcommand ──────────────────────────────────────────────────────
cmd_apply() {
  local patch_file=""
  local reset_tests=0
  local dry_run=0
  local no_regen=0
  local image_tag="${SEAMOS_FD_IMAGE:-}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --patch)        patch_file="$2"; shift 2 ;;
      --reset-tests)  reset_tests=1; shift ;;
      --image-tag)    image_tag="$2"; shift 2 ;;
      --dry-run)      dry_run=1; shift ;;
      --no-regen)     no_regen=1; shift ;;
      *)
        echo "ERROR: unknown flag: $1" >&2
        exit 64 ;;
    esac
  done

  [[ -n "$patch_file" ]] || { echo "ERROR: --patch <file> required" >&2; exit 64; }
  [[ -r "$patch_file" ]] || { echo "ERROR: patch file unreadable: $patch_file" >&2; exit 64; }

  # Validate patch shape
  if ! jq -e '
    type == "object"
    and ((has("add")    | not) or (.add    | type == "array"))
    and ((has("remove") | not) or (.remove | type == "array"))
  ' "$patch_file" >/dev/null 2>&1; then
    echo "ERROR: patch must be an object with optional 'add' and 'remove' arrays" >&2
    exit 2
  fi

  # Reject contradictory branches (in both add and remove)
  local conflicts
  conflicts="$(jq -r '
    ((.add // []) | map(.branch)) as $a
    | ((.remove // []) | map(.branch)) as $r
    | $a | map(select(. as $x | $r | index($x))) | .[]
  ' "$patch_file")"
  if [[ -n "$conflicts" ]]; then
    echo "ERROR: patch contains branches in both add and remove:" >&2
    echo "$conflicts" | sed 's/^/  - /' >&2
    exit 2
  fi

  local user_root project_name ssot
  user_root="$(find_user_root)" || exit $?
  project_name="$(load_context "$user_root")" || exit $?
  ssot="$user_root/${project_name}-interface.json"

  [[ -f "$ssot" ]] || { echo "ERROR: SSOT not found at $ssot" >&2; exit 64; }

  # Build the proposed new SSOT in memory
  local new_ssot_json
  new_ssot_json="$(jq \
    --slurpfile patch "$patch_file" \
    '
      ($patch[0].add // []) as $add
      | ($patch[0].remove // []) as $rem
      | ($rem | map(.branch)) as $rem_branches
      | (map(select(.branch as $b | ($rem_branches | index($b) | not))))
      | . + ($add | map({branch: .branch, config: (.config // "")}))
    ' "$ssot")"

  # Soft warn for remove targets that don't exist
  local missing_removes
  missing_removes="$(jq -r --slurpfile cur "$ssot" '
    ($cur[0] | map(.branch)) as $existing
    | (.remove // []) | map(select(.branch as $b | $existing | index($b) | not)) | .[].branch
  ' "$patch_file")"
  if [[ -n "$missing_removes" ]]; then
    echo "WARN: these removed branches were not in the SSOT (no-op):" >&2
    echo "$missing_removes" | sed 's/^/  - /' >&2
  fi

  # Refuse empty result
  local new_len
  new_len="$(echo "$new_ssot_json" | jq 'length')"
  if [[ "$new_len" == "0" ]]; then
    echo "ERROR: patch would empty the SSOT (zero interfaces). Refusing." >&2
    exit 2
  fi

  # Validate against offlineDB
  local offlinedb
  offlinedb="$(resolve_offlinedb)" || {
    echo "ERROR: offlineDB.json not resolvable" >&2
    exit 2
  }

  if ! echo "$new_ssot_json" | bash "$VALIDATE_SH" - "$offlinedb"; then
    echo "ERROR: validation failed against offlineDB" >&2
    exit 2
  fi

  # Compute diff
  local tmp_new
  tmp_new="$(mktemp)"
  echo "$new_ssot_json" | jq -S . > "$tmp_new"
  local diff_out
  diff_out="$(diff -u <(jq -S . "$ssot") "$tmp_new" || true)"

  echo "── proposed SSOT diff ($(basename "$ssot")) ──"
  if [[ -z "$diff_out" ]]; then
    echo "(no change)"
  else
    echo "$diff_out"
  fi
  echo "── end diff ──"

  echo
  echo "── planned regen sequence ──"
  echo -n "  1. create-project --project-name $project_name --regen-fsp-only"
  [[ -n "$image_tag" ]] && echo -n " --image-tag $image_tag"
  echo
  echo -n "  2. regen-sdk-app"
  [[ $reset_tests -eq 1 ]] && echo -n " --reset-tests"
  [[ -n "$image_tag" ]] && echo -n " --image-tag $image_tag"
  echo
  echo "── end plan ──"

  if [[ $dry_run -eq 1 ]]; then
    rm -f "$tmp_new"
    echo "[dry-run] no changes written"
    exit 0
  fi

  # ── apply ──
  acquire_context_lock "$ssot"

  local stamp
  stamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  local backup="${ssot}.bak.${stamp}"
  cp "$ssot" "$backup"
  mv "$tmp_new" "$ssot"

  echo "✓ SSOT updated (backup: $backup)"

  if [[ $no_regen -eq 1 ]]; then
    echo "[--no-regen] skipping FSP/SDK regen — TEST HARNESS ONLY"
    echo "WARN: in real use, never pass --no-regen — the running app will not see this change." >&2
    exit 0
  fi

  # Step 5: regen FSP
  echo "→ Step 1/2: regenerating FSP from updated interface JSON …"
  local fsp_args=(--project-name "$project_name" --regen-fsp-only)
  [[ -n "$image_tag" ]] && fsp_args+=(--image-tag "$image_tag")
  if ! bash "$CREATE_PROJECT_SH" "${fsp_args[@]}"; then
    echo "ERROR: FSP regen failed — restoring SSOT from $backup" >&2
    cp "$backup" "$ssot"
    exit 1
  fi

  # Step 6: regen SDK skeleton
  echo "→ Step 2/2: merging refreshed SDK hooks into existing app project …"
  local regen_args=()
  [[ $reset_tests -eq 1 ]] && regen_args+=(--reset-tests)
  [[ -n "$image_tag" ]] && regen_args+=(--image-tag "$image_tag")
  if ! bash "$REGEN_SDK_APP_SH" ${regen_args[@]+"${regen_args[@]}"}; then
    echo "ERROR: SDK skeleton regen failed — SSOT and FSP left in updated state." >&2
    echo "       To roll back: cp '$backup' '$ssot' && rerun this skill." >&2
    exit 1
  fi

  # Post-regen sanity: FD's UPDATE_SDK_APP returns success even when it
  # silently skips the SDK merge because the app project lacks customui/.
  # That happens with a fresh CPP project that has no user UI code yet, and
  # leaves stale provider files under <SDK_PROJECT_PATH>/src-gen/nevonex/. The
  # SEVERE log line is the only signal.
  #
  # Layout-aware path resolution: delegate to shared resolve-paths.sh so both
  # Layout A (nested: <USER_ROOT>/<P>/<P>/...) and Layout B (flat:
  # <USER_ROOT>/...) emit accurate absolute paths for sdk_log and the guidance
  # message.
  local RESOLVE_HELPER="$SKILLS_DIR/shared-references/scripts/resolve-paths.sh"
  local APP_PROJECT_PATH="" SDK_PROJECT_PATH=""
  if [[ -f "$RESOLVE_HELPER" ]]; then
    local RESOLVE_OUT
    if RESOLVE_OUT="$(bash "$RESOLVE_HELPER" "$user_root" 2>/dev/null)"; then
      eval "$RESOLVE_OUT"
    fi
  fi
  local sdk_log=""
  if [[ -n "$APP_PROJECT_PATH" ]]; then
    sdk_log="$(dirname "$APP_PROJECT_PATH")/run-sdk-app-update.log"
  fi
  if [[ -n "$sdk_log" && -f "$sdk_log" ]] && grep -q 'SEVERE: App project does not contain the custom ui folder' "$sdk_log"; then
    local stale_dir="${SDK_PROJECT_PATH}/src-gen/nevonex/"
    echo
    echo "WARNING: UPDATE_SDK_APP succeeded but FD reported no customui/ folder under" >&2
    echo "         the app project. The SDK merge was a NO-OP — stale provider files" >&2
    echo "         under ${stale_dir} may still reference removed" >&2
    echo "         plugins, which can break the build." >&2
    echo "         If this project hasn't had any user UI code yet, the safe path is" >&2
    echo "         to start over with create-project (loses no real user code yet)." >&2
    echo "         If user code already exists, manually clean stale src-gen subdirs" >&2
    echo "         under ${stale_dir} that match removed plugin names." >&2
  fi

  echo
  echo "✓ All done. Backup at: $backup"
}

# ─── entrypoint ────────────────────────────────────────────────────────────
main() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 inspect" >&2
    echo "       $0 apply --patch <patch.json> [--reset-tests] [--dry-run] [--no-regen]" >&2
    exit 64
  fi

  local sub="$1"; shift
  case "$sub" in
    inspect) cmd_inspect "$@" ;;
    apply)   cmd_apply   "$@" ;;
    -h|--help)
      sed -n '1,30p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)
      echo "ERROR: unknown subcommand: $sub" >&2
      exit 64 ;;
  esac
}

main "$@"
