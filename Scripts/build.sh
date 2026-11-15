#!/bin/bash
set -euo pipefail
ENOUGH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENOUGH_SCRATCH="${ENOUGH_BUILD_DIR:-$ENOUGH_ROOT/.build/package}"
ENOUGH_DIST="${ENOUGH_OUTPUT_DIR:-$ENOUGH_ROOT/dist}"
ENOUGH_IDENTITY="${ENOUGH_SIGN_IDENTITY:--}"
mkdir -p "$ENOUGH_DIST" "$ENOUGH_SCRATCH"
ENOUGH_BINARIES=()
for ENOUGH_ARCH in arm64 x86_64; do
  swift build --package-path "$ENOUGH_ROOT" --scratch-path "$ENOUGH_SCRATCH/$ENOUGH_ARCH" --configuration release --product Enough --triple "$ENOUGH_ARCH-apple-macosx13.0"
  ENOUGH_BIN_DIR="$(swift build --package-path "$ENOUGH_ROOT" --scratch-path "$ENOUGH_SCRATCH/$ENOUGH_ARCH" --configuration release --triple "$ENOUGH_ARCH-apple-macosx13.0" --show-bin-path)"
  ENOUGH_BINARIES+=("$ENOUGH_BIN_DIR/Enough")
done
ENOUGH_APP="$ENOUGH_DIST/Enough.app"
mkdir -p "$ENOUGH_APP/Contents/MacOS" "$ENOUGH_APP/Contents/Resources"
lipo -create "${ENOUGH_BINARIES[@]}" -output "$ENOUGH_APP/Contents/MacOS/Enough"
cp "$ENOUGH_ROOT/Assets/Info.plist" "$ENOUGH_APP/Contents/Info.plist"
cp -R "$ENOUGH_BIN_DIR/Enough_Enough.bundle" "$ENOUGH_APP/Contents/Resources/"
xcrun swift "$ENOUGH_ROOT/Scripts/make-icon.swift" "$ENOUGH_SCRATCH/Enough.iconset"
iconutil -c icns "$ENOUGH_SCRATCH/Enough.iconset" -o "$ENOUGH_APP/Contents/Resources/Enough.icns"
if [[ "$ENOUGH_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$ENOUGH_APP"
else
  codesign --force --options runtime --timestamp --sign "$ENOUGH_IDENTITY" "$ENOUGH_APP"
fi
codesign --verify --strict "$ENOUGH_APP"
lipo -archs "$ENOUGH_APP/Contents/MacOS/Enough"
printf 'Built: %s\n' "$ENOUGH_APP"
