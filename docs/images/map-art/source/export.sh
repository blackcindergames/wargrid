#!/bin/sh
# Writes docs/images/map-art/shapes-picked.json through headless Firefox and the page's #export hash, then checks the corrections.
# Usage: sh export.sh   (needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
art=$(dirname "$src")
out="$art/shapes-picked.json"
ff=/Applications/Firefox.app/Contents/MacOS/firefox
url=http://127.0.0.1:8769/docs/images/map-art/source/round6.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stamp() { python3 -I -c 'import os, sys; print(os.stat(sys.argv[1]).st_mtime_ns if os.path.exists(sys.argv[1]) else 0)' "$out"; }
# Nanosecond mtime, not -nt: /bin/sh compares in whole seconds and misses a rewrite in the same second.
before=$(stamp)
"$ff" --headless --no-remote --profile "$tmp" "$url#export" >/dev/null 2>&1 &
pid=$!
n=0
while [ "$(stamp)" = "$before" ] && [ "$n" -lt 120 ]; do sleep 1; n=$((n + 1)); done
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
[ "$(stamp)" != "$before" ] || { echo "shapes-picked.json was not rewritten" >&2; exit 1; }
python3 -I - "$out" "$src/shapes-current.json" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1]))
today = json.load(open(sys.argv[2]))
shapes = {s["id"]: s for s in doc["shapes"]}
bad = []


def lists(s):
    yield s["parts"]
    yield from s.get("parts_by_detail", {}).values()
    yield from (v["parts"] for v in s.get("damage_variants", {}).values())


def top(s):
    return max(q["offset"][2] + q["size"][2] for parts in lists(s) for p in parts for q in p["prims"])


for s in doc["shapes"]:
    if not s["parts"]:
        bad.append(f'{s["id"]}: no parts')
pickup = shapes["frc_light_vehicle"]
body = next(p for p in pickup["parts"] if p["name"] == "body")["prims"][0]["size"][0]
hull = [q for p in pickup["parts"] if p["angle"] != "turret" for q in p["prims"]]
length = max(q["offset"][0] + q["size"][0] / 2 for q in hull) - min(q["offset"][0] - q["size"][0] / 2 for q in hull)
for what, value in (("body length", body), ("hull length", length)):
    if abs(value - 0.65) > 1e-9:
        bad.append(f"frc_light_vehicle {what} {value}, expected 0.65")
for tank in ("usa_tank", "china_tank", "frc_tank", "china_light_vehicle"):
    if abs(top(shapes[tank]) - 3.0) > 1e-9:
        bad.append(f"{tank} is {top(shapes[tank])} units tall, expected 3.0")
tracks = [q for p in shapes["frc_tank"]["parts"] if p["name"] == "body" for q in p["prims"] if q["slot"] == 2]
if not tracks or any(abs(q["size"][0] - 0.7) > 1e-9 for q in tracks):
    bad.append("frc_tank track length is not 0.7")
missing = doc["meta"]["provisional"]["missing_zoom2"]
lacking = sorted(i for i, s in shapes.items() if "2" not in s.get("parts_by_detail", {}))
if sorted(missing) != lacking:
    bad.append(f"missing_zoom2 {sorted(missing)} differs from the shapes without a zoom 2 list {lacking}")
if set(shapes) != {s["id"] for s in today["shapes"]}:
    bad.append(f"shape ids differ from shapes-current.json: {sorted(set(shapes) ^ {s['id'] for s in today['shapes']})}")
for line in bad:
    print(line)
if not bad:
    print(f"{len(shapes)} shapes, corrections hold")
sys.exit(1 if bad else 0)
PY
