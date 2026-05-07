#!/usr/bin/env bash
set -euo pipefail

# SeamOS Marketplace App Version Update Script
# Uploads a new version of an existing app via multipart/form-data.
# Authenticates with a one-time upload token (ut_*) issued by the update_app
# MCP tool — 5-minute TTL, single-use, bound to the appId in the request.

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Required:
  --base-url URL        SeamOS backend base URL (e.g., http://localhost:8088)
  --upload-token TOKEN  One-time upload token (ut_*) from update_app MCP tool
  --app-id ID           Existing app ID to update
  --request JSON        Variants metadata as JSON string

Single-variant convenience flags (cannot mix with --app-file):
  --feu-type FEU        feuType to register under (multipart part name)
  --fif PATH            explicit .fif path
  --arch ARCH           resolve .fif by '<ARCH>-*.fif' in --build-dir
                        (must yield exactly one match; combine with --feu-type)
  --build-dir DIR       directory to scan for .fif when --arch is set
                        (default: ./seamos-assets/builds)

Multi-variant flag (cannot mix with --feu-type/--fif/--arch):
  --app-file TYPE PATH  feuType name and path to .fif file (can repeat)

Optional:
  --dry-run             Print the curl command without executing
  -h, --help            Show this help
EOF
  exit 1
}

BASE_URL=""
UPLOAD_TOKEN=""
APP_ID=""
REQUEST_JSON=""
APP_FILES=()  # pairs of (feuType, path)
DRY_RUN=false
FEU_TYPE=""
FIF_PATH=""
ARCH=""
BUILD_DIR="./seamos-assets/builds"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)      BASE_URL="$2"; shift 2 ;;
    --upload-token)  UPLOAD_TOKEN="$2"; shift 2 ;;
    --app-id)        APP_ID="$2"; shift 2 ;;
    --request)       REQUEST_JSON="$2"; shift 2 ;;
    --app-file)
      APP_FILES+=("$2" "$3"); shift 3 ;;
    --feu-type)   FEU_TYPE="$2"; shift 2 ;;
    --fif)        FIF_PATH="$2"; shift 2 ;;
    --arch)       ARCH="$2"; shift 2 ;;
    --build-dir)  BUILD_DIR="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

# Validation — required base flags
[[ -z "$BASE_URL" ]] && { echo "Error: --base-url is required"; exit 1; }
[[ -z "$UPLOAD_TOKEN" ]] && { echo "Error: --upload-token is required"; exit 1; }
[[ -z "$APP_ID" ]] && { echo "Error: --app-id is required"; exit 1; }
[[ -z "$REQUEST_JSON" ]] && { echo "Error: --request is required"; exit 1; }

# Convenience flags (--feu-type/--fif/--arch) synthesize a single --app-file pair.
# They cannot coexist with --app-file.
HAS_CONVENIENCE=false
if [[ -n "$FEU_TYPE" || -n "$FIF_PATH" || -n "$ARCH" ]]; then
  HAS_CONVENIENCE=true
fi

if $HAS_CONVENIENCE && [[ ${#APP_FILES[@]} -gt 0 ]]; then
  echo "Error: --feu-type/--fif/--arch cannot be combined with --app-file"
  exit 1
fi

if $HAS_CONVENIENCE; then
  [[ -z "$FEU_TYPE" ]] && { echo "Error: --feu-type is required when using --fif/--arch"; exit 1; }

  # Resolve FIF_PATH if only --arch was given.
  if [[ -z "$FIF_PATH" ]]; then
    [[ -z "$ARCH" ]] && { echo "Error: provide --fif PATH or --arch ARCH"; exit 1; }
    [[ -d "$BUILD_DIR" ]] || { echo "Error: --build-dir not found: $BUILD_DIR"; exit 1; }

    MATCHES=()
    while IFS= read -r -d '' f; do
      MATCHES+=("$f")
    done < <(find "$BUILD_DIR" -maxdepth 1 -type f -name "${ARCH}-*.fif" -print0 2>/dev/null | sort -z)

    if [[ ${#MATCHES[@]} -eq 0 ]]; then
      echo "Error: no .fif matched '${ARCH}-*.fif' in $BUILD_DIR"
      exit 1
    fi
    if [[ ${#MATCHES[@]} -gt 1 ]]; then
      echo "Error: multiple .fif matched '${ARCH}-*.fif' in $BUILD_DIR — pass --fif PATH explicitly:"
      for m in "${MATCHES[@]}"; do echo "  - $m"; done
      exit 1
    fi
    FIF_PATH="${MATCHES[0]}"
  fi

  APP_FILES+=("$FEU_TYPE" "$FIF_PATH")
fi

[[ ${#APP_FILES[@]} -eq 0 ]] && { echo "Error: at least 1 --app-file (or --feu-type + --fif/--arch) required"; exit 1; }

# Verify files exist
for ((i=1; i<${#APP_FILES[@]}; i+=2)); do
  [[ -f "${APP_FILES[$i]}" ]] || { echo "Error: App file not found: ${APP_FILES[$i]}"; exit 1; }
done

# Build curl command
CURL_ARGS=(
  curl -s -w "\n%{http_code}"
  -X POST "${BASE_URL}/v2/apps/${APP_ID}/versions"
  -H "Authorization: Bearer ${UPLOAD_TOKEN}"
  -F "request=${REQUEST_JSON};type=application/json"
)

# Add app files (feuType as part name)
for ((i=0; i<${#APP_FILES[@]}; i+=2)); do
  feu_type="${APP_FILES[$i]}"
  fif_path="${APP_FILES[$((i+1))]}"
  CURL_ARGS+=(-F "${feu_type}=@${fif_path}")
done

if $DRY_RUN; then
  MASKED="${UPLOAD_TOKEN:0:6}***"
  echo "DRY RUN — would execute:"
  printf '%s ' "${CURL_ARGS[@]}" | sed "s|${UPLOAD_TOKEN}|${MASKED}|g"
  echo
  exit 0
fi

# Execute. The upload token is single-use — on transient backend failure the
# token is already consumed, so the user must rerun the skill (which fetches a
# fresh token via update_app) rather than retrying inside this script.
OUTPUT=$("${CURL_ARGS[@]}")
HTTP_CODE=$(echo "$OUTPUT" | tail -1)
BODY=$(echo "$OUTPUT" | sed '$d')

echo "$BODY"
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "--- Status: ${HTTP_CODE} (Success) ---"
  exit 0
else
  echo "--- Status: ${HTTP_CODE} (Failed) ---"
  exit 1
fi
