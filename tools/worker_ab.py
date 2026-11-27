"""Worker-thread A/B extractor, from the spike's. usage: worker_ab.py decide|report [guards] PATH...

Reads the match bench's logs (WORKER RUN, DIGEST lines). Folders give their web-*.log and *bench*.log, not
recursive. The refusal, worst-pace and tick-rate guards are unset by default: their values are the owner's before SB6.
"""

import argparse
import contextlib
import glob
import json
import math
import re
import statistics
import sys
from collections import defaultdict
from collections.abc import Iterable
from pathlib import Path
from typing import Any

Row = dict[str, Any]

GOAL = ("skirmish3v3", "team")
PARK_LOADS = ("hordes300", "late_game_3v3")
MIN_WINDOW = 1800
DIGEST_EVERY = 300
TICK_RATE_REFERENCE = 29.7
MAX_DURATION_MS = 600_000.0
NO_VERDICT = "NO VERDICT"
DURATIONS = ("cpu_ms", "frame_ms", "start_ms", "refresh_ms", "job_ms", "age_ms", "handoff_ms")
REQUIRED = ("cpu_ms.p95", "cpu_ms.p99", "missed_share", "main_per_tick", "tick_rate", "frames", "window_ticks", "build")
REQUIRED_WORKER = (
    "depth_max", "room_refusals", "posts_attempted", "pace_worst_2s_tps", "job_ms.p95", "age_ms.p95", "handoff_ms.p95"
)  # fmt: skip
IDENTITY = ("load", "arm", "export", "run", "start_tick", "end_tick", "isolated")
TIMED = ("job_ms", "age_ms", "handoff_ms")


def files_of(paths: Iterable[str]) -> list[str]:
    out: list[str] = []
    for p in map(Path, paths):
        if p.is_dir():
            found = [glob.glob(str(p / pattern)) for pattern in ("web-*.log", "*bench*.log")]
            out += sorted({name for names in found for name in names})
        else:
            out.append(str(p))
    return out


def parse(path: str) -> tuple[list[Row], list[str]]:
    """Returns (runs, problems). A run is the WORKER RUN dict plus its digests and file."""
    runs: list[Row] = []
    problems: list[str] = []
    digests: dict[int, str] = {}
    ended = False
    for line in Path(path).read_text(errors="replace").splitlines():
        if line.startswith("RUN "):
            digests = {}
        elif line.startswith("DIGEST "):
            m = re.match(r"DIGEST tick=(\d+) (\S+)", line)
            if m:
                digests[int(m.group(1))] = m.group(2)
        elif line.startswith("WORKER RUN "):
            row = json.loads(line[len("WORKER RUN ") :])
            row["digests"], row["file"] = digests, path
            absent = [key for key in IDENTITY if key not in row]
            if absent:
                problems.append(f"{path}: WORKER RUN lacks {absent}")
            else:
                runs.append(row)
        elif re.match(r"WORKER BENCH (FAILED|TIMEOUT)", line):
            problems.append(f"{path}: {line.strip()}")
        elif line.startswith("WORKER BENCH DONE"):
            ended = True
    if not ended and not problems:
        problems.append(f"{path}: no WORKER BENCH DONE line")
    return runs, problems


def get(row: Row, key: str) -> Any:
    cur: Any = row
    for part in key.split("."):
        cur = cur[part]
    return cur


class Group:
    def __init__(self, runs: list[Row]) -> None:
        self.runs = runs

    def vals(self, key: str) -> list[Any]:
        out: list[Any] = []
        for r in self.runs:
            with contextlib.suppress(KeyError, TypeError):
                out.append(get(r, key))
        return out

    def med(self, key: str) -> float:
        return statistics.median(self.vals(key))

    def rng(self, key: str) -> float:
        vals = self.vals(key)
        return max(vals) - min(vals)

    def fmt(self, key: str, nd: int = 2) -> str:
        if not self.vals(key):
            return "-"
        return f"{self.med(key):.{nd}f} [{self.rng(key):.{nd}f}]"


Groups = dict[tuple[str, str, str], Group]


def group_runs(runs: list[Row]) -> Groups:
    g: dict[tuple[str, str, str], list[Row]] = defaultdict(list)
    for r in runs:
        g[(r["load"], r["export"], r["arm"])].append(r)
    return {k: Group(v) for k, v in g.items()}


def digest_notes(runs: list[Row]) -> tuple[list[str], list[str]]:
    """Per load: DIGESTS EQUAL, or the first problem. Returns (lines, bad_reasons)."""
    lines: list[str] = []
    bad: list[str] = []
    for load in sorted({r["load"] for r in runs}):
        rs = [r for r in runs if r["load"] == load]
        problem = None
        for r in rs:
            want = list(range(r["start_tick"] // DIGEST_EVERY * DIGEST_EVERY, r["end_tick"] + 1, DIGEST_EVERY))
            if sorted(r["digests"]) != want:
                span = f"{want[0]}..{want[-1]}" if want else "none"
                problem = f"{load}: DIGEST ticks of {r['file']} run {r['run']} are not {span} every {DIGEST_EVERY}"
                break
        if not problem:
            ref = rs[0]["digests"]
            for r in rs[1:]:
                differs = [t for t in sorted(set(ref) | set(r["digests"])) if ref.get(t) != r["digests"].get(t)]
                if differs:
                    problem = f"{load}: DIGEST differs at tick {differs[0]} ({r['file']} run {r['run']} arm {r['arm']})"
                    break
        if problem:
            bad.append(problem)
            lines.append("DIGESTS DIFFER " + problem)
        else:
            lines.append(
                f"DIGESTS EQUAL {load} ({len(rs)} runs)"
                if len(rs) > 1
                else f"DIGESTS ALONE {load} (1 run, nothing to compare)"
            )
    return lines, bad


def _absurd(value: Any) -> bool:
    return not isinstance(value, int | float) or not math.isfinite(value) or value < 0 or value > MAX_DURATION_MS


def _durations(r: Row) -> Iterable[tuple[str, Any]]:
    for name in DURATIONS:
        if isinstance(r.get(name), dict):
            yield from ((f"{name}.{k}", v) for k, v in r[name].items() if k != "n")
    for tag, summary in (r.get("job_ms_by_tag") or {}).items():
        yield from ((f"job_ms_by_tag.{tag}.{k}", v) for k, v in summary.items() if k != "n")
    if "main_per_tick" in r:
        yield "main_per_tick", r["main_per_tick"]


def validity(runs: list[Row], problems: list[str]) -> list[str]:
    bad = list(problems)
    for r in runs:
        tag = f"{r['load']}/{r['export']}/{r['arm']} run {r['run']}"
        for key in REQUIRED + (REQUIRED_WORKER if r["arm"] == "worker" else ()):
            try:
                get(r, key)
            except (KeyError, TypeError):
                bad.append(f"{tag}: field {key} missing")
        if r["arm"] == "worker":
            for key in TIMED:
                if r.get(key, {}).get("n", 0) == 0:
                    bad.append(f"{tag}: no {key} samples")
        if r.get("failed"):
            bad.append(f"{tag}: failed={r['failed']!r}")
        if r.get("window_ticks", 0) < MIN_WINDOW:
            bad.append(f"{tag}: window {r.get('window_ticks')} ticks < {MIN_WINDOW}")
        if r.get("frames", 0) == 0 or r.get("cpu_ms", {}).get("n", 0) == 0:
            bad.append(f"{tag}: zero frame samples")
        for key, value in _durations(r):
            if _absurd(value):
                bad.append(f"{tag}: absurd duration {key}={value!r}")
                break
    for load in {r["load"] for r in runs}:
        builds = {r.get("build") for r in runs if r["load"] == load}
        if len(builds) > 1:
            bad.append(f"{load}: more than one build value {sorted(map(str, builds))}")
    return bad + digest_notes(runs)[1]


def run_requirements(groups: Groups) -> list[str]:
    bad: list[str] = []
    loads = {k[0] for k in groups}
    for load in GOAL:
        if load not in loads:
            bad.append(f"{load}: goal load missing")
    for load in loads:
        arms = {("threads", "inline"), ("threads", "worker")} | ({("nothreads", "inline")} if load in GOAL else set())
        n = 3 if load in GOAL else 2
        for exp, arm in sorted(arms):
            have = len(groups.get((load, exp, arm), Group([])).runs)
            if have < n:
                bad.append(f"{load}/{exp}/{arm}: {have} runs, needs {n}")
    return bad


def not_isolated(runs: list[Row]) -> list[str]:
    return [f"{r['load']}/{r['export']}/{r['arm']} run {r['run']} not isolated" for r in runs if not r["isolated"]]


def compare(
    groups: Groups, load: str, base_key: tuple[str, str, str], args: argparse.Namespace
) -> tuple[float, float, dict[str, tuple[bool, str]]]:
    """Gain, spread and guards of the threaded worker against one baseline."""
    w, b = groups[(load, "threads", "worker")], groups[base_key]
    spread = max(b.rng("cpu_ms.p95"), w.rng("cpu_ms.p95"))
    gain = b.med("cpu_ms.p95") - w.med("cpu_ms.p95")
    guards: dict[str, tuple[bool, str]] = {}
    for k in ("cpu_ms.p99", "missed_share"):
        lim = b.med(k) + max(b.rng(k), w.rng(k))
        guards[k] = (w.med(k) <= lim, f"worker {w.med(k):.3f} vs limit {lim:.3f}")
    shares = [r["room_refusals"] / max(1, r["posts_attempted"]) for r in w.runs]
    worst = statistics.median(shares)
    if args.max_refusal_share is None:
        guards["refusal_share"] = (True, f"unset, worker {worst:.4f}")
    else:
        guards["refusal_share"] = (worst <= args.max_refusal_share, f"worker {worst:.4f} vs {args.max_refusal_share}")
    pace = w.med("pace_worst_2s_tps")
    if args.min_worst_pace is None:
        guards["pace_worst_2s_tps"] = (True, f"unset, worker {pace:.2f}")
    else:
        guards["pace_worst_2s_tps"] = (pace >= args.min_worst_pace, f"worker {pace:.2f} vs {args.min_worst_pace}")
    rate = w.med("tick_rate")
    if args.tick_rate_tolerance is None:
        guards["tick_rate"] = (True, f"unset, worker {rate:.2f}, reference floor {TICK_RATE_REFERENCE}")
    else:
        floor = b.med("tick_rate") - args.tick_rate_tolerance
        guards["tick_rate"] = (rate >= floor, f"worker {rate:.2f} vs floor {floor:.2f}")
    return gain, spread, guards


def verdict_lines(groups: Groups, args: argparse.Namespace) -> tuple[str, list[str]]:
    out: list[str] = []
    go = True
    for load in GOAL:
        for exp in ("threads", "nothreads"):
            base_key = (load, exp, "inline")
            gain, spread, guards = compare(groups, load, base_key, args)
            ok = gain > 2 * spread and all(g[0] for g in guards.values())
            go &= ok
            out.append(
                f"{load} vs {exp} inline: gain {gain:.3f} ms, spread {spread:.3f} ms, "
                f"need gain > {2 * spread:.3f}: {'ok' if gain > 2 * spread else 'NO'}"
            )
            for k, (good, txt) in guards.items():
                out.append(f"  guard {k}: {'ok' if good else 'FAIL'} ({txt})")
            w, ni = groups[(load, "threads", "worker")], groups[base_key]
            out.append(
                f"  main_per_tick worker {w.med('main_per_tick'):.2f}, {exp} inline {ni.med('main_per_tick'):.2f}"
            )
        tax = groups[(load, "nothreads", "inline")].med("cpu_ms.p95") / groups[(load, "threads", "inline")].med(
            "cpu_ms.p95"
        )
        out.append(f"  tax (nothreads inline / threaded inline, cpu_ms.p95): {tax:.3f}")
    if go:
        return "GO", out
    park = False
    for load in PARK_LOADS:
        if (load, "threads", "worker") in groups:
            gain, spread, _ = compare(groups, load, (load, "threads", "inline"), args)
            out.append(f"{load} vs threaded inline: gain {gain:.3f} ms, spread {spread:.3f} ms")
            park |= gain > 2 * spread
    return ("PARK" if park else "DROP"), out


def table(groups: Groups) -> None:
    print(
        "load | export | arm | n | cpu p95 | cpu p99 | cpu max | missed_share | main_per_tick | tick_rate | "
        "worst 2s tps | depth_max | room_refusals | frame p50/p95/p99/max (report-only) | isolated"
    )
    for (load, exp, arm), g in sorted(groups.items()):
        fr = "/".join(
            f"{g.med('frame_ms.' + k):.2f}" if g.vals("frame_ms." + k) else "-" for k in ("p50", "p95", "p99", "max")
        )
        print(
            f"{load} | {exp} | {arm} | {len(g.runs)} | {g.fmt('cpu_ms.p95')} | {g.fmt('cpu_ms.p99')} | {g.fmt('cpu_ms.max')} | "
            f"{g.fmt('missed_share', 4)} | {g.fmt('main_per_tick')} | {g.fmt('tick_rate')} | {g.fmt('pace_worst_2s_tps')} | "
            f"{max(g.vals('depth_max'), default='-')} | {max(g.vals('room_refusals'), default='-')} | {fr} | "
            f"{all(g.vals('isolated'))}"
        )
    print(
        "worker: load | export | job p50/p95/max | handoff p50/p95 | age p50/p95/max | refusal streak max | main waits (n, max ms)"
    )
    for (load, exp, arm), g in sorted(groups.items()):
        if arm != "worker":
            continue
        waits = f"{g.fmt('main_wait_count', 0)}, {g.fmt('main_wait_max_ms', 0)}"
        print(
            f"{load} | {exp} | {g.fmt('job_ms.p50')} / {g.fmt('job_ms.p95')} / {g.fmt('job_ms.max')} | "
            f"{g.fmt('handoff_ms.p50')} / {g.fmt('handoff_ms.p95')} | "
            f"{g.fmt('age_ms.p50')} / {g.fmt('age_ms.p95')} / {g.fmt('age_ms.max')} | {g.fmt('refusal_streak_max', 0)} | {waits}"
        )


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="worker_ab.py", description=__doc__.splitlines()[0] if __doc__ else "")
    p.add_argument("mode", choices=("decide", "report"))
    p.add_argument("paths", nargs="+")
    p.add_argument("--max-refusal-share", type=float, help="worker room_refusals / posts_attempted, median per arm")
    p.add_argument("--min-worst-pace", type=float, help="worker pace_worst_2s_tps, median per arm")
    p.add_argument(
        "--tick-rate-tolerance", type=float, help="worker tick_rate may trail the threaded inline median by this"
    )
    return p


def main(argv: list[str]) -> int:
    args = _parser().parse_args(argv)
    runs: list[Row] = []
    problems: list[str] = []
    for f in files_of(args.paths):
        r, p = parse(f)
        runs += r
        problems += p
    groups = group_runs(runs)
    if args.mode == "report":
        print("REPORT ONLY")
        for note in validity(runs, problems) + not_isolated(runs):
            print("NOTE", note)
        for line in digest_notes(runs)[0]:
            print(line)
        if runs:
            table(groups)
        print("AB DONE")
        return 0
    reasons = validity(runs, problems) + run_requirements(groups)
    if not reasons:
        reasons = [f"{x} (not isolated)" for x in not_isolated(runs)]
    for line in digest_notes(runs)[0]:
        print(line)
    if reasons:
        print(f"{NO_VERDICT}: " + "; ".join(reasons))
        print("AB DONE")
        return 0
    table(groups)
    verdict, lines = verdict_lines(groups, args)
    print("\n".join(lines))
    print("no-threads inline runs are not interleaved with the threaded page")
    print(f"VERDICT {verdict}")
    print("AB DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
