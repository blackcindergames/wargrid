#!/bin/sh
# Builds site/: the Go sources, the non-demo rounds and the tracked repository files they reference, at the same paths.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
app=warroom
site=$here/site
rm -rf "$site"
mkdir -p "$site/src" "$site/rounds"
cd "$repo/$app"
# The module without tests, templ sources or generated-asset inputs; internal/web/static is embedded.
tar --exclude='*_test.go' --exclude='*.templ' -cf - main.go priv_*.go go.mod go.sum internal | tar -xf - -C "$site/src"
cd "$repo"

# Demo rounds stay local: the public site then accepts no demo keys.
awk 'function flush() { if (blk != "" && blk !~ /demo: true/) printf "%s", blk; blk = "" }
     /^- / { flush() } { blk = blk $0 "\n" } END { flush() }' "$app/rounds/index.yaml" > "$site/rounds/index.yaml"
sed -n 's/^- id: //p' "$site/rounds/index.yaml" | while read -r id; do
  mkdir -p "$site/rounds/$id"
  for f in "$app/rounds/$id"/*; do
    if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then cp "$f" "$site/rounds/$id/"; else echo "skipped, not tracked by Git: $f" >&2; fi
  done
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

refs=$(grep -rhoE "(docs|game)/[A-Za-z0-9_./-]+\.(html|css|js|png|webp|jpg|svg|wav|ogg|mp3|webm|mp4)" "$site/rounds" "$site/src" --include="*.yaml" --include="*.go" | sort -u)
for f in $refs; do
  put "$f"
  case $f in *.html) for d in $(links "$f"); do put "$d"; done ;; esac
done
for f in game/fonts/PublicSans-*.ttf; do put "$f"; done
# Named by the stage controls and by round6.html at run time, not in any round file.
for f in docs/images/hud-v5/source/worlds/w-*.png; do put "$f"; done
put docs/images/hud-v5/layout.json
echo "site: $(find "$site" -type f | wc -l | tr -d ' ') files"
