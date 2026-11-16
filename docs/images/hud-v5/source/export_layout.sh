#!/bin/sh
# Writes docs/images/hud-v5/layout.json (HUD rects for the Godot layout tests) through headless Firefox and the page's #layout hash.
# Usage: sh export_layout.sh [picks, e.g. cell:A,side:B]  (default: the page reads source/picks.json, else all A; needs python3 server.py running)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
out="$(dirname "$src")/layout.json"
ff=/Applications/Firefox.app/Contents/MacOS/firefox
url=http://127.0.0.1:8767/docs/images/hud-v5/source/round1.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
touch "$tmp/start"
"$ff" --headless --no-remote --profile "$tmp" "$url#layout&picks=${1:-}" >/dev/null 2>&1 &
pid=$!
n=0
while ! [ "$out" -nt "$tmp/start" ] && [ "$n" -lt 120 ]; do sleep 1; n=$((n + 1)); done
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
[ "$out" -nt "$tmp/start" ] || { echo "layout.json was not rewritten" >&2; exit 1; }
python3 -I - "$out" <<'EOF'
import json, sys
doc = json.load(open(sys.argv[1]))
bad = []
for s in doc["screens"]:
    w, h = s["size"]
    pct = 100 * sum(r["w"] * r["h"] for r in s["rects"] if r.get("covers")) * s["k"] ** 2 / (w * h)
    if abs(pct - s["coverage_pct"]) > 0.02:
        bad.append(f'{s["state"]} {s["tier"]} {w}x{h}: rects {pct:.2f} vs table {s["coverage_pct"]}')
print(f'{len(doc["screens"])} screens, coverage sums {"match" if not bad else "DIFFER"}')
for line in bad:
    print(line)
sys.exit(1 if bad else 0)
EOF
