#!/bin/bash
set -euo pipefail
FIXTURE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIST="${1:?Usage: build.sh OUTPUT_DIRECTORY}"
mkdir -p "$FIXTURE_DIST"
xcrun swiftc -O "$FIXTURE_ROOT/Fixture.swift" -o "$FIXTURE_DIST/Fixture"
for FIXTURE_ROLE in owner reader documents desktop downloads; do
  FIXTURE_NAME="Enough Fixture $FIXTURE_ROLE"
  FIXTURE_ID="com.adore.enough.fixture.$FIXTURE_ROLE"
  if [[ "$FIXTURE_ROLE" == "owner" ]]; then FIXTURE_ID="com.adore.enough.fixture.owner-signed"; fi
  FIXTURE_APP="$FIXTURE_DIST/$FIXTURE_NAME.app"
  mkdir -p "$FIXTURE_APP/Contents/MacOS"
  cp "$FIXTURE_DIST/Fixture" "$FIXTURE_APP/Contents/MacOS/Fixture"
  cat > "$FIXTURE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$FIXTURE_ID</string>
<key>CFBundleName</key><string>$FIXTURE_NAME</string>
<key>CFBundleDisplayName</key><string>$FIXTURE_NAME</string>
<key>CFBundleExecutable</key><string>Fixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>FixtureRole</key><string>$FIXTURE_ROLE</string>
<key>NSDocumentsFolderUsageDescription</key><string>Test Enough using a folder listing. Only the entry count is recorded.</string>
<key>NSDesktopFolderUsageDescription</key><string>Test Enough using a folder listing. Only the entry count is recorded.</string>
<key>NSDownloadsFolderUsageDescription</key><string>Test Enough using a folder listing. Only the entry count is recorded.</string>
<key>NSAppDataUsageDescription</key><string>Read one disposable file created by the Enough test owner.</string>
</dict></plist>
PLIST
  if [[ "$FIXTURE_ROLE" == "owner" ]]; then
    cat > "$FIXTURE_DIST/owner.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>
PLIST
    if [[ "${ENOUGH_SIGN_IDENTITY:--}" != "-" ]]; then
      codesign --force --options runtime --timestamp --sign "$ENOUGH_SIGN_IDENTITY" --entitlements "$FIXTURE_DIST/owner.entitlements" "$FIXTURE_APP"
    else
      codesign --force --sign - --entitlements "$FIXTURE_DIST/owner.entitlements" "$FIXTURE_APP"
    fi
  else
    codesign --force --sign - "$FIXTURE_APP"
  fi
done
