# TTS (Text-to-Speech) Reference

Preset voices; same base URL and token as image/video endpoints.

## List Voices

`GET /api/v1/voices/list` (optional `?version=...`). Response: `{ voices: [...], emotions?: [...], languages?: [...] }`. Use `voice_type` from list for generate.

## Generate Speech

`POST /api/v1/tts/generate` with JSON:

```json
{
  "text": "Text to synthesize",
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
| `context_texts` | Scene/tone/voice instructions (v2.0 preset voices only) | `""` |
| `emotion` | Emotion label | `""` |
| `emotion_scale` | Emotion intensity 1–5 | `3` |
| `speech_rate` | Speech rate offset (e.g. -2 to 2) | `0` |
| `loudness_rate` | Loudness offset | `0` |
| `pitch` | Pitch offset | `0` |

## Writing Guidelines

- **`text` vs `context_texts`:**
  - **`text`** — Only the script to be read aloud. Do not put scene descriptions, tone, or voice-direction text here.
  - **Scene, tone, and voice direction** (e.g. "gently", "lowered voice", "with breath", "as if whispering") must go in **`context_texts`**. This keeps synthesis stable and lets the model separate "what to read" from "how to read".
- **Pauses and rhythm:** Ellipses may be added where pauses are desired so the delivery has breathing room. Common approach: add ellipses after commas, full stops, and question marks (e.g. `...,`, `....`, `...?`), or use "…" / "……" after words where a pause is needed. See the my_boyfriend skill for dialogue and the `--add-pauses` behaviour.

## Notes

- **resource_id:** Each voice has a matching `resource_id` from the voice list. The script `tts_generate.sh` fetches the list and fills it automatically.
- **Voice instructions scope:** Only **v2.0 preset voices** support `context_texts` and in-text markers like `【gently】`. **v1.0 presets and cloned voices do not** — leave `context_texts` empty and do not rely on 【】 markers for those.

## Recommended Voices

Male `zh_male_ruyayichen_saturn_bigtts`, Female `zh_female_vv_uranus_bigtts` (Vivi 2.0); both v2.0 and support `context_texts`. These are suggestions — more voices are available via `tts_voice_list.sh` or `GET /api/v1/voices/list`; do not hardcode, choose from the list when needed.

## Helper Scripts

```bash
# List voices
{baseDir}/scripts/tts_voice_list.sh

# Generate TTS (script auto-resolves resource_id from voice list)
{baseDir}/scripts/tts_generate.sh "Text to synthesize" "voice_type_from_list" [--output out.mp3] \
  [--context-texts "Scene/tone instructions"] [--emotion "emotion"] [--emotion-scale N] \
  [--speech-rate N] [--loudness-rate N] [--pitch N]
```
