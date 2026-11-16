#!/bin/sh
# HUD v5 pictures: the 1280x800 layout drawn at 2x, thirteen states x full and core, as 2560x1600 lossless WebP in docs/images/hud-v5/.
# Usage: sh shoot_final.sh [picks, e.g. cell:A,side:B]  (default: source/picks.json, else all A; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
out=$(dirname "$src")
ff=/Applications/Firefox.app/Contents/MacOS/firefox
cwebp=$(command -v cwebp || echo /opt/homebrew/bin/cwebp)
url=http://127.0.0.1:8767/docs/images/hud-v5/source/round1.html
saved_picks() {
  [ -f "$src/picks.json" ] || return 0
  python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(",".join(k + ":" + v["pick"] for k, v in d.items() if v.get("pick")))' "$src/picks.json"
}
picks=${1:-$(saved_picks)}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/profile"

shoot() { # tier state
  png="$tmp/$1-$2.png"
  "$ff" --headless --no-remote --profile "$tmp/profile" --window-size=2560,1600 \
    --screenshot "$png" "$url#shot=$2&size=1280&scale=2&tier=$1&picks=$picks" >/dev/null 2>&1 &
  pid=$!
  n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 60 ]; do sleep 1; n=$((n + 1)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "firefox hung on $1-$2" >&2; return 1; fi
  [ -s "$png" ] || { echo "no screenshot for $1-$2" >&2; return 1; }
  "$cwebp" -quiet -lossless -z 9 -exact "$png" -o "$out/$1-$2.webp"
}

for tier in full core; do
  for state in none one many factory plant full builder build place blocked enemy pile site; do
    shoot "$tier" "$state"
  done
done
