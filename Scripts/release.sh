#!/bin/bash
set -euo pipefail
ENOUGH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENOUGH_DIST="${ENOUGH_OUTPUT_DIR:-$ENOUGH_ROOT/dist}"
ENOUGH_VERSION="$(cat "$ENOUGH_ROOT/VERSION")"
: "${ENOUGH_SIGN_IDENTITY:?Set a Developer ID Application identity}"
: "${ENOUGH_NOTARY_KEY:?Set the path to an App Store Connect API key}"
: "${ENOUGH_NOTARY_KEY_ID:?Set the API key ID}"
: "${ENOUGH_NOTARY_ISSUER:?Set the API issuer}"
export ENOUGH_OUTPUT_DIR="$ENOUGH_DIST"
"$ENOUGH_ROOT/Scripts/check.sh"
"$ENOUGH_ROOT/Scripts/build.sh"
ENOUGH_APP="$ENOUGH_DIST/Enough.app"
ENOUGH_ZIP="$ENOUGH_DIST/Enough-$ENOUGH_VERSION-universal.zip"
ditto -c -k --keepParent "$ENOUGH_APP" "$ENOUGH_ZIP"
ENOUGH_NOTARY_ARGS=(--key "$ENOUGH_NOTARY_KEY" --key-id "$ENOUGH_NOTARY_KEY_ID" --issuer "$ENOUGH_NOTARY_ISSUER" --wait)
xcrun notarytool submit "$ENOUGH_ZIP" "${ENOUGH_NOTARY_ARGS[@]}" --output-format json > "$ENOUGH_DIST/app-notarization.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$ENOUGH_DIST/app-notarization.json"
xcrun stapler staple "$ENOUGH_APP"
ditto -c -k --keepParent "$ENOUGH_APP" "$ENOUGH_ZIP"
ENOUGH_STAGE="$(mktemp -d)"
trap 'rm -rf "$ENOUGH_STAGE"' EXIT
ditto "$ENOUGH_APP" "$ENOUGH_STAGE/Enough.app"
ln -s /Applications "$ENOUGH_STAGE/Applications"
cat > "$ENOUGH_STAGE/Install.txt" <<'TEXT'
Enough

1. Drag Enough to Applications.
2. Open Enough. Grant Accessibility access when it asks.
3. Supported permission requests are now approved automatically.

Enough clicks Allow for file and app-data requests from any app.
This grants real access. Use the menu bar icon to pause or quit.

https://github.com/jtc268/enough
TEXT
ENOUGH_DMG="$ENOUGH_DIST/Enough-$ENOUGH_VERSION-universal.dmg"
hdiutil create -volname Enough -srcfolder "$ENOUGH_STAGE" -ov -format UDZO "$ENOUGH_DMG"
codesign --force --timestamp --sign "$ENOUGH_SIGN_IDENTITY" "$ENOUGH_DMG"
xcrun notarytool submit "$ENOUGH_DMG" "${ENOUGH_NOTARY_ARGS[@]}" --output-format json > "$ENOUGH_DIST/dmg-notarization.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$ENOUGH_DIST/dmg-notarization.json"
xcrun stapler staple "$ENOUGH_DMG"
"$ENOUGH_ROOT/Scripts/verify-release.sh" "$ENOUGH_APP" "$ENOUGH_DMG"
cd "$ENOUGH_DIST"
shasum -a 256 "Enough-$ENOUGH_VERSION-universal.dmg" "Enough-$ENOUGH_VERSION-universal.zip" > SHA256SUMS.txt
