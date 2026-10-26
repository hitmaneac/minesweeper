#!/bin/sh
# Builds build/Minesweeper.app (release). Usage: ./build.sh [--run]
set -e
cd "$(dirname "$0")"

swift build -c release --product Minesweeper
swift build -c release --product mswtool
BIN="$(swift build -c release --show-bin-path)"

APP=build/Minesweeper.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Minesweeper" "$APP/Contents/MacOS/Minesweeper"

"$BIN/mswtool" icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Minesweeper</string>
    <key>CFBundleDisplayName</key><string>Minesweeper</string>
    <key>CFBundleIdentifier</key><string>local.minesweeper.xp</string>
    <key>CFBundleExecutable</key><string>Minesweeper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.puzzle-games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [ "$1" = "--run" ]; then open "$APP"; fi
