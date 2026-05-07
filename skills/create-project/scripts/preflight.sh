#!/bin/bash
# preflight.sh — Host compatibility check for create-project skill.
#
# Verifies:
#   - Required CLI tools: docker, jq, shasum|sha256sum, timeout|gtimeout
#   - macOS Apple Silicon: Rosetta 2 installed + Docker Desktop uses Rosetta
#   - Windows: only runs under WSL2 or Git Bash (detected via uname)
#
# Usage:
#   bash scripts/preflight.sh [--check-only]
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed (error messages printed to stderr)
#   64 — invalid arguments

set -euo pipefail

CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: preflight.sh [--check-only]

Verifies host environment for the create-project skill.

Options:
  --check-only   Print diagnostics without failing on fixable issues
  -h, --help     Show this help
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 64
      ;;
  esac
done

OS_NAME="$(uname -s)"
ARCH="$(uname -m)"

FAIL=0
log_ok()  { echo "[OK]   $*"; }
log_err() { echo "[FAIL] $*" >&2; FAIL=1; }
log_warn(){ echo "[WARN] $*" >&2; }

# ── 1. OS sanity ─────────────────────────────────────────────────────────────
case "$OS_NAME" in
  Darwin|Linux)
    log_ok "OS: $OS_NAME"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    log_ok "OS: $OS_NAME (Git Bash / MSYS detected — OK)"
    ;;
  *)
    log_err "Unsupported shell: $OS_NAME. Use WSL2 or Git Bash on Windows; PowerShell/cmd is not supported."
    ;;
esac

# ── 2. Required tools ────────────────────────────────────────────────────────
# docker — augment PATH with common install locations on Linux/macOS/Windows so
# `command -v docker` works in non-interactive bash where shell aliases are invisible.
if [ -n "${DOCKER:-}" ] && [ -x "${DOCKER}" ]; then
  export PATH="$(dirname "${DOCKER}"):${PATH}"
fi
if ! command -v docker >/dev/null 2>&1 && ! command -v docker.exe >/dev/null 2>&1; then
  for CAND in \
    /usr/bin \
    /usr/local/bin \
    /snap/bin \
    /opt/homebrew/bin \
    /Applications/Docker.app/Contents/Resources/bin \
    "/c/Program Files/Docker/Docker/resources/bin" \
    "/mnt/c/Program Files/Docker/Docker/resources/bin"; do
    if [ -x "${CAND}/docker" ] || [ -x "${CAND}/docker.exe" ]; then
      export PATH="${CAND}:${PATH}"
      break
    fi
  done
fi

if command -v docker >/dev/null 2>&1; then
  log_ok "docker: $(docker --version 2>/dev/null | head -1)"
elif command -v docker.exe >/dev/null 2>&1; then
  log_ok "docker.exe: $(docker.exe --version 2>/dev/null | head -1)"
else
  # C1: zsh alias hint. macOS users sometimes have `alias docker=...` in zshrc
  # without an actual binary on PATH (Docker Desktop install hooks did not
  # symlink to /usr/local/bin). The PATH augmentation above tries the canonical
  # Docker.app binary location; if that file exists but PATH still doesn't have
  # it (sandboxed FS, weird perms), surface the symlink hint explicitly.
  log_err "docker not found on PATH."
  if [[ "$OS_NAME" == "Darwin" && -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
    log_err "  Docker Desktop binary IS present at /Applications/Docker.app/Contents/Resources/bin/docker but not on PATH."
    log_err "  This often happens when zshrc has 'alias docker=...' but no symlink in /usr/local/bin/."
    log_err "  Fix: sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/docker"
    log_err "  Or:  export DOCKER=/Applications/Docker.app/Contents/Resources/bin/docker  # then re-run preflight"
  else
    log_err "  Install Docker Desktop (macOS/Windows) or Docker Engine (Linux). If installed, set DOCKER=/path/to/docker."
  fi
fi

# jq
if command -v jq >/dev/null 2>&1; then
  log_ok "jq: $(jq --version)"
else
  case "$OS_NAME" in
    Darwin) log_err "jq not found. Install: brew install jq" ;;
    Linux)  log_err "jq not found. Install: sudo apt-get install -y jq" ;;
    *)      log_err "jq not found. Install: choco install jq (run in Git Bash/WSL)" ;;
  esac
fi

# shasum or sha256sum
if command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; then
  if command -v shasum >/dev/null 2>&1; then
    log_ok "shasum: $(shasum --version 2>&1 | head -1)"
  else
    log_ok "sha256sum: $(sha256sum --version 2>&1 | head -1)"
  fi
else
  case "$OS_NAME" in
    Darwin) log_err "shasum not found. Install: brew install coreutils" ;;
    Linux)  log_err "sha256sum not found. Install: sudo apt-get install -y coreutils" ;;
    *)      log_err "shasum/sha256sum not found. Install coreutils or Git for Windows." ;;
  esac
fi

# timeout or gtimeout
if command -v gtimeout >/dev/null 2>&1; then
  log_ok "gtimeout: $(gtimeout --version 2>&1 | head -1)"
elif command -v timeout >/dev/null 2>&1; then
  log_ok "timeout: $(timeout --version 2>&1 | head -1)"
else
  case "$OS_NAME" in
    Darwin) log_err "timeout/gtimeout not found. Install: brew install coreutils (provides gtimeout)" ;;
    Linux)  log_err "timeout not found. Install: sudo apt-get install -y coreutils" ;;
    *)      log_err "timeout not found. Install coreutils." ;;
  esac
fi

# ── 3. Apple Silicon Rosetta 2 ───────────────────────────────────────────────
if [[ "$OS_NAME" == "Darwin" && "$ARCH" == "arm64" ]]; then
  # Rosetta 2 install check: arch -x86_64 true
  if arch -x86_64 true >/dev/null 2>&1; then
    log_ok "Rosetta 2 is installed (arch -x86_64 test passed)"
  else
    log_err "Rosetta 2 is NOT installed. Run: softwareupdate --install-rosetta --agree-to-license"
  fi

  # Docker Desktop Rosetta toggle (best-effort parse)
  DD_SETTINGS="$HOME/Library/Group Containers/group.com.docker/settings.json"
  if [[ -f "$DD_SETTINGS" ]]; then
    if command -v jq >/dev/null 2>&1; then
      ROSETTA_ENABLED=$(jq -r '.useVirtualizationFrameworkRosetta // "unknown"' "$DD_SETTINGS" 2>/dev/null || echo "unknown")
      case "$ROSETTA_ENABLED" in
        true) log_ok "Docker Desktop: 'Use Rosetta for x86_64/amd64 emulation' is enabled" ;;
        false)
          log_err "Docker Desktop: 'Use Rosetta for x86_64/amd64 emulation' is DISABLED. Enable in Docker Desktop → Settings → Features in Development. FD image will fall back to QEMU (extremely slow / unstable)."
          ;;
        *) log_warn "Could not parse Docker Desktop settings.json. Confirm 'Use Rosetta for x86/amd64 emulation' is enabled." ;;
      esac
    else
      log_warn "jq missing — cannot parse Docker Desktop settings. Manually confirm 'Use Rosetta' is enabled."
    fi
  else
    log_warn "Docker Desktop settings.json not found at $DD_SETTINGS. Cannot verify Rosetta integration."
  fi

  # docker info architecture hint (best-effort)
  if command -v docker >/dev/null 2>&1; then
    DOCKER_ARCH=$(docker info --format '{{.Architecture}}' 2>/dev/null || echo "")
    if [[ -n "$DOCKER_ARCH" ]]; then
      log_ok "docker info Architecture: $DOCKER_ARCH (amd64 images will use Rosetta/QEMU emulation)"
    fi
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [[ $FAIL -ne 0 ]]; then
  echo "[preflight] FAILED — see [FAIL] lines above." >&2
  if [[ $CHECK_ONLY -eq 1 ]]; then
    exit 1
  fi
  exit 1
fi

echo "[preflight] all checks passed."
exit 0
