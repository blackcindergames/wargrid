#!/bin/sh
# Usage: run_pump_faults.sh [case [bound_seconds]]. One godot process per fault case, each bounded without `timeout`.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
bound=${2:-300}
cases=${1:-"logged_error main_error_control wrong_thread fault_in_query stall_restart stall_leave stall_stop stall_query dead_thread next_match_inline stall_offline stall_online"}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1 || { cat "$log_dir/import.log"; exit 1; }
passed=0
failed=0
for name in $cases; do
	log="$log_dir/$name.log"
	WARGRID_SIM_THREAD=1 "$engine" --headless --path "$repo_root/game" --script res://tests/pump_faults.gd -- "--case=$name" >"$log" 2>&1 &
	pid=$!
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$bound" ]; do
		sleep 1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -KILL "$pid"
		echo "FAILED $name: still running after $bound s"
		failed=$((failed + 1))
		wait "$pid" 2>/dev/null
		continue
	fi
	wait "$pid"
	code=$?
	marker=$(grep -E "^FAULT CASE $name (PASSED|FAILED)" "$log")
	echo "$marker exit=$code"
	if [ "$code" -eq 0 ] && echo "$marker" | grep -q "^FAULT CASE $name PASSED"; then
		passed=$((passed + 1))
	else
		echo "FAILED $name: marker or exit status wrong"
		tail -n 5 "$log"
		failed=$((failed + 1))
	fi
done
[ "$failed" -eq 0 ] && [ "$passed" -gt 0 ] || exit 1
echo "PUMP FAULTS PASSED $passed"
