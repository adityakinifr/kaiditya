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
xcodegen generate >/dev/null
xcodebuild -project Kaiditya.xcodeproj -scheme Kaiditya -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Kaiditya.xcarchive \
  -allowProvisioningUpdates archive | grep -E "error:|warning: .*sign|ARCHIVE (SUCCEEDED|FAILED)"
OPTS=scripts/ExportOptions.plist
if [ "${1:-}" = "--upload" ]; then
  OPTS=$(mktemp -t export).plist
  sed 's#<string>export</string>#<string>upload</string>#' scripts/ExportOptions.plist > "$OPTS"
fi
xcodebuild -exportArchive -archivePath build/Kaiditya.xcarchive -exportOptionsPlist "$OPTS" \
  -exportPath build/export -allowProvisioningUpdates | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload"
