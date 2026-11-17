#!/bin/bash
# Restarts MouseButtons so it picks up changes to config.json (no rebuild, permission stays).
DIR="$(cd "$(dirname "$0")" && pwd)"
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$DIR/config.json" 2>/dev/null; then
  echo "config.json has a syntax error — fix it first (check commas and quotes)."
  exit 1
fi
launchctl kickstart -k "gui/$(id -u)/com.q.mousebuttons" && echo "MouseButtons reloaded."
sleep 1; tail -n 2 "$DIR/mousebuttons.log" 2>/dev/null
