#!/bin/zsh
# Captures raw store screenshots of the redesigned app (Pitch Night) in every
# store language on sample data. Needs a DEBUG build installed on the simulator.
#
#   capture_localized_screenshots.sh [DEVICE_ID]     (default: iPhone 17 Pro Max, 1320x2868)
#
# Screens: onboarding (personalization step), matches, analyses, profile.
# The match-detail screen needs a tap and is captured separately (see
# capture_match_detail below, driven by the simulator tool).
set -euo pipefail

DEVICE_ID="${1:-052D311D-7BAA-492A-98F6-B5341027B5D9}"
BUNDLE_ID="com.footballai.predictions.com"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

xcrun simctl ui "$DEVICE_ID" content_size large
xcrun simctl status_bar "$DEVICE_ID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

launch() {
  local app_locale="$1" apple_locale="$2"; shift 2
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -footballai-screenshot-mode \
    -AppleLanguages "($app_locale)" -AppleLocale "$apple_locale" "$@" >/dev/null
  sleep 4
}

capture_locale() {
  local store_locale="$1" app_locale="$2" apple_locale="$3"
  local out="$ROOT/raw/$store_locale"
  mkdir -p "$out"

  launch "$app_locale" "$apple_locale" -footballai-show-onboarding
  # Step 1 is the welcome page; the personalization step is the second one.
  xcrun simctl io "$DEVICE_ID" screenshot "$out/onboarding-welcome.png" >/dev/null 2>&1
  launch "$app_locale" "$apple_locale"
  xcrun simctl io "$DEVICE_ID" screenshot "$out/matches.png" >/dev/null 2>&1
  launch "$app_locale" "$apple_locale" -footballai-screenshot-tab analyses
  xcrun simctl io "$DEVICE_ID" screenshot "$out/history.png" >/dev/null 2>&1
  launch "$app_locale" "$apple_locale" -footballai-screenshot-tab profile
  xcrun simctl io "$DEVICE_ID" screenshot "$out/profile.png" >/dev/null 2>&1
  echo "captured $store_locale"
}

capture_locale en-US en en_US
capture_locale tr tr tr_TR
capture_locale de-DE de de_DE
capture_locale fr-FR fr fr_FR
capture_locale es-ES es es_ES
