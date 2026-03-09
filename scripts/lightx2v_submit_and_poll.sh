#!/usr/bin/env bash
# LightX2V: submit task, poll until done, print result URL.
# Usage: submit_and_poll.sh <task> <model_cls> <prompt> [--aspect-ratio RATIO] [--input-image PATH|URL [...]] [--input-audio PATH] [--input-video PATH]
#        Multiple --input-image for I2I multi-image; single or multiple supported.
# Env: LIGHTX2V_CLOUD_URL (default https://x2v.light-ai.top), LIGHTX2V_CLOUD_TOKEN (optional; required for cloud)

set -e
BASE_URL="${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}"
BASE_URL="${BASE_URL%/}"
TOKEN="${LIGHTX2V_CLOUD_TOKEN:-}"
CURL_AUTH=(); [ -n "$TOKEN" ] && CURL_AUTH=(-H "Authorization: Bearer $TOKEN")

TASK="$1"
MODEL_CLS="$2"
PROMPT="$3"
shift 3 || true
ASPECT_RATIO=""
INPUT_IMAGE_ARR=()
INPUT_AUDIO=""
INPUT_VIDEO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --aspect-ratio) ASPECT_RATIO="$2"; shift 2 ;;
    --input-image)  INPUT_IMAGE_ARR+=("$2"); shift 2 ;;
    --input-audio)  INPUT_AUDIO="$2";  shift 2 ;;
    --input-video)  INPUT_VIDEO="$2";  shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TASK" ] || [ -z "$MODEL_CLS" ]; then
  echo "Usage: submit_and_poll.sh <task> <model_cls> <prompt> [--aspect-ratio RATIO] [--input-image PATH|URL [--input-image PATH|URL ...]] [--input-audio PATH] [--input-video PATH]" >&2
  exit 1
fi

# Default prompt to space if empty (required by API)
[ -z "$PROMPT" ] && PROMPT=" "
SEED=$(( RANDOM * 1000 + RANDOM % 1000 ))

# Build JSON payload: only http(s) URL is sent as type "url"; local path is read and sent as base64.
# Single image/video: returns {"type":"url"|"base64","data":"..."}
payload_image() {
  local v="$1"
  if [ -z "$v" ]; then echo "null"; return; fi
  if [[ "$v" =~ ^https?:// ]]; then
    local esc; esc=$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "{\"type\":\"url\",\"data\":\"$esc\"}"
  else
    # 本地路径：读文件转 base64 提交
    local b64
    b64=$(base64 -w 0 "$v" 2>/dev/null || base64 < "$v" 2>/dev/null | tr -d '\n')
    if [ -z "$b64" ]; then echo "null"; return; fi
    echo "{\"type\":\"base64\",\"data\":\"$b64\"}"
  fi
}

# Multiple images: URL 用 type=url；含任一本地路径则全部按本地读入转 base64。
payload_images_array() {
  local n=$#
  [ "$n" -eq 0 ] && { echo "null"; return; }
  local arr=("$@")
  local all_urls=1
  for v in "${arr[@]}"; do
    if [[ ! "$v" =~ ^https?:// ]]; then all_urls=0; break; fi
  done
  local data="["
  local first=1
  if [ "$all_urls" -eq 1 ]; then
    for v in "${arr[@]}"; do
      [ "$first" -eq 1 ] && first=0 || data="$data,"
      local esc; esc=$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g')
      data="$data\"$esc\""
    done
    data="$data]"
    echo "{\"type\":\"url\",\"data\":$data}"
  else
    # 本地路径：逐个读文件转 base64
    for v in "${arr[@]}"; do
      [ "$first" -eq 1 ] && first=0 || data="$data,"
      local b64
      b64=$(base64 -w 0 "$v" 2>/dev/null || base64 < "$v" 2>/dev/null | tr -d '\n')
      if [ -z "$b64" ]; then echo "null"; return; fi
      data="$data\"$b64\""
    done
    data="$data]"
    echo "{\"type\":\"base64\",\"data\":$data}"
  fi
}

# 音频：仅支持本地路径，读文件转 base64 提交
payload_audio() {
  local v="$1"
  if [ -z "$v" ]; then echo "null"; return; fi
  if [[ "$v" =~ ^https?:// ]]; then
    local esc; esc=$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "{\"type\":\"url\",\"data\":\"$esc\"}"
  else
    local b64
    b64=$(base64 -w 0 "$v" 2>/dev/null || base64 < "$v" 2>/dev/null | tr -d '\n')
    if [ -z "$b64" ]; then echo "null"; return; fi
    echo "{\"type\":\"base64\",\"data\":\"$b64\"}"
  fi
}

# Escape prompt for JSON: \ " newline tab
escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/$/\\n/' | tr -d '\n'; }
P_ESC=$(escape_json "$PROMPT")
P_ESC="${P_ESC%\\n}"  # trim trailing \n

BODY="{\"task\":\"$TASK\",\"model_cls\":\"$MODEL_CLS\",\"stage\":\"single_stage\",\"seed\":$SEED,\"prompt\":\"$P_ESC\""
if [ -n "$ASPECT_RATIO" ]; then
  BODY="$BODY,\"aspect_ratio\":\"$ASPECT_RATIO\""
fi
if [ ${#INPUT_IMAGE_ARR[@]} -gt 0 ]; then
  if [ ${#INPUT_IMAGE_ARR[@]} -eq 1 ]; then
    IMG_JSON=$(payload_image "${INPUT_IMAGE_ARR[0]}")
  else
    IMG_JSON=$(payload_images_array "${INPUT_IMAGE_ARR[@]}")
  fi
  [ "$IMG_JSON" != "null" ] && BODY="$BODY,\"input_image\":$IMG_JSON"
fi
if [ -n "$INPUT_AUDIO" ]; then
  AUD_JSON=$(payload_audio "$INPUT_AUDIO")
  [ "$AUD_JSON" != "null" ] && BODY="$BODY,\"input_audio\":$AUD_JSON"
fi
if [ -n "$INPUT_VIDEO" ]; then
  VID_JSON=$(payload_image "$INPUT_VIDEO")
  [ "$VID_JSON" != "null" ] && BODY="$BODY,\"input_video\":$VID_JSON"
fi
BODY="$BODY}"

RESP=$(curl -s -S -X POST "$BASE_URL/api/v1/task/submit" \
  "${CURL_AUTH[@]}" \
  -H "Content-Type: application/json" \
  -d "$BODY") || { echo "Submit request failed." >&2; exit 1; }

TASK_ID=$(echo "$RESP" | grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
if [ -z "$TASK_ID" ]; then
  echo "Submit failed or no task_id in response:" >&2
  echo "$RESP" >&2
  exit 1
fi

# Poll
while true; do
  sleep 5
  Q=$(curl -s -S "$BASE_URL/api/v1/task/query?task_id=$TASK_ID" "${CURL_AUTH[@]}") || { echo "Query failed." >&2; exit 1; }
  STATUS=$(echo "$Q" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
  if [ "$STATUS" = "SUCCEED" ]; then break; fi
  if [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "CANCELLED" ]; then
    ERR=$(echo "$Q" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
    echo "Task $STATUS: $ERR" >&2
    exit 1
  fi
done

# Result URL: image for t2i/i2i, video for the rest
case "$TASK" in
  t2i|i2i) NAME="output_image" ;;
  *)       NAME="output_video" ;;
esac
R=$(curl -s -S "$BASE_URL/api/v1/task/result_url?task_id=$TASK_ID&name=$NAME" "${CURL_AUTH[@]}") || { echo "Result URL request failed." >&2; exit 1; }
URL=$(echo "$R" | grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
if [ -z "$URL" ]; then
  echo "No url in result response:" >&2
  echo "$R" >&2
  exit 1
fi
echo "$URL"
