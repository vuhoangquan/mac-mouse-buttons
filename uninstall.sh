#!/bin/bash
# Stops MouseButtons and removes the app and LaunchAgent.
LABEL="com.q.mousebuttons"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/MouseButtons.app"
echo "MouseButtons removed. You can also delete it from System Settings > Privacy & Security > Accessibility."
