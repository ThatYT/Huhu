#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${HUHU_DIST:-$ROOT/dist}"
APP="$DIST/macos/Huhu.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST/validation"
for ARCH in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -target "$ARCH-apple-macosx13.0" \
    -framework AppKit -framework QuartzCore -framework ServiceManagement "$ROOT/macos/Huhu.swift" \
    -o "$DIST/macos/Huhu-$ARCH"
done
xcrun lipo -create "$DIST/macos/Huhu-arm64" "$DIST/macos/Huhu-x86_64" -output "$APP/Contents/MacOS/Huhu"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/assets/Huhu.png" "$APP/Contents/Resources/Huhu.png"
cp "$ROOT/assets/Huhu.icns" "$APP/Contents/Resources/Huhu.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/Huhu" --self-test > "$DIST/validation/macos.json"
STAGE="$DIST/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Huhu.app"
ln -sfn /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/Read me.md"
hdiutil create -ov -volname Huhu -srcfolder "$STAGE" -format UDZO "$DIST/Huhu-1.2.1-macos-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Huhu-1.2.1-macos-universal.zip"
printf 'Built macOS DMG and ZIP in %s\n' "$DIST"
