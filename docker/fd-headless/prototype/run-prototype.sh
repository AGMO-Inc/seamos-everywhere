#!/bin/bash
# run-prototype.sh — One-shot build + run + result check for FD Headless Wine prototype
# Usage: bash docker/fd-headless/prototype/run-prototype.sh [project_name]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CTX="${REPO_ROOT}"

IMAGE_NAME="fd-headless-prototype"
PROJECT_NAME="${1:-PrototypeProject}"
WORKSPACE_HOST="${SCRIPT_DIR}/workspace_out"

echo "========================================"
echo " FD Headless Wine Prototype Runner"
echo "========================================"
echo " Repo root  : ${REPO_ROOT}"
echo " Image      : ${IMAGE_NAME}"
echo " Project    : ${PROJECT_NAME}"
echo " Workspace  : ${WORKSPACE_HOST}"
echo "========================================"
echo ""

# ── 1. docker build ──────────────────────────────────────────────────────────
echo "[1/4] Building Docker image (platform: linux/amd64) ..."
docker build \
  --platform linux/amd64 \
  -f "${REPO_ROOT}/docker/fd-headless/Dockerfile" \
  -t "${IMAGE_NAME}" \
  "${DOCKER_CTX}"

echo ""
echo "[1/4] Build complete."
docker images "${IMAGE_NAME}" --format "  Size: {{.Size}}  Created: {{.CreatedAt}}"
echo ""

# ── 2. Prepare workspace ─────────────────────────────────────────────────────
echo "[2/4] Preparing empty workspace ..."
rm -rf "${WORKSPACE_HOST}"
mkdir -p "${WORKSPACE_HOST}"
echo ""

# ── 3. docker run ────────────────────────────────────────────────────────────
echo "[3/4] Running FD Headless via Wine ..."
echo "---------- stdout / stderr below ----------"

LOGFILE="${SCRIPT_DIR}/fd_headless_run.log"

docker run \
  --rm \
  --platform linux/amd64 \
  -v "${WORKSPACE_HOST}:/workspace" \
  -e FD_WORKSPACE=/workspace \
  -e FD_INTERFACE_JSON=/opt/fd/fd_user_selected_interface.json \
  -e FD_PROJECT_NAME="${PROJECT_NAME}" \
  -e FD_UI_TYPE="Custom UI" \
  "${IMAGE_NAME}" \
  2>&1 | tee "${LOGFILE}"

echo "---------- end of output ----------"
echo ""

# ── 4. Result check ──────────────────────────────────────────────────────────
echo "[4/4] Checking result ..."
echo ""

SUCCESS_STR="FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY"
FAILURE_STR="FD HEADLESS EXECUTION EXITED WITH ERRORS"

if grep -qF "${SUCCESS_STR}" "${LOGFILE}"; then
    echo "RESULT: SUCCESS"
    echo ""
    echo "--- Last 15 lines of output ---"
    tail -15 "${LOGFILE}"
elif grep -qF "${FAILURE_STR}" "${LOGFILE}"; then
    echo "RESULT: FAILURE (FD reported errors)"
    echo ""
    echo "--- Last 20 lines of output ---"
    tail -20 "${LOGFILE}"
    echo ""
    echo "Full log saved to: ${LOGFILE}"
    exit 1
else
    echo "RESULT: UNKNOWN (success/failure string not found in output)"
    echo ""
    echo "--- Last 20 lines of output ---"
    tail -20 "${LOGFILE}"
    echo ""
    echo "Full log saved to: ${LOGFILE}"
    exit 2
fi

# ── 5. Workspace artifacts ───────────────────────────────────────────────────
echo ""
echo "=== Workspace artifacts in ${WORKSPACE_HOST} ==="
if [ -z "$(ls -A "${WORKSPACE_HOST}" 2>/dev/null)" ]; then
    echo "  (empty — no files generated)"
else
    find "${WORKSPACE_HOST}" -type f | sort | while read -r f; do
        size=$(du -sh "${f}" 2>/dev/null | cut -f1)
        echo "  ${size}  ${f#"${WORKSPACE_HOST}/"}"
    done
fi
echo "========================================"
