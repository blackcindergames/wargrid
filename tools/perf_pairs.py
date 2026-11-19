"""Pair verdict: median branch/reference ratio of guarded combat rows."""

import argparse
import json
import math
import re
import statistics
import sys
from pathlib import Path

from perf_record import COMBAT

MARKER = re.compile(r"^COMBAT BENCHMARK PASSED 10$", re.M)
STRESS = re.compile(r"^COMBAT STRESS \S+ ([a-z0-9_]+) ", re.M)
ERROR_LINE = re.compile(r"^.*ERROR: (.*)$", re.M)
# A/A calibration 2026-11-19 (performance ledger, pair gate), approved by the owner; raise only with user approval and a ledger line.
MAX_RATIO: dict[str, float] = {"p95": 1.02, "p99": 1.025}


def _rows(text: str) -> dict[str, dict[str, float]]:
    rows = {name: json.loads(raw) for name, raw in COMBAT.findall(text)}
    for row in rows.values():
        for metric in MAX_RATIO:
            value = row[metric]
            if isinstance(value, bool) or not isinstance(value, int | float) or not math.isfinite(value):
                raise ValueError(metric)
    return rows


def _unusable(text: str) -> str:
    if "SCRIPT ERROR" in text:
        return "SCRIPT ERROR"
    if not COMBAT.search(text):
        return "no tick line"
    errors = ERROR_LINE.findall(text)
    other = [
        m for m in errors if not m.startswith(("Combat benchmark failed for ", "Combat stress ceiling exceeded for "))
    ]
    if other:
        return other[0].strip()
    if MARKER.search(text):
        return ""
    failed = {
        m.removeprefix("Combat benchmark failed for ") for m in errors if m.startswith("Combat benchmark failed for ")
    }
    ceiling = {
        m.removeprefix("Combat stress ceiling exceeded for ")
        for m in errors
        if m.startswith("Combat stress ceiling exceeded for ")
    }
    legacy = bool(failed) and failed == ceiling and all(f"COMBAT STRESS FAIL {row} " in text for row in failed)
    return "" if legacy else "no completion line"


def verdict(refs: list[str], branches: list[str]) -> tuple[int, list[str]]:
    for i, text in enumerate(refs, 1):
        if reason := _unusable(text):
            return 2, [f"PAIR GATE INCONCLUSIVE ref run {i} unusable: {reason}"]
    for i, text in enumerate(branches, 1):
        if not MARKER.search(text):
            return 1, [f"PAIR GATE FAILED branch run {i}"]
    guarded = [set(STRESS.findall(t)) for t in branches]
    if not guarded[0] or any(g != guarded[0] for g in guarded):
        return 2, ["PAIR GATE INCONCLUSIVE guarded rows differ between branch runs"]
    ref_rows: list[dict[str, dict[str, float]]] = []
    branch_rows: list[dict[str, dict[str, float]]] = []
    for side, texts, parsed in (("ref", refs, ref_rows), ("branch", branches, branch_rows)):
        for i, text in enumerate(texts, 1):
            try:
                parsed.append(_rows(text))
            except (ValueError, KeyError, TypeError):
                return 2, [f"PAIR GATE INCONCLUSIVE malformed timing summary in {side} run {i}"]
    lines: list[str] = []
    failed: list[str] = []
    inconclusive: list[str] = []
    compared = 0
    for row in sorted(guarded[0]):
        if not all(row in b for b in branch_rows):
            inconclusive.append(f"branch run {[row in b for b in branch_rows].index(False) + 1} lacks {row}")
            continue
        have = [row in r for r in ref_rows]
        if not any(have):
            lines.append(f"PAIR NEW {row} no reference row, not gated (alarm only)")
            continue
        if not all(have):
            inconclusive.append(f"ref run {have.index(False) + 1} lacks {row}")
            continue
        compared += 1
        for metric, limit in MAX_RATIO.items():
            if any(x[row][metric] <= 0 for x in (*ref_rows, *branch_rows)):
                inconclusive.append(f"{row} {metric} not positive")
                continue
            ratios = [b[row][metric] / a[row][metric] for a, b in zip(ref_rows, branch_rows, strict=True)]
            median = statistics.median(ratios)
            ok = round(median, 4) <= limit
            if not ok:
                failed.append(f"{row}:{metric}")
            ref_text = "/".join(f"{r[row][metric]:.3f}" for r in ref_rows)
            branch_text = "/".join(f"{b[row][metric]:.3f}" for b in branch_rows)
            ratio_text = "/".join(f"{x:.4f}" for x in ratios)
            lines.append(
                f"PAIR {row} {metric} ref {ref_text} branch {branch_text} ratios {ratio_text}"
                f" median {median:.4f} limit {limit:.3f} {'PASS' if ok else 'FAIL'}"
            )
    if failed:
        return 1, [*lines, "PAIR GATE FAILED " + " ".join(failed)]
    if inconclusive:
        return 2, [*lines, "PAIR GATE INCONCLUSIVE " + "; ".join(inconclusive)]
    return 0, [*lines, f"PAIR GATE PASSED {compared}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", nargs="+", required=True, type=Path)
    parser.add_argument("--branch", nargs="+", required=True, type=Path)
    args = parser.parse_args(argv)
    if len(args.ref) != len(args.branch):
        parser.error("--ref and --branch need the same number of logs")
    code, lines = verdict(
        [p.read_text(errors="replace") for p in args.ref], [p.read_text(errors="replace") for p in args.branch]
    )
    print("\n".join(lines))
    return code


if __name__ == "__main__":
    sys.exit(main())
