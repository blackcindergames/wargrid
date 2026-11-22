"""Token usage of Claude Code sessions and Codex rollouts, for the milestone resume record.

"processed" is everything the model read per request (fresh + cached input), summed: the volume
that grows with session length. It is not a price.
    python3 tools/session_usage.py ~/.claude/projects/<project>/<session>.jsonl ~/.codex/sessions/2026/11/03/rollout-*.jsonl
    python3 tools/session_usage.py --lanes [days]   # kickoff lane table: tokens per worktree, lines landed on main
"""

import collections
import json
import re
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any


def _events(path: Path):
    with open(path) as handle:
        for line in handle:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def _requests(path: Path, seen: set | None = None):
    seen = set() if seen is None else seen
    for event in _events(path):
        if event.get("type") != "assistant":
            continue
        message = event.get("message") or {}
        request = event.get("requestId") or message.get("id")
        if request in seen:
            continue
        seen.add(request)
        used = message.get("usage") or {}
        context = sum(
            used.get(key) or 0 for key in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
        )
        yield event, message, used, context


def claude(path: Path) -> dict:
    contexts, output = [], 0
    models: collections.Counter[str] = collections.Counter()
    for _event, message, used, context in _requests(path):
        contexts.append(context)
        output += used.get("output_tokens") or 0
        if message.get("model"):
            models[message["model"]] += 1
    return {
        "processed": sum(contexts),
        "requests": len(contexts),
        "output": output,
        "models": dict(models),
        "first_context": contexts[0] if contexts else 0,
        "max_context": max(contexts, default=0),
    }


def codex(path: Path) -> dict:
    result: dict[str, Any] = {
        "thread": None,
        "parent": None,
        "processed": 0,
        "cached": 0,
        "output": 0,
        "requests": 0,
        "max_context": 0,
        "models": {},
    }
    models: collections.Counter[str] = collections.Counter()
    for event in _events(path):
        payload = event.get("payload") or {}
        if event.get("type") == "session_meta":
            result["thread"] = payload.get("id")
            source = payload.get("source")
            if isinstance(source, dict):
                result["parent"] = ((source.get("subagent") or {}).get("thread_spawn") or {}).get("parent_thread_id")
        elif event.get("type") == "turn_context" and payload.get("model"):
            models[payload["model"]] += 1
        elif payload.get("type") == "token_count" and payload.get("info"):
            total = payload["info"]["total_token_usage"]
            result.update(
                processed=total.get("input_tokens", 0),
                cached=total.get("cached_input_tokens", 0),
                output=total.get("output_tokens", 0),
            )
            result["requests"] += 1
            result["max_context"] = max(
                result["max_context"], (payload["info"].get("last_token_usage") or {}).get("input_tokens", 0)
            )
    result["models"] = dict(models)
    return result


def group_codex(threads: list) -> dict:
    by_id = {thread["thread"]: thread for thread in threads}

    def root(thread):
        hops = 0
        while thread["parent"] in by_id and hops < 20:
            thread, hops = by_id[thread["parent"]], hops + 1
        return thread["thread"]

    groups: dict[Any, dict[str, int]] = {}
    for thread in threads:
        group = groups.setdefault(root(thread), {"processed": 0, "output": 0, "requests": 0, "threads": 0})
        group["processed"] += thread["processed"]
        group["output"] += thread["output"]
        group["requests"] += thread["requests"]
        group["threads"] += 1
    return groups


def _kind(path: Path) -> str:
    for event in _events(path):
        if event.get("type") == "session_meta" or (event.get("payload") or {}).get("type") == "token_count":
            return "codex"
        if event.get("type") == "assistant":
            return "claude"
    return ""


def claude_by_day(path: Path, seen: set | None = None) -> collections.Counter:
    days: collections.Counter[date] = collections.Counter()
    for event, _message, _used, context in _requests(path, seen):
        try:
            stamp = (event.get("timestamp") or "").replace("Z", "+00:00")
            days[datetime.fromisoformat(stamp).astimezone().date()] += context
        except ValueError:
            continue
    return days


def area(path: str) -> str:
    name = path.rsplit("/", 1)[-1]
    if "/tests/" in path or name.startswith("test_") or name.endswith("_test.go"):
        return "tests"
    if path.startswith("game/"):
        return "game"
    if path.startswith("docs/") or name.endswith(".md"):
        return "docs"
    return "tools"


GENERATED = ("_templ.go", "package-lock.json", "perf-history.csv")


def landed(log: str) -> dict[date, collections.Counter[str]]:
    lines: dict[date, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    day = date.min
    for line in log.splitlines():
        if line.startswith("@"):
            day = date.fromisoformat(line[1:])
        elif line and line.split("\t")[0].isdigit():  # binary files show "-"
            added, _deleted, changed = line.split("\t", 2)
            changed = re.sub(r"\{[^}]* => ([^}]*)\}", r"\1", changed).replace("//", "/").split(" => ")[-1]
            if not changed.endswith(GENERATED):
                lines[day][area(changed)] += int(added)
    return lines


def lanes(days: int, out) -> None:
    since = date.today() - timedelta(days=days - 1)
    prefix = re.sub(r"[^A-Za-z0-9]", "-", str(Path.home())) + "-projects-"
    seen: set = set()  # a resumed session repeats requests of the file it resumed
    tokens: dict[date, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    for directory in (Path.home() / ".claude" / "projects").glob(prefix + "wargrid*"):
        lane = directory.name.removeprefix(prefix)
        for path in directory.rglob("*.jsonl"):
            if path.name == "journal.jsonl":  # workflow journals repeat their agents' requests
                continue
            key = lane if lane != "wargrid" else "wargrid/" + path.relative_to(directory).parts[0][:8]
            for day, processed in claude_by_day(path, seen).items():
                if day >= since:
                    tokens[day][key] += processed
    log = subprocess.run(
        ["git", "log", "main", f"--since={since} 00:00", "--numstat", "--format=@%cd", "--date=short"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    lines = landed(log)
    for offset in range(days):
        day = since + timedelta(days=offset)
        print("== %s processed %dM" % (day, sum(tokens[day].values()) // 10**6), file=out)
        for key, processed in tokens[day].most_common(9):
            print("  %6dM  %s" % (processed // 10**6, key), file=out)
        print(
            "  landed on main (+lines): %s"
            % " ".join(f"{a}={lines[day][a]}" for a in ("game", "tests", "docs", "tools")),
            file=out,
        )


def main(argv: list, out=sys.stdout) -> int:
    if not argv:
        print(__doc__, file=out)
        return 2
    if argv[0] == "--lanes":
        lanes(int(argv[1]) if len(argv) > 1 else 3, out)
        return 0
    total, codex_threads = 0, []
    for name in argv:
        path = Path(name)
        kind = _kind(path)
        if kind == "claude":
            result = claude(path)
            total += result["processed"]
            print(
                "claude %s processed=%d requests=%d first_context=%d max_context=%d output=%d models=%s"
                % (
                    path.name,
                    result["processed"],
                    result["requests"],
                    result["first_context"],
                    result["max_context"],
                    result["output"],
                    result["models"],
                ),
                file=out,
            )
        elif kind == "codex":
            codex_threads.append(codex(path))
        else:
            print("unrecognized session file: %s" % name, file=out)
            return 1
    for thread_id, group in group_codex(codex_threads).items():
        total += group["processed"]
        print(
            "codex %s processed=%d requests=%d threads=%d output=%d"
            % (thread_id, group["processed"], group["requests"], group["threads"], group["output"]),
            file=out,
        )
    print("TOTAL processed=%d" % total, file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
