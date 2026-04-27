# Voice Clone Reference

Clone a voice from a short audio sample, then synthesize speech with that voice. Same base URL and token; requires auth.

## Endpoints

1. **Clone:** `POST /api/v1/voice/clone` — **multipart/form-data**: `file` (audio file, WAV preferred), optional `text` (transcript; if omitted, server uses ASR). Response: `{ speaker_id, text, message }`. Use `speaker_id` for clone TTS and save.
2. **Synthesize with cloned voice:** `POST /api/v1/voice/clone/tts` — JSON: `{ text, speaker_id, style?: "normal", speed?: 1.0, volume?: 0, pitch?: 0, language?: "ZH_CN" }`. Response: binary **audio/wav**. **Note:** Voice cloning does NOT support voice instructions like 【gently】.
3. **Save to collection (optional):** `POST /api/v1/voice/clone/save` — JSON: `{ speaker_id, name }`.
4. **List clones:** `GET /api/v1/voice/clone/list` — returns `{ voice_clones: [...] }`.
5. **Delete clone:** `DELETE /api/v1/voice/clone/{speaker_id}`.

## Helper Scripts

```bash
# Clone from audio file; prints speaker_id
{baseDir}/scripts/voice_clone.sh /path/to/audio.wav [--text "Transcript of the audio"]

# TTS with cloned voice; saves WAV to --output (default voice_clone_tts.wav)
{baseDir}/scripts/voice_clone_tts.sh <speaker_id> "Text to speak" [--output out.wav]

# List user's cloned voices
curl -s -H "Authorization: Bearer $LIGHTX2V_CLOUD_TOKEN" \
  "${LIGHTX2V_CLOUD_URL:-https://x2v.light-ai.top}/api/v1/voice/clone/list"
```
