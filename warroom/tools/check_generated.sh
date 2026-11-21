#!/bin/sh
# Regenerates the templ, islands, htmx copy and schema output in a temporary copy and fails when it differs from the committed files.
set -eu

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/warroom"
# fly/site is the ignored deploy copy; its _templ.go files have no .templ sources to regenerate from.
tar --exclude=picks.json --exclude=picks.jsonl --exclude=node_modules --exclude=./fly/site -cf - . | tar -xf - -C "$tmp/warroom"
static=internal/web/static
find "$tmp/warroom" -name '*_templ.go' -delete
rm -f "$tmp/warroom/$static/islands.js" "$tmp/warroom/$static/htmx.min.js" "$tmp/warroom"/rounds/*.schema.json
(cd "$tmp/warroom" && go generate ./... >"$tmp/generate.log" 2>&1) || {
	cat "$tmp/generate.log" >&2
	exit 1
}

status=0
generated=$(find . -name '*_templ.go' -not -path './islands/node_modules/*' -not -path './fly/site/*'; echo "./$static/islands.js" "./$static/htmx.min.js"; ls rounds/*.schema.json)
for f in $generated; do
	if ! cmp -s "$f" "$tmp/warroom/$f"; then
		echo "check_generated: $f is out of date; run 'go generate ./...' in warroom/" >&2
		status=1
	fi
done
# A templ file whose output was never committed.
for f in $(cd "$tmp/warroom" && find . -name '*_templ.go'); do
	[ -f "$f" ] || { echo "check_generated: $f is missing; run 'go generate ./...' in warroom/" >&2; status=1; }
done
exit "$status"
