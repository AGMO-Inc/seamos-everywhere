#!/usr/bin/env bash
set -euo pipefail

# SDM Marketplace App Upload Script
# Uploads a SeamOS app package with metadata and assets via multipart/form-data

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Required:
  --base-url URL        SDM backend base URL (e.g., http://localhost:8088)
  --api-key KEY         API key with APP_DEPLOY scope
  --request JSON        App metadata as JSON string
  --main-image PATH     Path to main image file
  --icon-image PATH     Path to icon image file
  --screenshots PATH... Path(s) to screenshot files (at least 1)
  --app-file TYPE PATH  feuType name and path to .fif file (can repeat)

Optional:
  --dry-run             Print the curl command without executing
  -h, --help            Show this help
EOF
  exit 1
}

BASE_URL=""
API_KEY=""
REQUEST_JSON=""
MAIN_IMAGE=""
ICON_IMAGE=""
SCREENSHOTS=()
APP_FILES=()  # pairs of (feuType, path)
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)   BASE_URL="$2"; shift 2 ;;
    --api-key)    API_KEY="$2"; shift 2 ;;
    --request)    REQUEST_JSON="$2"; shift 2 ;;
    --main-image) MAIN_IMAGE="$2"; shift 2 ;;
    --icon-image) ICON_IMAGE="$2"; shift 2 ;;
    --screenshots)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
        SCREENSHOTS+=("$1"); shift
      done
      ;;
    --app-file)
      APP_FILES+=("$2" "$3"); shift 3 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

# Validation
[[ -z "$BASE_URL" ]] && { echo "Error: --base-url is required"; exit 1; }
[[ -z "$API_KEY" ]] && { echo "Error: --api-key is required"; exit 1; }
[[ -z "$REQUEST_JSON" ]] && { echo "Error: --request is required"; exit 1; }
[[ -z "$MAIN_IMAGE" ]] && { echo "Error: --main-image is required"; exit 1; }
[[ -z "$ICON_IMAGE" ]] && { echo "Error: --icon-image is required"; exit 1; }
[[ ${#SCREENSHOTS[@]} -eq 0 ]] && { echo "Error: at least 1 screenshot required"; exit 1; }
[[ ${#APP_FILES[@]} -eq 0 ]] && { echo "Error: at least 1 --app-file required"; exit 1; }

# Verify files exist
for f in "$MAIN_IMAGE" "$ICON_IMAGE" "${SCREENSHOTS[@]}"; do
  [[ -f "$f" ]] || { echo "Error: File not found: $f"; exit 1; }
done
for ((i=1; i<${#APP_FILES[@]}; i+=2)); do
  [[ -f "${APP_FILES[$i]}" ]] || { echo "Error: App file not found: ${APP_FILES[$i]}"; exit 1; }
done

# Build curl command
CURL_ARGS=(
  curl -s -w "\n%{http_code}"
  -X POST "${BASE_URL}/v2/apps"
  -H "X-API-Key: ${API_KEY}"
  -F "request=${REQUEST_JSON};type=application/json"
  -F "mainImage=@${MAIN_IMAGE}"
  -F "iconImage=@${ICON_IMAGE}"
)

# Add screenshots
for i in "${!SCREENSHOTS[@]}"; do
  CURL_ARGS+=(-F "screenshot${i}=@${SCREENSHOTS[$i]}")
done

# Add app files (feuType as part name)
for ((i=0; i<${#APP_FILES[@]}; i+=2)); do
  feu_type="${APP_FILES[$i]}"
  fif_path="${APP_FILES[$((i+1))]}"
  CURL_ARGS+=(-F "${feu_type}=@${fif_path}")
done

if $DRY_RUN; then
  echo "DRY RUN — would execute:"
  printf '%q ' "${CURL_ARGS[@]}"
  echo
  exit 0
fi

# Execute
OUTPUT=$("${CURL_ARGS[@]}")
HTTP_CODE=$(echo "$OUTPUT" | tail -1)
BODY=$(echo "$OUTPUT" | sed '$d')

echo "$BODY"
exit_code=0
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "--- Status: ${HTTP_CODE} (Success) ---"
else
  echo "--- Status: ${HTTP_CODE} (Failed) ---"
  exit_code=1
fi

exit $exit_code
