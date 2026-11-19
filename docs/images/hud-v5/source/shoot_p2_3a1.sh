#!/bin/sh
# P2.3a1 HUD state pictures: the 1280x720 layout drawn at 2x, as 2560x1440 lossless WebP in docs/images/hud-v5/.
# Usage: sh shoot_p2_3a1.sh [state ...]  (default: every state; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
out=$(dirname "$src")
ff=/Applications/Firefox.app/Contents/MacOS/firefox
cwebp=$(command -v cwebp || echo /opt/homebrew/bin/cwebp)
url=http://127.0.0.1:8767/docs/images/hud-v5/source/p2-3a1-states.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/profile"

shoot() { # state
  png="$tmp/$1.png"
  name="p2-3a1-$1"
  [ "$1" = collector ] && name=collector-status
  "$ff" --headless --no-remote --profile "$tmp/profile" --window-size=2560,1440 \
    --screenshot "$png" "$url#shot=$1&size=720&scale=2" >/dev/null 2>&1 &
  pid=$!
  n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 60 ]; do sleep 1; n=$((n + 1)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "firefox hung on $1" >&2; return 1; fi
  [ -s "$png" ] || { echo "no screenshot for $1" >&2; return 1; }
  "$cwebp" -quiet -lossless -z 9 -exact "$png" -o "$out/$name.webp"
}

if [ "$#" -eq 0 ]; then
  set -- slab notice freeze freeze-copied forecast sites chips chips-f3 chips-f3-rule chips-checklist chips-form chips-off refusal pile rows-footer unload collector
fi
for state in "$@"; do
  shoot "$state"
done
