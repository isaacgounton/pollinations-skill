#!/bin/bash
# Pollinations Audio Transcription
# Usage: ./transcribe.sh "audio_file_or_url" [--prompt "transcribe this"] [--model gemini]

set -e

AUDIO_INPUT="$1"
shift || true

# Defaults
PROMPT="${PROMPT:-Transcribe this audio accurately. Return only the transcription text, nothing else.}"
MODEL="${MODEL:-gemini}"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$AUDIO_INPUT" ]]; then
  echo "Usage: transcribe.sh <audio_file_or_url> [--prompt \"...\"] [--model gemini]"
  echo "Models: gemini, gemini-large, gemini-legacy, openai-audio"
  echo "Formats: MP3, WAV, FLAC, OGG"
  exit 1
fi

# Build message content
if [[ -f "$AUDIO_INPUT" ]]; then
  # Local file: detect format and convert to base64
  FORMAT="mp3"
  case "$AUDIO_INPUT" in
    *.wav) FORMAT="wav" ;;
    *.flac) FORMAT="flac" ;;
    *.ogg) FORMAT="ogg" ;;
    *.m4a) FORMAT="m4a" ;;
  esac
  BASE64_DATA=$(base64 -w0 "$AUDIO_INPUT")
  BODY=$(jq -n -c \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --arg data "$BASE64_DATA" \
    --arg format "$FORMAT" \
    '{
      model: $model,
      messages: [{
        role: "user",
        content: [
          {type: "text", text: $prompt},
          {type: "input_audio", input_audio: {data: $data, format: $format}}
        ]
      }]
    }')
else
  # URL: download first, then encode
  TEMP_FILE=$(mktemp /tmp/audio_XXXXXX)
  echo "Downloading audio..."
  curl -s -o "$TEMP_FILE" "$AUDIO_INPUT"
  FORMAT="mp3"
  case "$AUDIO_INPUT" in
    *.wav) FORMAT="wav" ;;
    *.flac) FORMAT="flac" ;;
    *.ogg) FORMAT="ogg" ;;
    *.m4a) FORMAT="m4a" ;;
  esac
  BASE64_DATA=$(base64 -w0 "$TEMP_FILE")
  rm "$TEMP_FILE"
  BODY=$(jq -n -c \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --arg data "$BASE64_DATA" \
    --arg format "$FORMAT" \
    '{
      model: $model,
      messages: [{
        role: "user",
        content: [
          {type: "text", text: $prompt},
          {type: "input_audio", input_audio: {data: $data, format: $format}}
        ]
      }]
    }')
fi

# Make request
echo "Transcribing audio with $MODEL..."

RESPONSE=$(curl -s -H "Content-Type: application/json" \
  ${POLLINATIONS_API_KEY:+-H "Authorization: Bearer $POLLINATIONS_API_KEY"} \
  -X POST "https://gen.pollinations.ai/v1/chat/completions" \
  -d "$BODY")

# Extract result
RESULT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -n "$RESULT" ]]; then
  echo "$RESULT"
else
  echo "Error: Failed to transcribe audio"
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
