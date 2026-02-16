#!/bin/bash
# Pollinations Model Listing
# Usage: ./models.sh [--type text|image|audio|vision|video]

set -e

TYPE="${1:-all}"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TYPE="$2"
      shift 2
      ;;
    text|image|audio|vision|video|all)
      TYPE="$1"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

case "$TYPE" in
  text)
    echo "=== Text/Chat Models ==="
    curl -s "https://gen.pollinations.ai/v1/models" | jq -r '.[].id' 2>/dev/null || \
    curl -s "https://gen.pollinations.ai/v1/models" | jq -r '.data[].id' 2>/dev/null
    ;;
  image)
    echo "=== Image Models ==="
    curl -s "https://gen.pollinations.ai/image/models" | jq -r '.[] | select(.output_modalities? // [] | index("image")) | .id // .name' 2>/dev/null || \
    curl -s "https://gen.pollinations.ai/image/models" | jq -r '.[].id // .[].name' 2>/dev/null
    ;;
  video)
    echo "=== Video Models ==="
    curl -s "https://gen.pollinations.ai/image/models" | jq -r '.[] | select(.output_modalities? // [] | index("video")) | .id // .name' 2>/dev/null || \
    echo "veo"
    echo "seedance"
    ;;
  audio)
    echo "=== Audio/TTS Models ==="
    echo "openai-audio"
    ;;
  vision)
    echo "=== Vision Models (image analysis) ==="
    curl -s "https://gen.pollinations.ai/text/models" | jq -r '.[] | select(.input_modalities? // [] | index("image")) | .id // .name' 2>/dev/null || \
    echo "gemini"
    echo "gemini-large"
    echo "claude"
    echo "openai"
    ;;
  all)
    echo "=== Text/Chat Models ==="
    curl -s "https://gen.pollinations.ai/v1/models" | jq -r '.[].id // .data[].id' 2>/dev/null
    echo ""
    echo "=== Image Models ==="
    curl -s "https://gen.pollinations.ai/image/models" | jq -r '.[].id // .[].name' 2>/dev/null
    echo ""
    echo "=== Video Models ==="
    echo "veo"
    echo "seedance"
    echo ""
    echo "=== Audio/TTS ==="
    echo "openai-audio"
    ;;
  *)
    echo "Usage: models.sh [--type text|image|audio|vision|video|all]"
    exit 1
    ;;
esac
