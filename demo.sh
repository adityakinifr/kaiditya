#!/bin/bash
# Build + launch Kaiditya in autopilot (demo) mode, capturing a screenshot
# sequence through the full playthrough for validation.
set -e
DEV=3424D3FB-19AD-4338-B88F-2E901268C3F4
OUT=/tmp/kaiditya_demo
rm -rf "$OUT"; mkdir -p "$OUT"

echo "▸ Building..."
xcodebuild -project Kaiditya.xcodeproj -scheme Kaiditya -sdk iphonesimulator \
  -configuration Debug -destination "id=$DEV" -derivedDataPath build build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -40

APP=$(find build/Build/Products -name "Kaiditya.app" -type d | head -1)
xcrun simctl boot $DEV 2>/dev/null || true
open -a Simulator
xcrun simctl terminate $DEV com.kaiditya.game 2>/dev/null || true
xcrun simctl install $DEV "$APP"

echo "▸ Launching autopilot..."
SIMCTL_CHILD_KAIDITYA_DEMO=1 xcrun simctl launch $DEV com.kaiditya.game >/dev/null 2>&1

FRAMES=${1:-26}
INTERVAL=${2:-1.1}
for i in $(seq -w 1 $FRAMES); do
  xcrun simctl io $DEV screenshot "$OUT/frame_$i.png" >/dev/null 2>&1 || true
  sleep $INTERVAL
done
echo "▸ Captured $FRAMES frames to $OUT"
