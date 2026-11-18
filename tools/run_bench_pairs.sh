#!/bin/sh
# usage: [PERF_REF=<rev>] run_bench_pairs.sh — reference and working tree run_combat.gd in 3 alternating pairs; perf_pairs.py judges.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
engine=${GODOT_BIN:-godot}
cd "$repo_root" || exit 1
ref=${PERF_REF:-$(git merge-base HEAD main)} || { echo "PAIR GATE INCONCLUSIVE no merge base with main (set PERF_REF)"; exit 1; }
name=$(git rev-parse --short "$ref") || { echo "PAIR GATE INCONCLUSIVE bad reference $ref"; exit 1; }
if [ -z "${PERF_REF:-}" ] && git diff --quiet "$ref" -- game && [ -z "$(git status --porcelain -- game)" ]; then
	echo "PAIR GATE SKIPPED game/ unchanged since $name"; exit 0
fi
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
echo "PAIR WORK $work (pid $$)"
git archive "$ref" game | tar -x -C "$work" || { echo "PAIR GATE INCONCLUSIVE archive of $name failed"; exit 1; }
if ! "$engine" --headless --path "$work/game" --import >"$work/import.log" 2>&1 || grep -E 'ERROR:|SCRIPT ERROR' "$work/import.log"; then
	cat "$work/import.log"; echo "PAIR GATE INCONCLUSIVE import of $name failed"; exit 1
fi
echo "PAIR REF $name ${PERF_REF:+(PERF_REF=$PERF_REF)}"
for i in 1 2 3; do
	echo "PAIR ref-$i $(uptime)"
	"$engine" --headless --path "$work/game" --script res://benchmarks/run_combat.gd >"$work/ref-$i.log" 2>&1
	echo "PAIR branch-$i $(uptime)"
	if ! "$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_combat.gd >"$work/branch-$i.log" 2>&1 \
		|| grep -E 'ERROR:|SCRIPT ERROR:' "$work/branch-$i.log" \
		|| ! grep -q '^COMBAT BENCHMARK PASSED 10$' "$work/branch-$i.log"; then
		cat "$work/branch-$i.log"; echo "PAIR GATE FAILED branch run $i"; exit 1
	fi
done
python3 tools/perf_pairs.py --ref "$work"/ref-1.log "$work"/ref-2.log "$work"/ref-3.log --branch "$work"/branch-1.log "$work"/branch-2.log "$work"/branch-3.log
