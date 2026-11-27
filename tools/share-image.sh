#!/bin/sh
# Renders website/images/share.png from tools/share-image.html. Needs Google Chrome.
set -e
ROOT=$(pwd); PROFILE=$(mktemp -d)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1200,630 --user-data-dir="$PROFILE" --virtual-time-budget=4000 \
  --screenshot="$ROOT/website/images/share.png" "file://$ROOT/tools/share-image.html" >/dev/null 2>&1
rm -rf "$PROFILE"; sips -g pixelWidth -g pixelHeight "$ROOT/website/images/share.png" | tail -2
