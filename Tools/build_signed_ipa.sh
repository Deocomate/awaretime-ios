#!/usr/bin/env bash
# Builds a signed, directly installable ad-hoc .ipa using your Apple
# Developer account. Requires Xcode, a logged-in account and the team id.
#
# Usage: APPLE_TEAM_ID=XXXXXXXXXX ./Tools/build_signed_ipa.sh
set -euo pipefail

cd "$(dirname "$0")/.."

: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID to your 10-character Apple Developer team id}"

ARCHIVE="build/AwareTime.xcarchive"
EXPORT_DIR="build/export"

echo "==> Regenerating Xcode project"
python3 Tools/generate_xcodeproj.py

echo "==> Archiving"
xcodebuild \
  -project AwareTime.xcodeproj \
  -scheme AwareTime \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  archive

echo "==> Exporting ad-hoc IPA"
mkdir -p build
sed "s/__TEAM_ID__/$APPLE_TEAM_ID/" Tools/ExportOptions-adhoc.plist > build/ExportOptions.plist
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates

echo "==> Done"
ls -lh "$EXPORT_DIR"/*.ipa
