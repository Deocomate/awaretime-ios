#!/usr/bin/env bash
# Builds AwareTime for a device without code signing and packages it as an
# .ipa. The result installs only after being re-signed (Sideloadly, AltStore,
# ios-app-signer, …) — see docs/BUILD.md.
#
# Usage: ./Tools/build_unsigned_ipa.sh [output-directory]
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="${1:-build/ipa}"
DERIVED="build/unsigned"

echo "==> Regenerating Xcode project"
python3 Tools/generate_xcodeproj.py
python3 Tools/validate_xcodeproj.py

echo "==> Building (Release, iphoneos, unsigned)"
xcodebuild \
  -project AwareTime.xcodeproj \
  -scheme AwareTime \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  clean build

APP_PATH="$(find "$DERIVED/Build/Products/Release-iphoneos" -maxdepth 1 -name '*.app' | head -n 1)"
if [ -z "$APP_PATH" ]; then
  echo "error: no .app product was produced" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist")"
NAME="AwareTime-${VERSION}-unsigned"

echo "==> Embedded extensions"
ls -1 "$APP_PATH/PlugIns"

echo "==> Packaging $NAME.ipa"
rm -rf build/payload
mkdir -p build/payload/Payload "$OUT_DIR"
cp -R "$APP_PATH" build/payload/Payload/
(cd build/payload && zip -qry "../../$OUT_DIR/$NAME.ipa" Payload)

echo "==> Done: $OUT_DIR/$NAME.ipa"
ls -lh "$OUT_DIR/$NAME.ipa"
