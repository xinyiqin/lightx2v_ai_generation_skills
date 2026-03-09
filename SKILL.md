---
name: lightx2v
description: LightX2V cloud API. Generate images (t2i), edit images (i2i), text-to-video (t2v), image-to-video (i2v), digital human video (s2v); TTS; voice clone.
homepage: https://x2v.light-ai.top
metadata:
  openclaw:
    emoji: "🎬"
    requires:
      env: ["LIGHTX2V_CLOUD_TOKEN"]
    primaryEnv: "LIGHTX2V_CLOUD_TOKEN"
---

# LightX2V

Call the LightX2V cloud API (base URL default `https://x2v.light-ai.top`, same token for all). Covers: (1) **Image/Video** — t2i, i2i, t2v, i2v, s2v, animate; (2) **TTS** — text-to-speech with preset voices; (3) **Voice clone** — clone voice from audio, then synthesize with cloned voice. User must set `LIGHTX2V_CLOUD_TOKEN` and optionally `LIGHTX2V_CLOUD_URL`.


## Setup

1. Get an access token from the LightX2V platform (e.g. https://x2v.light-ai.top) for **cloud**.
2. Set environment variables (in `skills.entries.lightx2v.env` in openclaw.json):

```bash
# Required for API auth
export LIGHTX2V_CLOUD_TOKEN="your-token"

# Optional; default is https://x2v.light-ai.top
export LIGHTX2V_CLOUD_URL="https://x2v.light-ai.top"
```

In OpenClaw config you can use (cloud and local use **separate** env vars):

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

All calls use the same base URL and Bearer token.

**⚠️ CRITICAL: Authentication Header Required**
**ALL LightX2V API endpoints MUST include the Authorization header:**
```bash
-H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN"
```
Do NOT assume any endpoint works without authentication.

| Action | Endpoint | Purpose |
|--------|----------|---------|
| List models | `GET /api/v1/model/list` | Get available `task` + `model_cls` combinations |
| Submit task | `POST /api/v1/task/submit` | Submit a job; returns `task_id` |
| Query status | `GET /api/v1/task/query?task_id=<id>` | Poll until `status` is SUCCEED / FAILED / CANCELLED |
| Get result | `GET /api/v1/task/result_url?task_id=<id>&name=<name>` | Get download URL; name is `output_image` (t2i/i2i) or `output_video` (t2v/i2v/s2v/animate) |
| TTS voices | `GET /api/v1/voices/list` | List preset voices (optional `?version=`) |
| TTS generate | `POST /api/v1/tts/generate` | JSON: text, voice_type, context_texts?, emotion?, emotion_scale?, speech_rate?, pitch?, loudness_rate?, resource_id; returns audio/mpeg (mp3) |
| Voice clone | `POST /api/v1/voice/clone` | multipart: file (audio), optional text; returns speaker_id |
| Voice clone TTS | `POST /api/v1/voice/clone/tts` | JSON: text, speaker_id; returns audio/wav |
| Voice clone list | `GET /api/v1/voice/clone/list` | List user's cloned voices |
| Voice clone save | `POST /api/v1/voice/clone/save` | JSON: speaker_id, name — save clone to collection |
| Voice clone delete | `DELETE /api/v1/voice/clone/{speaker_id}` | Remove a cloned voice |

## Task Types and Inputs

| task | Description | Required | Optional |
|------|-------------|----------|----------|
| **t2i** | Text-to-image | prompt | aspect_ratio |
| **i2i** | Image edit | prompt, input_image | aspect_ratio |
| **t2v** | Text-to-video | prompt | aspect_ratio |
| **i2v** | Image-to-video | prompt, input_image | aspect_ratio |
| **s2v** | Digital human (image + audio) | prompt, input_image, input_audio | — |
| **animate** | Animate with ref video | prompt, input_image, input_video | — |

- `input_image`: one image (file path, URL, or base64 data URL). For i2i multi-image, API accepts array of images.
- `input_audio`: one audio file (WAV preferred; base64 or URL).
- `input_video`: one video file (for animate).
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

For local files: read file, base64-encode, and set `{ "type": "base64", "data": "<base64>" }`. For HTTP(S) URLs use `{ "type": "url", "data": "<url>" }`.

## Workflow

1. **List models** — `GET $LIGHTX2V_CLOUD_URL/api/v1/model/list` with header `Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN`. Choose a `model_cls` whose `task` matches the user request (t2i, i2i, t2v, i2v, s2v, animate).
2. **Submit** — `POST /api/v1/task/submit` with JSON body as above. Remember `task_id` from the response.
3. **Poll** — Every few seconds call `GET /api/v1/task/query?task_id=<task_id>` until `status` is `SUCCEED`, `FAILED`, or `CANCELLED`. On `FAILED`, report `error` from the response.
4. **Result URL** — For success, call `GET /api/v1/task/result_url?task_id=<task_id>&name=output_image` (t2i/i2i) or `&name=output_video` (t2v/i2v/s2v/animate). Return the `url` from the JSON to the user.

## Helper Script

Use the bundled script to submit, poll, and print the result URL:

```bash
# List models (no script; use curl)
curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" \
  "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/model/list"

# T2I
{baseDir}/scripts/submit_and_poll.sh t2i "<model_cls>" "a cat on the beach" --aspect-ratio 1:1

# T2V (text to video, no image)
{baseDir}/scripts/submit_and_poll.sh t2v "<model_cls>" "a cat walking on the beach at sunset" --aspect-ratio 16:9

# I2I 单图（一张图 + 编辑提示）
{baseDir}/scripts/submit_and_poll.sh i2i "<model_cls>" "make it sunset style" --input-image /path/to/image.png --aspect-ratio 1:1

# I2I 多图（多张图输入）：可多次传 --input-image，全部为 URL 时 type=url，含本地路径时自动转为 base64
{baseDir}/scripts/submit_and_poll.sh i2i "<model_cls>" "merge and stylize" --input-image /path/to/1.png --input-image /path/to/2.png --aspect-ratio 1:1

# I2V (image + prompt)
{baseDir}/scripts/submit_and_poll.sh i2v "<model_cls>" "camera pans slowly" --input-image /path/to/image.png

# S2V digital human (image + audio)
{baseDir}/scripts/submit_and_poll.sh s2v "<model_cls>" " " --input-image /path/to/face.png --input-audio /path/to/audio.wav
```

Script usage:

```bash
submit_and_poll.sh <task> <model_cls> <prompt> [--aspect-ratio RATIO] [--input-image PATH|URL [--input-image PATH|URL ...]] [--input-audio PATH] [--input-video PATH]
```

Output: prints the result URL (image or video) to stdout on success.

---

## TTS (Text-to-Speech)

Preset voices; same base URL and token.

**List voices:** `GET /api/v1/voices/list` (optional `?version=...`). Response: `{ voices: [...], emotions?: [...], languages?: [...] }`. Use `voice_type` from list for generate.

**Generate:** `POST /api/v1/tts/generate` with JSON:

```json
{
  "text": "要合成的文本",
  "voice_type": "zh_female_1",
  "context_texts": "",
  "emotion": "",
  "emotion_scale": 3,
  "speech_rate": 0,
  "pitch": 0,
  "loudness_rate": 0,
  "resource_id": "seed-tts-2.0"
}
```

| Field | Description | Default |
|-------|-------------|--------|
| `text` | Text to synthesize | required |
| `voice_type` | From `GET /api/v1/voices/list` | required |
| `resource_id` | From voice list (script resolves automatically) | required |
| `context_texts` | 上下文/语气指令 (tone instructions for v2.0 voices) | `""` |
| `emotion` | 情绪 (emotion label) | `""` |
| `emotion_scale` | Emotion intensity 1–5 | `3` |
| `speech_rate` | 语速 (relative, e.g. -2 to 2) | `0` |
| `loudness_rate` | 音量 (relative) | `0` |
| `pitch` | 音高 (relative) | `0` |

**⚠️ IMPORTANT - Resource ID:** Each voice requires the correct `resource_id` from the voice list. The script `tts_generate.sh` fetches the list and fills it automatically.

**🎭 Voice Instructions (语音指令):** Only **v2.0 voices** support emotion instructions like `【温柔地】【严肃地】【兴奋地】` in the text, or use `--context-texts "用沉稳专业的语气"` for tone control.

Response: binary **audio/mpeg** (mp3). Save to file (e.g. `--output out.mp3`) and return path to user.

**Helper script:**

```bash
# List voices
{baseDir}/scripts/tts_voice_list.sh
# or: curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/voices/list"

# Generate TTS (script auto-resolves resource_id from voice list)
{baseDir}/scripts/tts_generate.sh "要合成的文字" "voice_type_from_list" [--output out.mp3] \
  [--context-texts "语气/上下文指令"] [--emotion "情绪"] [--emotion-scale N] \
  [--speech-rate N] [--loudness-rate N] [--pitch N]
```

Script env: `LIGHTX2V_CLOUD_URL` (or base URL), `LIGHTX2V_CLOUD_TOKEN` (optional). Optional params: `--context-texts` (上下文/语气), `--emotion`, `--emotion-scale` (default 3), `--speech-rate`, `--loudness-rate`, `--pitch` (defaults 0).

Recommended voices for digital human: Male `zh_male_ruyayichen_saturn_bigtts` (儒雅逸辰), Female `zh_female_vv_uranus_bigtts` (Vivi 2.0); both v2.0, support voice instructions.

---

## Voice Clone (音色克隆)

Clone a voice from a short audio sample, then synthesize speech with that voice. Same base URL and token; requires auth.

1. **Clone:** `POST /api/v1/voice/clone` — **multipart/form-data**: `file` (audio file, WAV preferred), optional `text` (transcript; if omitted, server uses ASR). Response: `{ speaker_id, text, message }`. Use `speaker_id` for clone TTS and save.
2. **Synthesize with cloned voice:** `POST /api/v1/voice/clone/tts` — JSON: `{ text, speaker_id, style?: "正常", speed?: 1.0, volume?: 0, pitch?: 0, language?: "ZH_CN" }`. Response: binary **audio/wav**. **Note:** Voice cloning does NOT support voice instructions (语音指令) like 【温柔地】.
3. **Save to collection (optional):** `POST /api/v1/voice/clone/save` — JSON: `{ speaker_id, name }`.
4. **List clones:** `GET /api/v1/voice/clone/list` — returns `{ voice_clones: [...] }`.
5. **Delete clone:** `DELETE /api/v1/voice/clone/{speaker_id}`.

**Helper scripts:**

```bash
# Clone from audio file; prints speaker_id
{baseDir}/scripts/voice_clone.sh /path/to/audio.wav [--text "音频对应的文字"]

# TTS with cloned voice; saves WAV to --output (default voice_clone_tts.wav)
{baseDir}/scripts/voice_clone_tts.sh <speaker_id> "要说的文字" [--output out.wav]

# List user's cloned voices
curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" \
  "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/voice/clone/list"
```

---

## When to Use This Skill

Use **lightx2v** (cloud) only when the user’s request does **not** involve adult or restricted (成人/限制级/NSFW) content. If it does, use **lightx2v-local** instead.

- User asks to **generate an image** from text (non-adult) → task `t2i`, get model from list.
- User asks to **edit or modify an image** (non-adult) → task `i2i`, require one input image + prompt.
- User asks to **generate a video** from text (non-adult) → task `t2v`.
- User asks to **animate an image** or **image to video** (non-adult) → task `i2v`, require input image + prompt.
- User asks for **digital human / talking head** video (face + voice, non-adult) → task `s2v`, require input_image + input_audio; prompt can be a space.
- User asks to **convert text to speech** or **TTS** with a preset voice → use `GET /api/v1/voices/list` to pick `voice_type`, then `POST /api/v1/tts/generate`; return the saved MP3 path or URL.
- User asks to **clone a voice** from an audio sample → `POST /api/v1/voice/clone` with the audio file; then use `speaker_id` for `POST /api/v1/voice/clone/tts` to synthesize with that voice. Optionally save with `/api/v1/voice/clone/save`.

Always ensure `LIGHTX2V_CLOUD_TOKEN` (and optionally `LIGHTX2V_CLOUD_URL`) are set before calling the API.

---

## 把本 Skill 传到 GitHub

若你想把 **lightx2v** 作为独立仓库发布到 GitHub（方便他人 `git clone` 或通过 clawhub 安装），可按以下步骤操作。

### 1. 在 GitHub 上建仓库

- 打开 https://github.com/new
- 仓库名建议：`openclaw-skill-lightx2v` 或 `lightx2v-openclaw-skill`
- 选择 **Public**，可不勾选 “Add a README”（本地已有文件）
- 创建后记下仓库地址，例如：`https://github.com/你的用户名/openclaw-skill-lightx2v.git`

### 2. 在本地只针对 lightx2v 建新仓库并推送

在**本机**新开一个目录，只放 skill 内容并初始化 git，再推送到 GitHub：

```bash
# 新建目录并进入
mkdir -p /tmp/openclaw-skill-lightx2v && cd /tmp/openclaw-skill-lightx2v

# 复制当前 skill 内容（仅 skill 自身，不含 workspace 其他文件）
cp -r /home/gongruihao/.openclaw/workspace/skills/lightx2v/* .

# 初始化 git 并首次提交
git init
git add .
git commit -m "Initial commit: LightX2V OpenClaw skill"

# 添加远程并推送（替换为你的 GitHub 仓库地址）
git remote add origin https://github.com/你的用户名/openclaw-skill-lightx2v.git
git branch -M main
git push -u origin main
```

若已有 `install.sh`、`README.md` 等，放在 skill 根目录一并复制即可；没有的话可在仓库里后续再加。

### 3. 可选：加 .gitignore

在仓库根目录创建 `.gitignore`，避免把本地私密或临时文件推上去：

```
.env
*.local
__pycache__/
.DS_Store
```

然后执行：

```bash
git add .gitignore && git commit -m "Add .gitignore" && git push
```

### 4. 他人安装方式

安装方式可写在仓库的 README 里，例如：

```bash
git clone https://github.com/你的用户名/openclaw-skill-lightx2v.git
cd openclaw-skill-lightx2v
# 将 SKILL.md 与 scripts/ 复制到 OpenClaw 的 skills 目录，或运行你的 install.sh
cp -r . ~/.openclaw/workspace/skills/lightx2v/
```

若你后续做了 `install.sh`（参考 openclaw-xhs），也可以写「运行 `./install.sh` 即可安装」。
