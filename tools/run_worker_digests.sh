#!/bin/sh
# Usage: run_worker_digests.sh [--inject-divergence]. Each load runs once inline and once worker (one godot process each, bounded without `timeout`); the digests every 30 ticks must be equal.
# --inject-divergence moves one worker command on the first load; it exits 0 only when both the command-log check and the digest check reported a mismatch, and 1 otherwise.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
# shortcut: an interrupt removes the logs but leaves the running godot until its own 270 s limit (as run_pump_faults.sh); add a kill to the trap when either script is next touched.
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
bound=${WORKER_DIGESTS_BOUND:-300}
layouts="skirmish3v3 hordes300 late_game_3v3 team"
inject=""
command_mismatch=0
digest_mismatch=0
if [ "$1" = "--inject-divergence" ]; then
	inject=1
	layouts="skirmish3v3"
fi

# run_bounded <log> <script args>: fails when the process fails or outlives the bound.
run_bounded() {
	log=$1
	shift
	"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_worker_digests.gd -- "$@" >"$log" 2>&1 &
	pid=$!
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$bound" ]; do
		sleep 1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -KILL "$pid"
		wait "$pid" 2>/dev/null
		echo "FAILED $*: still running after $bound s"
		return 1
	fi
	wait "$pid" || {
		echo "FAILED $*: godot exited with an error"
		tail -n 5 "$log"
		return 1
	}
}

run_worker() {
	if [ -n "$inject" ]; then run_bounded "$@" --inject-divergence; else run_bounded "$@"; fi
}

# The first differing DIGEST line is reported per tick, in both modes, over its 30-tick window.
report_window() {
	layout=$1
	first=$(awk 'NR==FNR { a[NR] = $0; next } a[FNR] != $0 { print $3; exit }' "$log_dir/$layout-inline.dig" "$log_dir/$layout-worker.dig")
	tick=${first#tick=}
	echo "DIGEST MISMATCH $layout: first differing line at tick $tick, rerunning ticks $((tick - 30)) to $tick per tick"
	run_worker "$log_dir/$layout-window.log" --layout="$layout" --window="$((tick - 30)),$tick" || return 0
	cat "$log_dir/$layout-window.log"
}

# Command logs first: a difference there is reported apart from a state difference.
check_inputs() {
	layout=$1
	grep '^COMMANDS ' "$log_dir/$layout-inline.log" >"$log_dir/$layout-inline.cmd"
	grep '^COMMANDS ' "$log_dir/$layout-worker.log" >"$log_dir/$layout-worker.cmd"
	[ -s "$log_dir/$layout-inline.cmd" ] && cmp -s "$log_dir/$layout-inline.cmd" "$log_dir/$layout-worker.cmd" && return 0
	command_mismatch=1
	echo "COMMAND LOG MISMATCH $layout: the command logs differ (a different input, or bot orders the worker made differently)"
	cat "$log_dir/$layout-inline.cmd" "$log_dir/$layout-worker.cmd"
	return 1
}

check_digests() {
	layout=$1
	grep '^DIGEST ' "$log_dir/$layout-inline.log" >"$log_dir/$layout-inline.dig"
	grep '^DIGEST ' "$log_dir/$layout-worker.log" >"$log_dir/$layout-worker.dig"
	inline_count=$(wc -l <"$log_dir/$layout-inline.dig" | tr -d ' ')
	worker_count=$(wc -l <"$log_dir/$layout-worker.dig" | tr -d ' ')
	if [ "$inline_count" -eq 0 ] || [ "$inline_count" -ne "$worker_count" ]; then
		echo "FAILED $layout: $inline_count inline and $worker_count worker digest lines"
		return 1
	fi
	for column in 4 5; do
		if [ "$(awk -v c="$column" '{ print $c }' "$log_dir/$layout-inline.dig" | sort -u | wc -l | tr -d ' ')" -lt 2 ]; then
			echo "FAILED $layout: column $column of the digest lines (4 digest, 5 view) never changes, so it proves nothing"
			return 1
		fi
	done
	cmp -s "$log_dir/$layout-inline.dig" "$log_dir/$layout-worker.dig" && return 0
	digest_mismatch=1
	report_window "$layout"
	return 1
}

check_layout() {
	layout=$1
	run_bounded "$log_dir/$layout-inline.log" --layout="$layout" --mode=inline || return 1
	run_worker "$log_dir/$layout-worker.log" --layout="$layout" --mode=worker || return 1
	grep -h '^RUN ' "$log_dir/$layout-inline.log" "$log_dir/$layout-worker.log"
	ok=0
	check_inputs "$layout" || ok=1
	check_digests "$layout" || ok=1
	[ "$ok" -eq 0 ] && echo "MATCHED $layout: $inline_count digests"
	return "$ok"
}

"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1 || { cat "$log_dir/import.log"; exit 1; }
matched=0
failed=0
for layout in $layouts; do
	if check_layout "$layout"; then matched=$((matched + 1)); else failed=$((failed + 1)); fi
done
if [ -n "$inject" ]; then
	[ "$command_mismatch" -eq 1 ] && [ "$digest_mismatch" -eq 1 ] || { echo "INJECTED DIVERGENCE NOT DETECTED: command log mismatch $command_mismatch, digest mismatch $digest_mismatch"; exit 1; }
	echo "INJECTED DIVERGENCE DETECTED"
	exit 0
fi
[ "$failed" -eq 0 ] && [ "$matched" -eq 4 ] || exit 1
echo "WORKER DIGESTS MATCHED $matched"
