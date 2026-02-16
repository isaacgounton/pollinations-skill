#!/bin/bash
# Pollinations Video Analysis
# Usage: ./analyze-video.sh "video_url_or_file" [--prompt "describe this"] [--model gemini]

set -e

VIDEO_INPUT="$1"
shift || true

# Defaults
PROMPT="${PROMPT:-Describe this video in detail}"
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

if [[ -z "$VIDEO_INPUT" ]]; then
  echo "Usage: analyze-video.sh <video_url_or_file> [--prompt \"...\"] [--model gemini]"
  echo "Models: gemini, gemini-large, claude, openai (video-capable models)"
  echo "Formats: MP4, MOV, AVI"
  exit 1
fi

# Build message content based on input type
if [[ -f "$VIDEO_INPUT" ]]; then
  # Local file: convert to base64
  FORMAT="mp4"
  case "$VIDEO_INPUT" in
    *.mov) FORMAT="mov" ;;
    *.avi) FORMAT="avi" ;;
  esac
  BASE64_DATA=$(base64 -w0 "$VIDEO_INPUT")
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
          {type: "input_video", input_video: {data: $data, format: $format}}
        ]
      }]
    }')
else
  # URL input
  BODY=$(jq -n -c \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --arg url "$VIDEO_INPUT" \
    '{
      model: $model,
      messages: [{
        role: "user",
        content: [
          {type: "text", text: $prompt},
          {type: "video_url", video_url: {url: $url}}
        ]
      }]
    }')
fi

# Make request
echo "Analyzing video with $MODEL..."

RESPONSE=$(curl -s -H "Content-Type: application/json" \
  ${POLLINATIONS_API_KEY:+-H "Authorization: Bearer $POLLINATIONS_API_KEY"} \
  -X POST "https://gen.pollinations.ai/v1/chat/completions" \
  -d "$BODY")

# Extract result
RESULT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -n "$RESULT" ]]; then
  echo "$RESULT"
else
  echo "Error: Failed to analyze video"
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
