#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1 || { cat "$log_dir/import.log"; exit 1; }
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_team_match.gd >"$log_dir/match.log" 2>&1
code=$?
cat "$log_dir/match.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/match.log"; then exit 1; fi
# Pinned outcome: equal team mirror, ongoing at the 45000 cap since BR8's group speed (exempt from the end bar, user 2026-11-22).
grep -Eq '^TEAM MATCH cap tick=45000 winner=null units_peak=329$' "$log_dir/match.log" || exit 1
grep -Eq '^TEAM PATHS PASS ' "$log_dir/match.log" || exit 1
