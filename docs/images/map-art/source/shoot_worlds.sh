#!/bin/sh
# Shoots the HUD v5 world backdrops: headless Firefox on the page's #world hash, 2560x1600 PNG into docs/images/hud-v5/source/worlds/.
# Usage: sh shoot_worlds.sh [state ...]   (no states = all twelve; `full` uses w-factory.png; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$src/../../../.." && pwd)
dest="$root/docs/images/hud-v5/source/worlds"
ff=/Applications/Firefox.app/Contents/MacOS/firefox
url=http://127.0.0.1:8769/docs/images/map-art/source/round6.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
[ "$#" -gt 0 ] || set -- none one many factory plant builder build place blocked enemy pile site
for n in "$@"; do
  png="$tmp/w-$n.png"
  rm -rf "$tmp/profile"
  mkdir -p "$tmp/profile"
  "$ff" --headless --no-remote --profile "$tmp/profile" --window-size=2560,1600 \
    --screenshot "$png" "$url#world=$n&scale=2" >/dev/null 2>&1 &
  pid=$!
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 60 ]; do sleep 1; i=$((i + 1)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "firefox hung on $n" >&2; exit 1; fi
  [ -s "$png" ] || { echo "no screenshot for $n" >&2; exit 1; }
  cp "$png" "$dest/w-$n.png"
done
