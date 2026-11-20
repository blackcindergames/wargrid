#!/bin/sh
# Proves check_generated.sh ignores the fly/site deploy copy yet still flags a stale tracked file. Run from quality.sh.
set -eu

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Tracked files only, so an uncommitted generated file in the working tree cannot decide the result.
git ls-files | tar -cf - -T - | tar -xf - -C "$tmp"

# The nested module is what fly/sync.sh builds; it has no .templ sources to regenerate from.
mkdir -p "$tmp/fly/site/src/internal/web"
touch "$tmp/fly/site/src/go.mod"
stale=$(cd "$tmp" && find internal/web -name '*_templ.go' | sort | head -n 1)
[ -n "$stale" ] || { echo "test_check_generated: no tracked _templ.go to use" >&2; exit 1; }
cp "$tmp/$stale" "$tmp/fly/site/src/internal/web/"

(cd "$tmp" && sh tools/check_generated.sh) >"$tmp/deploy-only.log" 2>&1 || {
	echo "test_check_generated: the fly/site copy alone must pass" >&2
	cat "$tmp/deploy-only.log" >&2
	exit 1
}

echo >>"$tmp/$stale"
if (cd "$tmp" && sh tools/check_generated.sh) >"$tmp/stale.log" 2>&1; then
	echo "test_check_generated: a stale tracked $stale must fail" >&2
	exit 1
fi
grep -q "$stale is out of date" "$tmp/stale.log" || { echo "test_check_generated: $stale not named" >&2; cat "$tmp/stale.log" >&2; exit 1; }
if grep -q 'fly/site' "$tmp/stale.log"; then
	echo "test_check_generated: fly/site took part" >&2
	cat "$tmp/stale.log" >&2
	exit 1
fi
