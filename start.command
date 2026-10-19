#!/bin/sh
# Copyright (c) 2026 Lucas Van De Weerd. MIT.
# Double-click in Finder: installs Retrofind on first run, starts it, opens it in the browser.
cd "$(dirname "$0")" || exit 1
URL="http://127.0.0.1:${RETROFIND_PORT:-8898}/"
HEALTH="http://127.0.0.1:${RETROFIND_SEARXNG_PORT:-8893}/healthz"

up() { curl -fs -o /dev/null "$URL" && curl -fs -o /dev/null "$HEALTH"; }
wait_up() {
  i=0
  until up; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && return 1
    sleep 1
  done
}

installed=1
for label in org.retrofind.searxng org.retrofind.web; do
  plist="$HOME/Library/LaunchAgents/$label.plist"
  if [ -f "$plist" ]; then
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true # already running is fine
  else
    installed=0
  fi
done

# A missing agent or a moved folder both need a (re)install.
if [ "$installed" = 0 ] || ! wait_up; then
  if ! { sh searxng/install.sh && wait_up; }; then
    printf "\nRetrofind did not start. Logs: ~/Library/Logs/Retrofind\nPress Return to close."
    read -r _
    exit 1
  fi
fi
echo "Retrofind: $URL"
open "$URL"
