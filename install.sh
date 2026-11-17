#!/bin/bash
# Builds MouseButtons.app and starts it at login via a LaunchAgent.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/MouseButtons.app"
LABEL="com.q.mousebuttons"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift compiler not found. Installing Command Line Tools — re-run this script when that finishes."
  xcode-select --install || true
  exit 1
fi

echo "==> Building"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -O -swift-version 5 -framework Cocoa -framework ApplicationServices \
  "$SRC_DIR/main.swift" -o "$APP/Contents/MacOS/MouseButtons"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>MouseButtons</string>
  <key>CFBundleExecutable</key><string>MouseButtons</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
# Sign with your Apple Development / Developer ID certificate if you have one, so rebuilding
# keeps the Accessibility permission. Otherwise fall back to ad-hoc signing.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/{print $2; exit}')"
if [ -n "$IDENTITY" ] && codesign --force --sign "$IDENTITY" "$APP" 2>/dev/null; then
  echo "    signed with: $IDENTITY"
else
  codesign --force --sign - "$APP" >/dev/null 2>&1
  echo "    signed ad-hoc (each rebuild will need Accessibility re-granted)"
fi

rm -f "$SRC_DIR/.prompted" "$SRC_DIR/mousebuttons.log"

echo "==> Installing LaunchAgent"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$APP/Contents/MacOS/MouseButtons</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardErrorPath</key><string>$SRC_DIR/mousebuttons.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. One last step:"
echo "  System Settings > Privacy & Security > Accessibility > turn ON 'MouseButtons'"
echo "  IMPORTANT: each rebuild counts as a new app to macOS. If MouseButtons is already listed,"
echo "  select it, click '-' to remove it, then click '+' and add $APP and switch it ON."
echo "  It starts working within ~10 seconds — no restart needed."
echo "Log: $SRC_DIR/mousebuttons.log"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
