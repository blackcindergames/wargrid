#!/bin/sh
# Copies the decision page, its rounds and the repository files they reference into site/ at the same paths.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
app=tools/decision_page
site=$here/site
rm -rf "$site"
mkdir -p "$site/$app/rounds"
cd "$repo"
cp "$app/index.html" "$app/app.js" "$app/stage.js" "$app/app.css" "$app/server.py" "$site/$app/"
cp "$app/rounds/index.js" "$site/$app/rounds/"
# Demo rounds stay local: the public site then accepts no demo keys.
for r in "$app"/rounds/*/; do
  r=${r%/} # BSD cp -R copies a slash-ended folder's contents, not the folder
  case $(basename "$r") in demo*) ;; *) cp -R "$r" "$site/$app/rounds/" ;; esac
done

put() { # repository path
  # The site is public: a file Git does not track (an owner mock) stays on this machine.
  git ls-files --error-unmatch -- "$1" >/dev/null 2>&1 || { echo "skipped, not tracked by Git: $1" >&2; return 0; }
  mkdir -p "$site/$(dirname "$1")"
  cp "$1" "$site/$1"
}
links() { # html file: the local files it loads, as repository paths
  dir=$(dirname "$1")
  grep -oE '(href|src)="[^":#$]+"' "$1" | sed -E 's/^(href|src)="//; s/"$//' | while read -r p; do printf '%s/%s\n' "$dir" "$p"; done
}

refs=$(grep -rhoE "(docs|game)/[A-Za-z0-9_./-]+\.(html|css|js|png|webp|jpg|svg|wav|ogg|mp3|webm|mp4)" "$site/$app" | sort -u)
for f in $refs; do
  put "$f"
  case $f in *.html) for d in $(links "$f"); do put "$d"; done ;; esac
done
for f in game/fonts/PublicSans-*.ttf; do put "$f"; done
# Named by the stage controls and by round6.html at run time, not in any round file.
for f in docs/images/hud-v5/source/worlds/w-*.png; do put "$f"; done
put docs/images/hud-v5/layout.json
echo "site: $(find "$site" -type f | wc -l | tr -d ' ') files"
