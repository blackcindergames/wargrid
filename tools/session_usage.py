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


def _first_message(path: Path) -> str:
    for event in _events(path):
        content = (event.get("message") or {}).get("content")
        if event.get("type") != "user" or event.get("isMeta") or not content:
            continue
        if isinstance(content, list):
            content = " ".join(block.get("text", "") for block in content if block.get("type") == "text")
        content = content.strip()
        if content and not content.startswith(("<system-reminder>", "<local-command", "<command-name>/clear")):
            return content
    return ""


def session_label(path: Path) -> str:
    text = _first_message(path)
    handoff = re.search(r"([\w.-]+)-prompt\.txt", text)
    command = re.search(r"<command-name>(/\S+)</command-name>", text) or re.match(r"(/\S+)", text)
    if handoff:
        return handoff.group(1)
    return command.group(1) if command else " ".join(text.split())[:40]


def package_ids(text: str) -> dict[str, str]:
    ids = re.findall(r"^\| (P\d[\w.]*) \|", text, re.M)
    return {_squash(i): i for i in sorted(ids, key=len, reverse=True)}


def _squash(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


# shortcut: a lane counts as a player package when its label starts with a package id, upgrade to a lane tag in the handoff when names stop matching.
def _package_of(name: str, ids: dict[str, str]) -> str | None:
    squashed = _squash(name.removeprefix("wargrid-wt-"))
    return next((i for i in ids if squashed.startswith(i) and not squashed[len(i) :][:1].isdigit()), None)


def player_packages(rows: list[tuple[str, int]], ids: dict[str, str]) -> str:
    shares: collections.Counter[str] = collections.Counter()
    for name, processed in rows:
        found = _package_of(name, ids)
        if found:
            shares[ids[found]] += processed
    total = sum(processed for _name, processed in rows)
    line = "  player packages: %d %%" % round(100 * sum(shares.values()) / total if total else 0)
    if shares:
        line += " (%s)" % ", ".join("%s %dM" % (i, n // 10**6) for i, n in shares.most_common())
    return line


def _package_table() -> dict[str, str]:
    try:
        return package_ids((Path(__file__).resolve().parent.parent / "docs" / "packages.md").read_text())
    except OSError:
        return {}


def lanes(days: int, out) -> None:
    since = date.today() - timedelta(days=days - 1)
    prefix = re.sub(r"[^A-Za-z0-9]", "-", str(Path.home())) + "-projects-"
    seen: set = set()  # a resumed session repeats requests of the file it resumed
    tokens: dict[date, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    labels: dict[str, str] = {}
    for directory in (Path.home() / ".claude" / "projects").glob(prefix + "wargrid*"):
        lane = directory.name.removeprefix(prefix)
        for path in directory.rglob("*.jsonl"):
            if path.name == "journal.jsonl":  # workflow journals repeat their agents' requests
                continue
            key = lane if lane != "wargrid" else "wargrid/" + path.relative_to(directory).parts[0][:8]
            if lane == "wargrid" and path.parent == directory:
                labels[key] = session_label(path)
            for day, processed in claude_by_day(path, seen).items():
                if day >= since:
                    tokens[day][key] += processed
    log = subprocess.run(
        ["git", "log", "main", f"--since={since} 00:00", "--numstat", "--format=@%cd", "--date=short"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    lines, ids = landed(log), _package_table()
    for offset in range(days):
        day = since + timedelta(days=offset)
        print("== %s processed %dM" % (day, sum(tokens[day].values()) // 10**6), file=out)
        for key, processed in tokens[day].most_common(9):
            print("  %6dM  %s" % (processed // 10**6, key) + (f"  {labels[key]}" if labels.get(key) else ""), file=out)
        if ids:
            rows = [(labels.get(key) or key, n) for key, n in tokens[day].items()]
            print(player_packages(rows, ids), file=out)
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
