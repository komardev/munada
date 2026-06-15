#!/usr/bin/env bash
# Install the latest Munada release into /Applications.
# Downloading via curl (not a browser) means macOS doesn't quarantine the app,
# so it launches without a Gatekeeper prompt.
#
#   curl -fsSL https://raw.githubusercontent.com/komardev/munada/main/scripts/install.sh | bash

set -euo pipefail

URL="https://github.com/komardev/munada/releases/latest/download/Munada.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Munada…"
curl -fsSL "$URL" -o "$TMP/Munada.zip"

echo "Installing to /Applications…"
osascript -e 'tell application "Munada" to quit' >/dev/null 2>&1 || true
rm -rf /Applications/Munada.app
ditto -x -k "$TMP/Munada.zip" /Applications

open /Applications/Munada.app
echo "Done — Munada is now in your menu bar."
