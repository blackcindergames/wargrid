#!/bin/sh
# Screenshots a War Room page with headless Firefox: sh shoot.sh '<path?query>' <out.png|out.webp> [WIDTHxHEIGHT]
# A query with shot=1 is the stage alone; give the frame size as the window size. Needs the server (WR_URL) running.
set -eu
[ $# -ge 2 ] || { echo "usage: sh shoot.sh '<path?query>' <out.png|out.webp> [WIDTHxHEIGHT]" >&2; exit 2; }
target=$1 out=$2 size=${3:-1600x1000}
base=${WR_URL:-http://127.0.0.1:8780}
# A phone-sized window would be redirected to phone=1 mid-screenshot, so ask for it up front.
case $target in
  *phone=1* | *shot=1*) ;;
  *\?*) [ "${size%x*}" -gt 900 ] || target="$target&phone=1" ;;
  *) [ "${size%x*}" -gt 900 ] || target="$target?phone=1" ;;
esac
firefox=${FIREFOX:-/Applications/Firefox.app/Contents/MacOS/firefox}
profile=$(mktemp -d)
png=$profile/shot.png
trap 'rm -rf "$profile"' EXIT
"$firefox" --headless --no-remote --profile "$profile" --window-size "${size%x*},${size#*x}" --screenshot "$png" "$base$target" >/dev/null 2>&1
[ -s "$png" ] || { echo "no screenshot for $target" >&2; exit 1; }
case $out in
  *.webp) cwebp -quiet -lossless "$png" -o "$out" ;;
  *) cp "$png" "$out" ;;
esac
echo "$out"
