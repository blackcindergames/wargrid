#!/bin/sh
# Copies the gate page and what it loads from the repo into site/ at the same paths.
set -eu
repo=$HOME/projects/wargrid
here=$(cd "$(dirname "$0")" && pwd)
rm -rf "$here/site"
src=docs/images/hud-v5/source
mkdir -p "$here/site/$src" "$here/site/game/fonts"
for f in p2-3a1-gate.html p2-3a1-states.html hud.css server.py; do cp "$repo/$src/$f" "$here/site/$src/"; done
cp "$repo"/game/fonts/PublicSans-*.ttf "$here/site/game/fonts/"
