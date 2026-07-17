#!/bin/zsh
set -euo pipefail

DEVICE_ID="${1:-052D311D-7BAA-492A-98F6-B5341027B5D9}"
BUNDLE_ID="com.footballai.predictions.com"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

capture_locale() {
  local output_locale="$1"
  local locale_argument="$2"
  local output_dir="$ROOT/raw/$output_locale"
  mkdir -p "$output_dir"

  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" \
    -footballai-screenshot-mode \
    -footballai.onboarding.completed.v1 NO \
    "$locale_argument"
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$output_dir/onboarding.png"

  for screen in matches history profile; do
    xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
    local screen_argument=""
    if [[ "$screen" != "matches" ]]; then
      screen_argument="-footballai-screenshot-$screen"
    fi
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" \
      -footballai-screenshot-mode \
      -footballai.onboarding.completed.v1 YES \
      "$locale_argument" \
      "$screen_argument"
    sleep 2
    xcrun simctl io "$DEVICE_ID" screenshot "$output_dir/$screen.png"
  done
}

capture_locale "en-US" "-footballai-screenshot-en"
capture_locale "tr" "-footballai-screenshot-tr"
capture_locale "de-DE" "-footballai-screenshot-de"
capture_locale "fr-FR" "-footballai-screenshot-fr"
capture_locale "es-ES" "-footballai-screenshot-es"
