#!/bin/bash
# build-offline-bundle.sh — Build an air-gapped Docker image bundle.
#
# Usage:
#   bash docker/fd-headless/scripts/build-offline-bundle.sh <image-tag> [output-dir]
#
# Example:
#   bash docker/fd-headless/scripts/build-offline-bundle.sh \
#     public.ecr.aws/g0j5z0m9/seamos-fd-headless:0.4.2 \
#     ./dist
#
# Output:
#   <output-dir>/seamos-fd-headless-<sanitized-tag>.tar
#   <output-dir>/seamos-fd-headless-<sanitized-tag>.tar.sha256
#
# Transfer both files to the air-gapped host, then:
#   shasum -a 256 -c seamos-fd-headless-<...>.tar.sha256
#   docker load -i seamos-fd-headless-<...>.tar

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image-tag> [output-dir]" >&2
  echo "Example: $0 public.ecr.aws/g0j5z0m9/seamos-fd-headless:0.4.2 ./dist" >&2
  exit 64
fi

IMAGE_TAG="$1"
OUTPUT_DIR="${2:-./dist}"

mkdir -p "${OUTPUT_DIR}"

# Sanitize tag for use in filename
SAFE_TAG="$(echo "${IMAGE_TAG}" | tr '/:' '__')"
TAR_FILE="${OUTPUT_DIR}/seamos-fd-headless-${SAFE_TAG}.tar"
SHA_FILE="${TAR_FILE}.sha256"

echo "=========================================="
echo " FD Headless Offline Bundle Builder"
echo "=========================================="
echo " Image tag   : ${IMAGE_TAG}"
echo " Output dir  : ${OUTPUT_DIR}"
echo " Tar file    : ${TAR_FILE}"
echo "=========================================="

# Step 1: Ensure image is present locally
if ! docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[1/3] Pulling ${IMAGE_TAG} (not found locally)..."
  docker pull "${IMAGE_TAG}"
else
  echo "[1/3] Using local image ${IMAGE_TAG}"
fi

# Step 2: docker save
echo "[2/3] Saving image to ${TAR_FILE}..."
docker save -o "${TAR_FILE}" "${IMAGE_TAG}"

# Step 3: SHA256
echo "[3/3] Computing SHA256..."
if command -v shasum >/dev/null 2>&1; then
  (cd "${OUTPUT_DIR}" && shasum -a 256 "$(basename "${TAR_FILE}")" > "$(basename "${SHA_FILE}")")
elif command -v sha256sum >/dev/null 2>&1; then
  (cd "${OUTPUT_DIR}" && sha256sum "$(basename "${TAR_FILE}")" > "$(basename "${SHA_FILE}")")
else
  echo "ERROR: neither shasum nor sha256sum found" >&2
  exit 1
fi

echo ""
echo "=========================================="
echo " Bundle built successfully."
echo "   TAR:    ${TAR_FILE}"
echo "   SHA256: ${SHA_FILE}"
echo "=========================================="
echo ""
echo "Transfer these two files to the air-gapped host, then:"
echo "  shasum -a 256 -c $(basename "${SHA_FILE}")"
echo "  docker load -i $(basename "${TAR_FILE}")"
