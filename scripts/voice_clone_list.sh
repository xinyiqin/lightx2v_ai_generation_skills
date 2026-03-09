#!/usr/bin/env bash
# LightX2V Voice Clone: list user's cloned voices. Prints speaker_id and name for use with voice_clone_tts.sh.
# Usage: voice_clone_list.sh
# Env: LIGHTX2V_CLOUD_URL (default https://x2v.light-ai.top), LIGHTX2V_CLOUD_TOKEN (required for cloud)

set -e
BASE_URL="${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}"
BASE_URL="${BASE_URL%/}"
TOKEN="${LIGHTX2V_CLOUD_TOKEN:-}"
CURL_AUTH=(); [ -n "$TOKEN" ] && CURL_AUTH=(-H "Authorization: Bearer $TOKEN")

URL="$BASE_URL/api/v1/voice/clone/list"
RESPONSE=$(curl -s "${CURL_AUTH[@]}" "$URL")

if ! echo "$RESPONSE" | grep -q '"voice_clones"'; then
  echo "Failed to get voice clone list:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.voice_clones[]? | "\(.speaker_id // .speakerId // "?") \(.name // "")"' 2>/dev/null || echo "$RESPONSE" | jq .
else
  echo "$RESPONSE" | grep -o '"speaker_id":"[^"]*"[^}]*"name":"[^"]*"' | sed 's/"speaker_id":"\([^"]*\)".*"name":"\([^"]*\)"/\1 \2/' || echo "$RESPONSE"
fi
