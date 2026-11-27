#!/bin/sh
# Makes the App Store pictures in store/screenshots from raw screenshots.
#   tools/store-shots.sh <folder of raw screenshots>
# Needs Google Chrome. Run from the repository root.
set -e
RAW=$(cd "$1" && pwd)
ROOT=$(pwd)
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE=$(mktemp -d)
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
# shot <out> <w> <h> <headline> <line> <images, comma separated> [fit] [bg] [cols]
shot() {
  out="$ROOT/store/screenshots/$1"; mkdir -p "$(dirname "$out")"
  imgs=$(echo "$6" | sed "s|[^,]*|file://$RAW/&|g")
  url="file://$ROOT/tools/store-shots.html?w=$2&h=$3&t=$(enc "$4")&s=$(enc "$5")&img=$(enc "$imgs")"
  [ -n "$7" ] && url="$url&fit=$7"
  [ -n "$8" ] && url="$url&bg=$(enc "$8")"
  [ -n "$9" ] && url="$url&cols=$9"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=$2,$3 --user-data-dir="$PROFILE" --virtual-time-budget=4000 \
    --screenshot="$out" "$url" >/dev/null 2>&1
  echo "$1 $(sips -g pixelWidth -g pixelHeight "$out" | tail -2 | awk '{print $2}' | tr '\n' ' ')"
}
# iPhone: 1206 x 2622, the size App Store Connect asks for
shot iphone/1-on-tape.png      1206 2622 "Your music, on tape" "Albums and playlists become cassettes with two sides." ip-tape-80s.png
shot iphone/2-feel-it.png      1206 2622 "Keys that clunk. Reels that turn." "Every key, the door and the fader click under your thumb." ip-tape-black.png "" "#3a3a3d,#0d0d0f"
shot iphone/3-eats-tape.png    1206 2622 "Sometimes the deck eats your tape" "Lean on a reel too long. Then wind it back in." ip-eaten.png
shot iphone/4-colours.png      1206 2622 "Pick your colour" "Retro 80s, black, yellow or blue." ip-tape-80s.png,ip-tape-black.png,ip-tape-yellow.png,ip-tape-blue.png 0.86 "" 2
shot iphone/5-flip.png         1206 2622 "Two sides. You flip it." "When side A runs out, turn the tape over." ip-tape-blue.png "" "#2a4f8f,#101a33"
# Folding iPhone, cover screen: 1398 x 2034
shot duo/1-cover.png           1398 2034 "The whole cover is a tape deck" "Made for the folding iPhone." duo-closed.png 0.66
shot duo/2-colours.png         1398 2034 "Pick your colour" "Retro 80s, black, yellow or blue." duo-closed.png,duo-black.png,duo-yellow.png,duo-blue.png 0.86 "" 2
# Folding iPhone, open and upright: 2007 x 2853
shot duo/3-recorder.png        2007 2853 "Open it up: a tape recorder" "A speaker grille, a tinted door and chunky keys." duo-upright.png 0.72
shot duo/4-eats-tape.png       2007 2853 "Sometimes the deck eats your tape" "Lean on a reel too long. Then wind it back in." duo-eaten.png 0.72
# Folding iPhone, open and sideways: 2853 x 2007
shot duo/5-library.png         2853 2007 "Your library beside the player" "Tap a song and the tape goes straight to it." duo-open.png 0.66
rm -rf "$PROFILE"
