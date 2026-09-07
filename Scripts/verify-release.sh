#!/bin/bash
set -euo pipefail
ENOUGH_APP="${1:?Usage: verify-release.sh APP DMG}"
ENOUGH_DMG="${2:?Usage: verify-release.sh APP DMG}"
codesign --verify --strict --verbose=2 "$ENOUGH_APP"
codesign -d --verbose=2 "$ENOUGH_APP" 2>&1 | /usr/bin/grep -E 'Authority=Developer ID Application:|TeamIdentifier='
lipo "$ENOUGH_APP/Contents/MacOS/Enough" -verify_arch arm64 x86_64
xcrun stapler validate "$ENOUGH_APP"
spctl --assess --type execute --verbose=2 "$ENOUGH_APP"
codesign --verify --strict --verbose=2 "$ENOUGH_DMG"
xcrun stapler validate "$ENOUGH_DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$ENOUGH_DMG"
