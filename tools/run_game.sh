#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
# Shown in the playtest helper's build id; a failing git writes nothing. Rewritten on each launch, so exec keeps Godot the signalled process.
if commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null); then
	[ -z "$(git -C "$repo_root" status --porcelain)" ] || commit=$commit-dirty
	# Written whole, so a second window launched at the same moment never reads half a build id.
	printf '%s\n' "$commit" > "$repo_root/game/build_commit.txt.tmp" && mv "$repo_root/game/build_commit.txt.tmp" "$repo_root/game/build_commit.txt"
fi
[ "$#" -eq 0 ] && set -- res://scenes/launcher.tscn
exec "${GODOT_BIN:-godot}" --path "$repo_root/game" "$@"
