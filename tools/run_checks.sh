#!/bin/sh
cd -- "$(dirname -- "$0")/.." || exit 1
sh tools/ensure_venv.sh || exit 1 # three gates call it, and two parallel venv builds can break each other
log_dir=$(mktemp -d) || exit 1
pids=""
trap 'rm -rf "$log_dir"' EXIT
# Each child leads its own process group, so the trap also reaches its children, even orphaned ones.
group() { exec perl -e 'setpgrp; exec @ARGV or die "$ARGV[0]: $!\n"' "$@"; } # only after &: replaces that job's subshell, so $! is the group
case $(uname -s) in MINGW* | MSYS* | CYGWIN*) group() { exec "$@"; } ;; esac # Windows CI keeps its plain launch; groups there are untested
# shellcheck disable=SC2086 # pids are numbers
stop() { for p in $pids; do kill -TERM -$p || kill -TERM $p; done 2>/dev/null; exit 1; }
trap stop HUP INT TERM
gates="run_lint run_warnings run_python_checks run_shell_checks check_public"
for gate in $gates; do
	group sh "tools/$gate.sh" >"$log_dir/$gate.log" 2>&1 &
	pids="$pids $!"
done
failed=""
# shellcheck disable=SC2086 # pids are numbers
set -- $pids
for gate in $gates; do
	if wait "$1"; then echo "PASS $gate"; else echo "FAIL $gate"; failed="$failed $gate"; fi
	shift
done
for gate in $failed; do
	echo "--- $gate ---"
	cat "$log_dir/$gate.log"
done
[ -z "$failed" ] || exit 1
echo "CHECKS PASSED 5"
