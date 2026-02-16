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
  echo ""
  echo "Note: URL sources are faster. Local files are base64-encoded and may be slow for large images."
  exit 1
fi

# Determine output filename
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="edited_$(date +%s).jpg"
fi

# Sanitize prompt
SANITIZED_PROMPT=$(echo "$PROMPT" | sed 's/%/percent/g')
ENCODED_PROMPT=$(urlencode "$SANITIZED_PROMPT")

if [[ -f "$SOURCE" ]]; then
  # Local file: use POST with JSON body to avoid URL length limits
  MIME_TYPE="image/jpeg"
  case "$SOURCE" in
    *.png) MIME_TYPE="image/png" ;;
    *.gif) MIME_TYPE="image/gif" ;;
    *.webp) MIME_TYPE="image/webp" ;;
  esac

  BODY_FILE=$(mktemp /tmp/imgedit_body_XXXXXX.json)
  B64_FILE=$(mktemp /tmp/imgedit_b64_XXXXXX)
  trap "rm -f '$BODY_FILE' '$B64_FILE'" EXIT

  base64 -w0 "$SOURCE" > "$B64_FILE"

  # Build data URL from file to avoid ARG_MAX
  DATA_URL_PREFIX="data:$MIME_TYPE;base64,"

  # Build JSON body with image as data URL
  jq -n -c --rawfile b64data "$B64_FILE" \
    --arg prefix "$DATA_URL_PREFIX" \
    --arg model "$MODEL" \
    --arg prompt "$SANITIZED_PROMPT" \
    --arg seed "$SEED" \
    --arg negative "$NEGATIVE" \
    '{
      prompt: $prompt,
      model: $model,
      image: ($prefix + ($b64data | rtrimstr("\n")))
    }
    | if $seed != "" then . + {seed: ($seed | tonumber)} else . end
    | if $negative != "" then . + {negative_prompt: $negative} else . end
    ' > "$BODY_FILE"

  echo "Editing image: $PROMPT"
  echo "Model: $MODEL (local file, using POST)"

  curl -s --max-time 300 \
    -H "Content-Type: application/json" \
    ${POLLINATIONS_API_KEY:+-H "Authorization: Bearer $POLLINATIONS_API_KEY"} \
    -X POST "https://gen.pollinations.ai/image/$ENCODED_PROMPT" \
    -d @"$BODY_FILE" \
    -o "$OUTPUT"
else
  # URL source: use GET with query params (fast path)
  PARAMS="model=$MODEL&image=$(urlencode "$SOURCE")"

  if [[ -n "$SEED" ]]; then
    PARAMS="$PARAMS&seed=$SEED"
  fi
  if [[ -n "$NEGATIVE" ]]; then
    PARAMS="$PARAMS&negative_prompt=$(urlencode "$NEGATIVE")"
  fi

  URL="https://gen.pollinations.ai/image/$ENCODED_PROMPT?$PARAMS"

  echo "Editing image: $PROMPT"
  echo "Model: $MODEL"

  curl -s --max-time 300 \
    ${POLLINATIONS_API_KEY:+-H "Authorization: Bearer $POLLINATIONS_API_KEY"} \
    -o "$OUTPUT" "$URL"
fi

# Check if file was created
if [[ -s "$OUTPUT" ]]; then
  FILE_SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
  echo "Saved to: $OUTPUT ($FILE_SIZE)"
else
  echo "Failed to edit image"
  exit 1
fi
