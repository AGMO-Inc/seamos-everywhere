#!/usr/bin/env bash
# check-ecr-public-auth.sh — defuse stale public.ecr.aws bearer tokens.
#
# Background:
#   public.ecr.aws supports anonymous bearer-token pulls — the docker daemon
#   should fetch a fresh token from https://public.ecr.aws/token/... per pull.
#   But once a host has logged into ANY ECR registry (private or public) via
#   `aws ecr-public get-login-password | docker login`, AWS Toolkit, IAM
#   Identity Center, or `docker-credential-ecr-login` helper, the registry
#   credentials get cached in ~/.docker/config.json under
#   `auths."public.ecr.aws"`. That entry typically holds a 12h-TTL token that
#   docker will keep using as `Authorization: Bearer ...` until it's manually
#   removed — even after expiry, even though anonymous fallback would work.
#
#   Result: `docker pull public.ecr.aws/...` returns 403 Forbidden on what is
#   genuinely a public image. SeamOS skills that depend on ECR public images
#   (create-project, run-app --via-fd-cli, build-fif) all hit this.
#
# Usage (called from a skill before its first docker pull):
#   bash skills/shared-references/scripts/check-ecr-public-auth.sh           # warn-only
#   bash skills/shared-references/scripts/check-ecr-public-auth.sh --auto-clean
#
# Exit codes:
#   0  OK — no stale entry, OR cleaned successfully (--auto-clean), OR config absent
#   2  stale entry detected, --auto-clean NOT requested (caller decides)
#   64 usage error
#
# Output (stdout):
#   STATUS_OK       — config absent or no stale entry
#   STATUS_WARN: stale public.ecr.aws auth detected (...)
#   STATUS_OK: cleaned stale public.ecr.aws auth (--auto-clean)

set -uo pipefail

AUTO_CLEAN=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --auto-clean) AUTO_CLEAN=1 ;;
    --quiet)      QUIET=1 ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 64
      ;;
  esac
done

log()  { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

CFG="${HOME}/.docker/config.json"
if [[ ! -f "$CFG" ]]; then
  log "STATUS_OK"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  # Without jq we can't safely parse/edit JSON — warn but don't block.
  warn "jq not found — cannot inspect ${CFG} for stale public.ecr.aws auth. If a docker pull from public.ecr.aws/ returns 403, manually run: jq 'del(.auths.\"public.ecr.aws\")' ${CFG} > /tmp/c.json && mv /tmp/c.json ${CFG}"
  log "STATUS_OK"
  exit 0
fi

# Detect entry presence.
HAS_ENTRY="$(jq -r '
  if (.auths // {}) | has("public.ecr.aws") then "yes" else "no" end
' "$CFG" 2>/dev/null || echo "no")"

if [[ "$HAS_ENTRY" != "yes" ]]; then
  log "STATUS_OK"
  exit 0
fi

# Stale entry present.
if [[ $AUTO_CLEAN -eq 1 ]]; then
  TMP="$(mktemp)"
  if jq 'del(.auths."public.ecr.aws")' "$CFG" > "$TMP" 2>/dev/null && [[ -s "$TMP" ]]; then
    # Atomic replace.
    mv "$TMP" "$CFG"
    log "STATUS_OK: cleaned stale public.ecr.aws auth from $CFG (anonymous pulls will resume)"
    exit 0
  else
    rm -f "$TMP"
    warn "auto-clean failed: jq edit on $CFG produced no output. Manual fix: jq 'del(.auths.\"public.ecr.aws\")' $CFG > /tmp/c.json && mv /tmp/c.json $CFG"
    exit 2
  fi
fi

# Warn-only mode.
warn "stale ECR public auth detected in $CFG. This typically causes 403 Forbidden on docker pull public.ecr.aws/* images even though the images are public."
warn "Fix (one-time):"
warn "  jq 'del(.auths.\"public.ecr.aws\")' $CFG > /tmp/c.json && mv /tmp/c.json $CFG"
warn "Or rerun this skill with --clean-ecr-auth to apply automatically."
log "STATUS_WARN: stale public.ecr.aws auth in $CFG (run with --auto-clean to fix)"
exit 2
