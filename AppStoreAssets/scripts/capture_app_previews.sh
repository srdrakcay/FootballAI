#!/bin/zsh
set -euo pipefail

DEVICE_ID="${1:-052D311D-7BAA-492A-98F6-B5341027B5D9}"
BUNDLE_ID="com.footballai.predictions.com"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/previews"
mkdir -p "$OUTPUT"

record_locale() {
  local locale="$1"
  local locale_argument="$2"
  local raw="$OUTPUT/${locale}-raw.mov"
  local final="$OUTPUT/${locale}-app-preview.mp4"

  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --force "$raw" &
  local recorder=$!
  sleep 1
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" \
    -footballai-screenshot-mode \
    -footballai-app-preview \
    "$locale_argument"
  sleep 17
  kill -INT "$recorder"
  wait "$recorder" || true

  ffmpeg -y -i "$raw" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
    -vf "scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,fps=30,tpad=stop_mode=clone:stop_duration=8" \
    -c:v libx264 -profile:v high -level 4.0 -b:v 10M -maxrate 12M -bufsize 20M \
    -c:a aac -b:a 256k -ar 48000 -ac 2 -shortest -movflags +faststart \
    -t 17 \
    "$final"
}

record_locale "en-US" "-footballai-screenshot-en"
record_locale "tr" "-footballai-screenshot-tr"
record_locale "de-DE" "-footballai-screenshot-de"
record_locale "fr-FR" "-footballai-screenshot-fr"
record_locale "es-ES" "-footballai-screenshot-es"
