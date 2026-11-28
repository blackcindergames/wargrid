#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
pids=""
trap 'rm -rf "$log_dir"' EXIT
# Each child leads its own process group, so the trap also reaches its children, even orphaned ones.
group() { exec perl -e 'setpgrp; exec @ARGV or die "$ARGV[0]: $!\n"' "$@"; } # only after &: replaces that job's subshell, so $! is the group
case $(uname -s) in MINGW* | MSYS* | CYGWIN*) group() { exec "$@"; } ;; esac # Windows CI keeps its plain launch; groups there are untested
# shellcheck disable=SC2086 # pids are numbers
stop() { for p in $pids; do kill -TERM -$p || kill -TERM $p; done 2>/dev/null; exit 1; }
trap stop HUP INT TERM
engine=${GODOT_BIN:-godot}
exe=${WARGRID_TEST_EXE:-} # an exported tests build runs the suite itself and needs no import
stamp="$repo_root/game/.godot/wargrid-imported"
stale() { [ ! -f "$stamp" ] || [ -n "$(find "$repo_root/game" -path "$repo_root/game/.godot" -prune -o -newer "$stamp" -print -quit)" ]; }
if [ -z "$exe" ] && stale; then
	mkdir -p "$repo_root/game/.godot" && touch "$stamp" # before the import, so an edit made during it still counts as newer
	"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1
	code=$?
	cat "$log_dir/import.log"
	[ "$code" -eq 0 ] || { rm -f "$stamp"; exit 1; }
	if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/import.log"; then rm -f "$stamp"; exit 1; fi
fi
only=${WARGRID_TEST_ONLY:-}
shards=${WARGRID_TEST_SHARDS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}
[ "$shards" -ge 1 ] 2>/dev/null || { echo "FAIL: WARGRID_TEST_SHARDS must be a number >= 1"; exit 1; }
[ "$shards" -gt 4 ] && shards=4 # measured: 8 shards are no faster than 4, the slowest case bounds the run
[ -n "$only" ] && shards=1 # a filtered run is short; one process boots fastest
i=0
while [ "$i" -lt "$shards" ]; do
	if [ -n "$exe" ]; then
		group "$exe" --headless -- --shard="$i/$shards" ${only:+"--only=$only"} >"$log_dir/tests.$i.log" 2>&1 &
	else
		group "$engine" --headless --path "$repo_root/game" --script res://tests/run_tests.gd -- --shard="$i/$shards" ${only:+"--only=$only"} >"$log_dir/tests.$i.log" 2>&1 &
	fi
	pids="$pids $!"
	i=$((i + 1))
done
status=0
i=0
for pid in $pids; do
	code=0
	wait "$pid" || { code=$?; status=1; }
	grep -q '^CASES ' "$log_dir/tests.$i.log" || echo "shard $i/$shards exit=$code" # a Windows watchdog kill exits 0
	grep -Ev '^(CASES|TESTS PASSED|SIM PUMPS) ' "$log_dir/tests.$i.log"
	i=$((i + 1))
done
if cat "$log_dir"/tests.*.log | grep -E 'ERROR:|SCRIPT ERROR:' >/dev/null; then status=1; fi
cat "$log_dir"/tests.*.log | awk -v shards="$shards" -v status="$status" '
	/^CASES / { cases += $2; checks += $4; failures += $6; done++ }
	/^SIM PUMPS worker=/ { for (f = 3; f <= 6; f++) { split($f, kv, "="); pumps[kv[1]] += kv[2] }; counted = 1 }
	/^SIM PUMPS LIVE / { live += $4; lives = 1 }
	END {
		print "CASES " cases " CHECKS " checks " FAILURES " failures
		if (counted) print "SIM PUMPS worker=" pumps["worker"] " forced=" pumps["forced"] " fallback=" pumps["fallback"] " inline=" pumps["inline"]
		if (lives) print "SIM PUMPS LIVE " live
		bad = ENVIRON["WARGRID_SIM_THREAD"] == "1" && ENVIRON["WARGRID_TEST_ONLY"] == "" && (pumps["worker"] == 0 || pumps["inline"] > 0 || live > 0)
		if (bad) print "FAIL: SIM PUMPS under the worker switch need worker > 0, inline == 0 and LIVE 0"
		if (done != shards) print "FAIL: " shards - done " of " shards " shards did not finish"
		else if (!bad && status == 0 && failures == 0 && checks > 0) print "TESTS PASSED " checks
	}' >"$log_dir/summary.log"
cat "$log_dir/summary.log"
grep -Eq '^TESTS PASSED [1-9][0-9]*$' "$log_dir/summary.log" || exit 1
