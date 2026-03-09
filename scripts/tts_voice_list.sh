#!/usr/bin/env bash
# LightX2V TTS: list preset voices. Prints voice_type and resource_id for use with tts_generate.sh.
# Usage: tts_voice_list.sh [--version VERSION]
# Env: LIGHTX2V_CLOUD_URL (default https://x2v.light-ai.top), LIGHTX2V_CLOUD_TOKEN (optional)

set -e
BASE_URL="${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}"
BASE_URL="${BASE_URL%/}"
TOKEN="${LIGHTX2V_CLOUD_TOKEN:-}"
CURL_AUTH=(); [ -n "$TOKEN" ] && CURL_AUTH=(-H "Authorization: Bearer $TOKEN")

VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    *) echo "Usage: tts_voice_list.sh [--version VERSION]" >&2; exit 1 ;;
  esac
done

URL="$BASE_URL/api/v1/voices/list"
[ -n "$VERSION" ] && URL="${URL}?version=$VERSION"

RESPONSE=$(curl -s "${CURL_AUTH[@]}" "$URL")
if ! echo "$RESPONSE" | grep -q '"voices"'; then
  echo "Failed to get voice list:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.voices[]? | "\(.voice_type // .voiceType // "?") \(.resource_id // .resourceId // "")"' 2>/dev/null || echo "$RESPONSE" | jq .
else
  echo "$RESPONSE" | grep -o '"voice_type":"[^"]*"[^}]*"resource_id":"[^"]*"' | sed 's/"voice_type":"\([^"]*\)".*"resource_id":"\([^"]*\)"/\1 \2/'
fi
