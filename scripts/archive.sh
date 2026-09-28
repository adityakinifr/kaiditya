#!/bin/bash
# Build a signed App Store archive + .ipa. Uploading is a separate, explicit step:
#   scripts/archive.sh            -> build/Kaiditya.xcarchive + build/export/Kaiditya.ipa
#   scripts/archive.sh --upload   -> same, then upload to App Store Connect
# Bump the build number first:  BUILD=2 scripts/archive.sh
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "${BUILD:-}" ]; then
  sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$BUILD\"/" project.yml
fi
mkdir -p build
LOG=build/archive.log
xcodegen generate >/dev/null
echo "Archiving (full log: $LOG)..."
xcodebuild -project Kaiditya.xcodeproj -scheme Kaiditya -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Kaiditya.xcarchive \
  -allowProvisioningUpdates archive > "$LOG" 2>&1 || { grep -E "error:" "$LOG" | tail -20; echo "ARCHIVE FAILED - see $LOG"; exit 1; }
echo "Archive succeeded."
OPTS=scripts/ExportOptions.plist
if [ "${1:-}" = "--upload" ]; then
  OPTS=$(mktemp -t export).plist
  sed 's#<string>export</string>#<string>upload</string>#' scripts/ExportOptions.plist > "$OPTS"
fi
echo "$([ "${1:-}" = --upload ] && echo Uploading || echo Exporting) (full log: build/export.log)..."
xcodebuild -exportArchive -archivePath build/Kaiditya.xcarchive -exportOptionsPlist "$OPTS" \
  -exportPath build/export -allowProvisioningUpdates > build/export.log 2>&1 \
  || { grep -iE "error" build/export.log | tail -20; echo "EXPORT/UPLOAD FAILED - see build/export.log"; exit 1; }
grep -E "EXPORT SUCCEEDED|Upload|uploaded" build/export.log || true
echo "Done."
