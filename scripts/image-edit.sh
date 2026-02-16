#!/bin/bash
# Pollinations Image-to-Image Editing
# Usage: ./image-edit.sh "edit instructions" --source "image_url_or_file" [--model kontext] [--seed N] [--output file]

set -e

PROMPT="$1"
shift || true

# Defaults
MODEL="${MODEL:-kontext}"
SEED="${SEED:-}"
OUTPUT="${OUTPUT:-}"
SOURCE=""
NEGATIVE=""

# URL encode function
urlencode() {
  local string="$1"
  local encoded=""
  local length="${#string}"
  for ((i = 0; i < length; i++)); do
    local c="${string:$i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *) encoded+="%$(printf '%X' "'$c")" ;;
    esac
  done
  echo "$encoded"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source|--image)
      SOURCE="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --seed)
      SEED="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --negative)
      NEGATIVE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$PROMPT" || -z "$SOURCE" ]]; then
  echo "Usage: image-edit.sh \"edit instructions\" --source <image_url_or_file> [options]"
  echo ""
  echo "Options:"
  echo "  --source URL/FILE  Source image (URL or local file)"
  echo "  --model MODEL      Model (default: kontext)"
  echo "  --seed N           Seed for reproducibility"
  echo "  --negative TEXT    Negative prompt"
  echo "  --output FILE      Output filename"
  exit 1
fi

# Handle local file: convert to data URL
if [[ -f "$SOURCE" ]]; then
  MIME_TYPE="image/jpeg"
  case "$SOURCE" in
    *.png) MIME_TYPE="image/png" ;;
    *.gif) MIME_TYPE="image/gif" ;;
    *.webp) MIME_TYPE="image/webp" ;;
  esac
  BASE64_DATA=$(base64 -w0 "$SOURCE")
  IMAGE_URL="data:$MIME_TYPE;base64,$BASE64_DATA"
else
  IMAGE_URL="$SOURCE"
fi

# Sanitize prompt
SANITIZED_PROMPT=$(echo "$PROMPT" | sed 's/%/percent/g')

# Build query params
PARAMS="model=$MODEL&image=$(urlencode "$IMAGE_URL")"

if [[ -n "$SEED" ]]; then
  PARAMS="$PARAMS&seed=$SEED"
fi
if [[ -n "$NEGATIVE" ]]; then
  PARAMS="$PARAMS&negative_prompt=$(urlencode "$NEGATIVE")"
fi

# Build URL
ENCODED_PROMPT=$(urlencode "$SANITIZED_PROMPT")
URL="https://gen.pollinations.ai/image/$ENCODED_PROMPT?$PARAMS"

# Determine output filename
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="edited_$(date +%s).jpg"
fi

# Download result
echo "Editing image: $PROMPT"
echo "Model: $MODEL"

if [[ -n "$POLLINATIONS_API_KEY" ]]; then
  curl -s -H "Authorization: Bearer $POLLINATIONS_API_KEY" -o "$OUTPUT" "$URL"
else
  curl -s -o "$OUTPUT" "$URL"
fi

# Check if file was created
if [[ -s "$OUTPUT" ]]; then
  FILE_SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
  echo "Saved to: $OUTPUT ($FILE_SIZE)"
else
  echo "Failed to edit image"
  exit 1
fi
