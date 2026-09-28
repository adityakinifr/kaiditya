#!/bin/bash
# Build, install, launch Kaiditya in the booted simulator, then screenshot.
set -e
DEV=${KAIDITYA_SIM:-$(xcrun simctl list devices booted | grep -oE "[0-9A-F-]{36}" | head -1)}
[ -z "$DEV" ] && { echo "Boot a simulator first (or set KAIDITYA_SIM)"; exit 1; }
SHOT=${1:-/tmp/kaiditya_run.png}

echo "▸ Building..."
xcodebuild -project Kaiditya.xcodeproj -scheme Kaiditya -sdk iphonesimulator \
  -configuration Debug -destination "id=$DEV" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -40

APP=$(find build/Build/Products -name "Kaiditya.app" -type d | head -1)
xcrun simctl boot $DEV 2>/dev/null || true
open -a Simulator
xcrun simctl terminate $DEV com.kaiditya.game 2>/dev/null || true
xcrun simctl install $DEV "$APP"
rm -f /tmp/kaiditya_console.log
xcrun simctl launch --console-pty $DEV com.kaiditya.game > /tmp/kaiditya_console.log 2>&1 &
sleep 6
xcrun simctl io $DEV screenshot "$SHOT" 2>&1 | tail -1
echo "=== console (errors) ==="
grep -iE "fatal|error|exception|nil" /tmp/kaiditya_console.log | head -10 || echo "(clean)"
