#!/bin/sh
# Runs a page report in headless Firefox and prints the file it posts to build/map-art/<name>.txt; exit 0 only when its last line starts with PASS.
# Usage: sh report.sh '<hash without #>' <name>   (needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$src/../../../.." && pwd)
hash=${1:?hash}
name=${2:?report name}
out="$root/build/map-art/$name.txt"
ff=/Applications/Firefox.app/Contents/MacOS/firefox
url=http://127.0.0.1:8769/docs/images/map-art/source/round6.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$root/build/map-art"
# Not an mtime stamp: /bin/sh (bash 3.2) compares -nt in whole seconds and misses a same-second report.
rm -f "$out"
"$ff" --headless --no-remote --profile "$tmp" "$url#$hash" >/dev/null 2>&1 &
pid=$!
n=0
while ! [ -s "$out" ] && [ "$n" -lt 120 ]; do sleep 1; n=$((n + 1)); done
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
[ -s "$out" ] || { echo "$name.txt was not rewritten" >&2; exit 1; }
cat "$out"
tail -n 1 "$out" | grep -q '^PASS'
