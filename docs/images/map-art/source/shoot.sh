#!/bin/sh
# Shoots map art pictures: headless Firefox on the page's #pic hash, then lossless WebP.
# Usage: [SCALE=1|2] [AS=shot|final] [OUT=dir] [EXTRA='&font=inter'] sh shoot.sh [name ...]   (no names = every picture; step<n>-<A|B>[-dark] review shots also accepted; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$src/../../../.." && pwd)
scale=${SCALE:-2}
as=${AS:-final}
out=${OUT:-docs/images/map-art}
extra=${EXTRA:-}
ff=/Applications/Firefox.app/Contents/MacOS/firefox
cwebp=$(command -v cwebp || echo /opt/homebrew/bin/cwebp)
url=http://127.0.0.1:8769/docs/images/map-art/source/round6.html
listname="pics-$$"
sh "$src/report.sh" "report=pics&name=$listname" "$listname" >/dev/null
sh "$src/report.sh" "report=fonts&name=fonts-$$" "fonts-$$" >/dev/null || { echo "fonts did not load" >&2; exit 1; }
rm -f "$root/build/map-art/fonts-$$.txt"
known=$(grep -v '^PASS' "$root/build/map-art/$listname.txt")
rm -f "$root/build/map-art/$listname.txt"
names=${*:-$known}
for n in $names; do
  printf '%s\n' "$known" | grep -qx -- "$n" || printf '%s\n' "$n" | grep -Eq '^step[0-9]+-[AB](-dark)?$' || { echo "unknown picture $n" >&2; exit 1; }
done
case $out in /*) dest=$out ;; *) dest="$root/$out" ;; esac
mkdir -p "$dest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
w=$((1280 * scale))
h=$((720 * scale))
for n in $names; do
  png="$tmp/$n.png"
  rm -rf "$tmp/profile"
  mkdir -p "$tmp/profile"
  "$ff" --headless --no-remote --profile "$tmp/profile" --window-size="$w,$h" \
    --screenshot "$png" "$url#pic=$n&as=$as&scale=$scale$extra" >/dev/null 2>&1 &
  pid=$!
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 60 ]; do sleep 1; i=$((i + 1)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "firefox hung on $n" >&2; exit 1; fi
  [ -s "$png" ] || { echo "no screenshot for $n" >&2; exit 1; }
  "$cwebp" -quiet -lossless -z 9 -exact "$png" -o "$dest/$n.webp"
done
