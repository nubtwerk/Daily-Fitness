#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

SIM_NAME="${1:-iPhone 17}"
DERIVED="$ROOT/.derived"

cd "$ROOT"
xcodegen generate

xcodebuild \
  -scheme DailyFitness \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED" \
  build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/DailyFitness.app"
SIM_ID=$(xcrun simctl list devices available | awk -F '[()]' -v name="$SIM_NAME" '$0 ~ name && $0 !~ /unavailable/ { print $2; exit }')

echo "Simulator: $SIM_NAME ($SIM_ID)"
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$SIM_ID" "$APP"
xcrun simctl launch "$SIM_ID" app.dailybase.dailyfitness

echo "DailyFitness launched on $SIM_NAME"
