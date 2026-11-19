#!/bin/sh
# Screenshots the decision page at a hash with headless Firefox: sh shoot.sh '<hash>' <out.png|out.webp> [WIDTHxHEIGHT]
# A hash with shot=1 is the stage alone; give the frame size as the window size. Needs the server (DP_URL) running.
set -eu
[ $# -ge 2 ] || { echo "usage: sh shoot.sh '<hash>' <out.png|out.webp> [WIDTHxHEIGHT]" >&2; exit 2; }
hash=$1 out=$2 size=${3:-1600x1000}
base=${DP_URL:-http://127.0.0.1:8770/tools/decision_page/}
firefox=${FIREFOX:-/Applications/Firefox.app/Contents/MacOS/firefox}
profile=$(mktemp -d)
png=$profile/shot.png
trap 'rm -rf "$profile"' EXIT
"$firefox" --headless --no-remote --profile "$profile" --window-size "${size%x*},${size#*x}" --screenshot "$png" "$base#$hash" >/dev/null 2>&1
[ -s "$png" ] || { echo "no screenshot for #$hash" >&2; exit 1; }
case $out in
  *.webp) cwebp -quiet -lossless "$png" -o "$out" ;;
  *) cp "$png" "$out" ;;
esac
echo "$out"
