#!/bin/sh
# Copyright (c) 2026 Lucas Van De Weerd. MIT.
# Install SearXNG natively (no Docker) plus the Retrofind page, and keep both running.
set -eu

SEARXNG_COMMIT="a9d99003344ac3879ec45c56c661283482a92a39" # 2026-09-30
SEARXNG_PORT="${RETROFIND_SEARXNG_PORT:-8893}"
WEB_PORT="${RETROFIND_PORT:-8898}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
case "$REPO$HOME" in *[\&\<\>]*) echo "Move Retrofind to a folder without & < > in its path." >&2; exit 1;; esac
HOME_DIR="$HOME/Library/Application Support/Retrofind/searxng"
AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs/Retrofind"

command -v uv >/dev/null 2>&1 || { echo "uv is required: brew install uv" >&2; exit 1; }

mkdir -p "$HOME_DIR" "$LOGS" "$AGENTS"
cd "$HOME_DIR"

if [ ! -d src/.git ]; then
  git clone --quiet https://github.com/searxng/searxng.git src
fi
git -C src fetch --quiet origin "$SEARXNG_COMMIT"
git -C src checkout --quiet "$SEARXNG_COMMIT"

uv venv --quiet --python 3.12 --allow-existing venv
# SearXNG's setup.py imports its own deps, so install them first, then the package without isolation.
uv pip install --quiet --python venv/bin/python -r src/requirements.txt setuptools wheel
uv pip install --quiet --python venv/bin/python --no-build-isolation -e src

if [ ! -f settings.yml ]; then
  SECRET="$(openssl rand -hex 32)"
  cat > settings.yml <<YML
use_default_settings: true
general:
  instance_name: "Retrofind"
search:
  formats: [html, json]
server:
  bind_address: "127.0.0.1"
  port: $SEARXNG_PORT
  secret_key: "$SECRET"
  limiter: false
  image_proxy: true
  method: "GET"
YML
  chmod 600 settings.yml
fi

# agent LABEL PROGRAM... : write a LaunchAgent that keeps PROGRAM running, then (re)load it.
agent() {
  label="$1"; shift
  plist="$AGENTS/$label.plist"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0"><dict>'
    echo "  <key>Label</key><string>$label</string>"
    echo '  <key>ProgramArguments</key><array>'
    for arg in "$@"; do echo "    <string>$arg</string>"; done
    echo '  </array>'
    echo '  <key>EnvironmentVariables</key><dict>'
    echo "    <key>SEARXNG_SETTINGS_PATH</key><string>$HOME_DIR/settings.yml</string>"
    echo '  </dict>'
    echo "  <key>WorkingDirectory</key><string>$HOME_DIR</string>"
    echo '  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>'
    echo "  <key>StandardOutPath</key><string>$LOGS/$label.log</string>"
    echo "  <key>StandardErrorPath</key><string>$LOGS/$label.log</string>"
    echo '</dict></plist>'
  } > "$plist"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
}

agent org.retrofind.searxng "$HOME_DIR/venv/bin/python" -m searx.webapp
agent org.retrofind.web "$HOME_DIR/venv/bin/python" "$REPO/server.py" \
  --port "$WEB_PORT" --searxng "http://127.0.0.1:$SEARXNG_PORT"

printf "Waiting for SearXNG"
i=0
until curl -fs -o /dev/null "http://127.0.0.1:$SEARXNG_PORT/healthz"; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then echo; echo "SearXNG did not start; see $LOGS" >&2; exit 1; fi
  printf "."; sleep 1
done
echo
echo "Retrofind is running at http://127.0.0.1:$WEB_PORT/"
echo "Search URL for the browser: http://127.0.0.1:$WEB_PORT/search?q=%s"
