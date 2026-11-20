#!/bin/sh
# Regenerates the templ, Tailwind and islands output in a temporary copy and fails when it differs from the committed files.
set -eu

cd "$(dirname "$0")/.."
sh tools/fetch.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/warroom"
tar --exclude=.bin --exclude=picks.json --exclude=node_modules -cf - . | tar -xf - -C "$tmp/warroom"
ln -s "$PWD/.bin" "$tmp/warroom/.bin"
rm -f "$tmp"/warroom/*_templ.go "$tmp/warroom/static/app.css" "$tmp/warroom/static/islands.js"
(cd "$tmp/warroom" && go generate ./... >"$tmp/generate.log" 2>&1) || {
	cat "$tmp/generate.log" >&2
	exit 1
}

status=0
for f in *_templ.go static/app.css static/islands.js; do
	if ! cmp -s "$f" "$tmp/warroom/$f"; then
		echo "check_generated: $f is out of date; run 'go generate ./...' in warroom/" >&2
		status=1
	fi
done
for f in "$tmp"/warroom/*_templ.go; do
	[ -f "$(basename "$f")" ] || { echo "check_generated: $(basename "$f") is missing; run 'go generate ./...' in warroom/" >&2; status=1; }
done
exit "$status"
