#!/bin/sh
# Copyright (c) 2026 Lucas Van De Weerd. MIT.
# Stop Retrofind and SearXNG and remove everything install.sh created.
set -eu

for label in org.retrofind.web org.retrofind.searxng; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$label.plist"
done
rm -rf "$HOME/Library/Application Support/Retrofind" "$HOME/Library/Logs/Retrofind"
echo "Retrofind removed."
