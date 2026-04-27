---
name: lightx2v
title: X2V 图影
description: "LightX2V cloud API for images (t2i, i2i), video (t2v, i2v, s2v, flf2v, animate), TTS, and voice clone. Use when the user asks to generate or edit images, create video from text or image, produce digital human (talking head) video, first-last frame video, convert text to speech, or clone a voice—and content is not adult/restricted (otherwise use lightx2v-local)."
homepage: https://x2v.light-ai.top
metadata:
  version: "1.0.0"
  openclaw:
    emoji: "🎬"
    displayName: "X2V Studio"
    requires:
      env: ["LIGHTX2V_CLOUD_TOKEN"]
    primaryEnv: "LIGHTX2V_CLOUD_TOKEN"
---

# LightX2V

Calls the LightX2V cloud API (base URL default `https://x2v.light-ai.top`, same token for all). Covers: (1) **Image/Video** — t2i, i2i, t2v, i2v, s2v, animate; (2) **TTS** — text-to-speech with preset voices; (3) **Voice clone** — clone voice from audio, then synthesize with cloned voice. Supported models include the **Wan2.2** series (video), **Qwen-2511** (image editing / i2i), and **Qwen-2512** (image generation / t2i). Requires `LIGHTX2V_CLOUD_TOKEN` (and optionally `LIGHTX2V_CLOUD_URL`) to be set.

## Setup

1. Get an access token from the LightX2V platform (e.g. https://x2v.light-ai.top).
2. Set environment variables in `skills.entries.lightx2v.env` in openclaw.json (recommended), or export in the shell:

```bash
export LIGHTX2V_CLOUD_TOKEN="your-token"
export LIGHTX2V_CLOUD_URL="https://x2v.light-ai.top"  # optional
```

**Auto-load:** The bundled scripts automatically read `LIGHTX2V_CLOUD_TOKEN` and `LIGHTX2V_CLOUD_URL` from `~/.openclaw/openclaw.json` when not set in the environment. Configure once; no need to export every time.

```json
"skills": {
  "entries": {
    "lightx2v": {
      "enabled": true,
      "env": {
        "LIGHTX2V_CLOUD_TOKEN": "your-cloud-token",
        "LIGHTX2V_CLOUD_URL": "https://x2v.light-ai.top"
      }
    }
  }
}
```

## API Overview

**⚠️ Authentication:** ALL endpoints require `Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN`. Include this header on every request — omitting it causes 401 errors.

| Action | Endpoint | Purpose |
|--------|----------|---------|
| List models | `GET /api/v1/model/list` | Get available `task` + `model_cls` combinations |
| Submit task | `POST /api/v1/task/submit` | Submit a job; returns `task_id` |
| Query status | `GET /api/v1/task/query?task_id=<id>` | Poll until `status` is SUCCEED / FAILED / CANCELLED |
| Get result | `GET /api/v1/task/result_url?task_id=<id>&name=<name>` | Download URL; name is `output_image` (t2i/i2i) or `output_video` (t2v/i2v/s2v/flf2v/animate) |
| TTS voices | `GET /api/v1/voices/list` | List preset voices |
| TTS generate | `POST /api/v1/tts/generate` | JSON body; returns audio/mpeg (mp3) |
| Voice clone | `POST /api/v1/voice/clone` | multipart: file (audio); returns speaker_id |
| Voice clone TTS | `POST /api/v1/voice/clone/tts` | JSON: text, speaker_id; returns audio/wav |
| Voice clone list | `GET /api/v1/voice/clone/list` | List user's cloned voices |
| Voice clone save | `POST /api/v1/voice/clone/save` | JSON: speaker_id, name — save clone |
| Voice clone delete | `DELETE /api/v1/voice/clone/{speaker_id}` | Remove a cloned voice |

## Task Types and Inputs

| task | Description | Required | Optional |
|------|-------------|----------|----------|
| **t2i** | Text-to-image | prompt | aspect_ratio |
| **i2i** | Image edit | prompt, input_image | aspect_ratio |
| **t2v** | Text-to-video | prompt | aspect_ratio |
| **i2v** | Image-to-video | prompt, input_image | aspect_ratio |
| **s2v** | Digital human (image + audio) | prompt, input_image, input_audio | — |
| **flf2v** | First–last frame video | `--input-image` (first frame) + `--input-last-frame` (last frame); see [examples/first-last-frame-video.md](examples/first-last-frame-video.md) | — |
| **animate** | Animate with ref video | prompt, input_image, input_video | — |

- `input_image`: file path, URL, or base64 data URL. For i2i multi-image, API accepts array.
- `input_audio`: audio file (WAV preferred; base64 or URL).
- `input_video`: video file (for animate).
- `prompt`: non-empty text; use space `" "` if the task does not need a text prompt.
- `aspect_ratio`: e.g. `16:9`, `1:1`, `9:16`, `3:4`, `4:3`.

Submit payload shape (JSON):

```json
{
  "task": "t2i",
  "model_cls": "<from model list>",
  "stage": "single_stage",
  "seed": <random 0-999999>,
  "prompt": "user prompt text",
  "aspect_ratio": "16:9",
  "input_image": { "type": "base64", "data": "<base64>" },
  "input_audio": { "type": "base64", "data": "<base64>" }
}
```

For local files: read, base64-encode, set `{ "type": "base64", "data": "<base64>" }`. For HTTP(S) URLs use `{ "type": "url", "data": "<url>" }`.

## Workflow

1. **List models** — `GET $LIGHTX2V_CLOUD_URL/api/v1/model/list`. Choose a `model_cls` whose `task` matches the user request.
2. **Submit** — `POST /api/v1/task/submit` with JSON body. Remember `task_id` from the response.
3. **Poll** — `GET /api/v1/task/query?task_id=<task_id>` every 5–10 seconds until `status` is `SUCCEED`, `FAILED`, or `CANCELLED`. Video tasks can take several minutes; do not timeout too early. On `FAILED`, report `error` from the response.
4. **Result URL** — `GET /api/v1/task/result_url?task_id=<task_id>&name=output_image` (t2i/i2i) or `&name=output_video` (t2v/i2v/s2v/flf2v/animate). Return the `url` to the user.

## Helper Script

```bash
# List models
curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" \
  "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/model/list"

# T2I
{baseDir}/scripts/lightx2v_submit_and_poll.sh t2i "<model_cls>" "a cat on the beach" --aspect-ratio 1:1

# T2V
{baseDir}/scripts/lightx2v_submit_and_poll.sh t2v "<model_cls>" "a cat walking on the beach at sunset" --aspect-ratio 16:9

# I2I (single image)
{baseDir}/scripts/lightx2v_submit_and_poll.sh i2i "<model_cls>" "make it sunset style" --input-image /path/to/image.png --aspect-ratio 1:1

# I2I (multi-image)
{baseDir}/scripts/lightx2v_submit_and_poll.sh i2i "<model_cls>" "merge and stylize" --input-image /path/to/1.png --input-image /path/to/2.png --aspect-ratio 1:1

# I2V
{baseDir}/scripts/lightx2v_submit_and_poll.sh i2v "<model_cls>" "camera pans slowly" --input-image /path/to/image.png

# S2V (digital human)
{baseDir}/scripts/lightx2v_submit_and_poll.sh s2v "<model_cls>" " " --input-image /path/to/face.png --input-audio /path/to/audio.wav
```

Script usage: `lightx2v_submit_and_poll.sh <task> <model_cls> <prompt> [--aspect-ratio RATIO] [--input-image PATH|URL [...]] [--input-last-frame PATH|URL] [--input-audio PATH] [--input-video PATH]`

## TTS (Text-to-Speech)

Preset voices; same base URL and token. For full field reference, writing guidelines, and recommended voices see [references/tts-reference.md](references/tts-reference.md).

```bash
# List voices
{baseDir}/scripts/tts_voice_list.sh

# Generate TTS
{baseDir}/scripts/tts_generate.sh "Text to synthesize" "voice_type_from_list" [--output out.mp3]
```

**Binary response:** The generate endpoint returns audio/mpeg (mp3) binary. Do not capture in a shell variable (`RESP=$(curl ...)`) — null bytes truncate and corrupt the file. Redirect directly: `curl ... > out.mp3`, then validate: `[ -s out.mp3 ] && head -c 10 out.mp3 | grep -q ID3`.

## Voice Clone

Clone a voice from audio, then synthesize speech with it. For full endpoint details and helper scripts see [references/voice-clone-reference.md](references/voice-clone-reference.md).

```bash
# Clone from audio file; prints speaker_id
{baseDir}/scripts/voice_clone.sh /path/to/audio.wav [--text "Transcript"]

# TTS with cloned voice
{baseDir}/scripts/voice_clone_tts.sh <speaker_id> "Text to speak" [--output out.wav]
```

## Complete End-to-End Examples

**Text-to-image (t2i):** List models → pick t2i `model_cls` → `lightx2v_submit_and_poll.sh t2i "<model_cls>" "a cat on the beach at sunset" --aspect-ratio 1:1` → script prints result image URL.

**TTS (preset voice):** List voices via `tts_voice_list.sh` → pick `voice_type` → `tts_generate.sh "Hello, welcome." "<voice_type>" --output files/audio/hello.mp3` → script writes MP3.

**Digital human (s2v):** Get scene image (t2i or i2i) → generate TTS audio → `lightx2v_submit_and_poll.sh s2v "<s2v_model_cls>" " " --input-image <scene_url> --input-audio files/audio/greeting.mp3` → script prints result video URL.

## Troubleshooting

### "Could not validate credentials" (401)

Every request must include `-H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN"`. Common causes: header missing, token not exported, token expired or malformed.

```bash
echo "Token length: $(echo -n "$LIGHTX2V_CLOUD_TOKEN" | wc -c)"
curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" \
  "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/voices/list" | head -3
```

### Other

- **Model not found:** Call `GET /api/v1/model/list` and pick a `model_cls` that supports the task.
- **Voice / resource_id:** Each voice in voices/list has its own `resource_id`; use the one from the list for that `voice_type`.
- **Large result files:** Prefer returning the result **URL** rather than embedding large files in messages.

## Additional Resources

For multi-step workflows, see the examples directory:

- [examples/first-last-frame-video.md](examples/first-last-frame-video.md) — flf2v: first frame → i2i last frame → flf2v
- [examples/digital-human-video.md](examples/digital-human-video.md) — s2v: scene image + TTS → talking-head video
- [examples/one-sentence-to-video.md](examples/one-sentence-to-video.md) — t2i/i2i → i2v: one key image → short video
- [examples/virtual-boyfriend-video.md](examples/virtual-boyfriend-video.md) — virtual companion: persona → avatar → scene + TTS/s2v or i2v
