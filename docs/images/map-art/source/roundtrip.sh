#!/bin/sh
# Bakes a shapes export through the game's own code in headless Godot, then has the page compare it with its own drawing.
# Usage: sh roundtrip.sh [shapes json]   (default docs/images/map-art/shapes-picked.json; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$src/../../../.." && pwd)
in=${1:-$root/docs/images/map-art/shapes-picked.json}
case $in in /*) ;; *) in="$PWD/$in" ;; esac
case $in in */shapes-current.json) set=today ;; *) set=picked ;; esac
out="$root/build/map-art/roundtrip-godot.json"
mkdir -p "$root/build/map-art"
# A stale file from an earlier run must never be compared.
rm -f "$out"
"${GODOT_BIN:-godot}" --headless --path "$root/game" -s "$src/roundtrip.gd" -- --in="$in" --out="$out" || { echo "roundtrip.gd failed" >&2; exit 1; }
[ -s "$out" ] || { echo "roundtrip-godot.json was not written" >&2; exit 1; }
sh "$src/report.sh" "roundtrip&set=$set" roundtrip
