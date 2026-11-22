#!/bin/sh
# usage: [BOT_LAB_GAME=<Godot project dir>] [BOT_LAB_JOBS=<jobs file>] [BOT_LAB_PAR=5] run_bot_lab.sh LABEL
# Runs the bot lab matrix headless, one match per job, and prints the summary. Rows land in build/bot_lab/LABEL/.
# A variant is a patched export: `git archive <rev> game | tar -x -C build/variant` and edit it there, then BOT_LAB_GAME=build/variant/game.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
label=${1:?usage: run_bot_lab.sh LABEL}
case $label in */*|.*) echo "LABEL must be a plain name"; exit 2;; esac
game=${BOT_LAB_GAME:-$repo_root/game}
jobs=${BOT_LAB_JOBS:-$repo_root/tools/bot_lab_jobs.txt}
out=$repo_root/build/bot_lab/$label
engine=${GODOT_BIN:-godot}
[ -f "$game/project.godot" ] || { echo "no Godot project in $game"; exit 1; }
[ -f "$jobs" ] || { echo "no jobs file $jobs"; exit 1; }
rm -rf "$out"
mkdir -p "$out" || exit 1
echo "BOT LAB $label game=$game jobs=$(grep -vc '^#\|^$' "$jobs")"
[ -d "$game/.godot" ] || "$engine" --headless --path "$game" --import >"$out/import.log" 2>&1 || { cat "$out/import.log"; exit 1; }
export out game engine probe="$repo_root/game/benchmarks/bot_lab.gd"
# The probe always comes from this tree, so a variant export of an older revision runs the same measurements.
# shellcheck disable=SC2016 # the sh -c body expands its own variables
grep -v '^#\|^$' "$jobs" | xargs -P "${BOT_LAB_PAR:-5}" -L1 sh -c '
	name=$1; shift
	start=$(date +%s)
	nice -n 19 "$engine" --headless --path "$game" --script "$probe" -- "$@" >"$out/$name.log" 2>&1
	code=$?
	grep "^BOTLAB " "$out/$name.log" >"$out/$name.jsonl"
	grep -q "ERROR:" "$out/$name.log" && [ "$code" -eq 0 ] && code=2
	echo "exit=$code seconds=$(( $(date +%s) - start )) $name" >"$out/$name.exit"
' _
touch "$out/done"
python3 "$repo_root/tools/bot_lab_summary.py" "$out"
