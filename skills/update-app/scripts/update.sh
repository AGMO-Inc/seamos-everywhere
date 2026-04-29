#!/usr/bin/env bash
set -euo pipefail

# SDM Marketplace App Version Update Script
# Uploads a new version of an existing app via multipart/form-data

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Required:
  --base-url URL        SDM backend base URL (e.g., http://localhost:8088)
  --api-key KEY         API key with APP_DEPLOY scope
  --app-id ID           Existing app ID to update
  --request JSON        Variants metadata as JSON string
  --app-file TYPE PATH  feuType name and path to .fif file (can repeat)

Optional:
  --dry-run             Print the curl command without executing
  -h, --help            Show this help
EOF
  exit 1
}

BASE_URL=""
API_KEY=""
APP_ID=""
REQUEST_JSON=""
APP_FILES=()  # pairs of (feuType, path)
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)   BASE_URL="$2"; shift 2 ;;
    --api-key)    API_KEY="$2"; shift 2 ;;
    --app-id)     APP_ID="$2"; shift 2 ;;
    --request)    REQUEST_JSON="$2"; shift 2 ;;
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
[[ -z "$APP_ID" ]] && { echo "Error: --app-id is required"; exit 1; }
[[ -z "$REQUEST_JSON" ]] && { echo "Error: --request is required"; exit 1; }
[[ ${#APP_FILES[@]} -eq 0 ]] && { echo "Error: at least 1 --app-file required"; exit 1; }

# Verify files exist
for ((i=1; i<${#APP_FILES[@]}; i+=2)); do
  [[ -f "${APP_FILES[$i]}" ]] || { echo "Error: App file not found: ${APP_FILES[$i]}"; exit 1; }
done

# Build curl command
CURL_ARGS=(
  curl -s -w "\n%{http_code}"
  -X POST "${BASE_URL}/v2/apps/${APP_ID}/versions"
  -H "X-API-Key: ${API_KEY}"
  -F "request=${REQUEST_JSON};type=application/json"
)

# Add app files (feuType as part name)
for ((i=0; i<${#APP_FILES[@]}; i+=2)); do
  feu_type="${APP_FILES[$i]}"
  fif_path="${APP_FILES[$((i+1))]}"
  CURL_ARGS+=(-F "${feu_type}=@${fif_path}")
done

if $DRY_RUN; then
  MASKED_KEY="${API_KEY:0:6}***"
  echo "DRY RUN — would execute:"
  printf '%s ' "${CURL_ARGS[@]}" | sed "s|${API_KEY}|${MASKED_KEY}|g"
  echo
  exit 0
fi

# Execute with one-shot retry on transient backend errors.
# The SDM backend occasionally responds with "Could not open JPA EntityManager
# for transaction" (HTTP 500) on the first call after a cold start. A single
# retry after a short sleep clears it. We only retry on 5xx — never on 4xx,
# which is a real client-side problem the user should see immediately.
run_curl() {
  local out
  out=$("${CURL_ARGS[@]}")
  echo "$out"
}

ATTEMPT=1
MAX_ATTEMPTS=2
while :; do
  OUTPUT=$(run_curl)
  HTTP_CODE=$(echo "$OUTPUT" | tail -1)
  BODY=$(echo "$OUTPUT" | sed '$d')

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    break
  fi

  # Retry only on 5xx or transient JPA-shaped bodies; only once.
  if [[ $ATTEMPT -lt $MAX_ATTEMPTS ]] \
     && { [[ "$HTTP_CODE" -ge 500 && "$HTTP_CODE" -lt 600 ]] \
          || echo "$BODY" | grep -qiE 'JPA EntityManager|EntityManagerFactory|transaction'; }; then
    echo "--- Transient backend error (HTTP ${HTTP_CODE}); retrying once after 2s ---" >&2
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
    continue
  fi

  break
done

echo "$BODY"
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "--- Status: ${HTTP_CODE} (Success) ---"
  exit 0
else
  echo "--- Status: ${HTTP_CODE} (Failed after ${ATTEMPT} attempt(s)) ---"
  exit 1
fi
