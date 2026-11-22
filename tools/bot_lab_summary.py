#!/usr/bin/env python3
"""Summarise bot lab rows: bot_lab_summary.py <build/bot_lab/LABEL>. Exits 1 when a job failed, no row loaded or an idle floor is missed."""

import json
import math
import statistics
import sys
from pathlib import Path
from typing import Any

Row = dict[str, Any]

# Stock idle-seat defeat minimums (T1-1 kill check A): a bot rule may not make the idle seat fall earlier.
FLOORS: dict[str, int] = {
    "Dry Wells": 7414,
    "Ashfall 2,6": 10698,
    "Ashfall 3,7": 10314,
    "Broken Crown 1v1": 7887,
    "Broken Crown 1v2": 7413,
}
FACTIONS = ("usa", "china", "frc")


def read_found(path: Path) -> list[Row] | None:
    try:
        return [json.loads(line[7:]) for line in path.read_text().splitlines() if line.startswith("BOTLAB ")]
    except (OSError, ValueError):
        return None


def load_rows(folder: Path) -> tuple[list[Row], list[str]]:
    rows: list[Row] = []
    failed: list[str] = []
    for marker in sorted(folder.glob("*.exit")):
        job = marker.name.removesuffix(".exit")
        found = read_found(folder / f"{job}.jsonl") if marker.read_text().startswith("exit=0 ") else None
        if found is None or len(found) != 1:
            failed.append(job)
            continue
        found[0]["job"] = job
        rows.append(found[0])
    return rows, failed


def group_of(row: Row) -> str:
    if row["map"] == "ashfall":
        return f"Ashfall {row['starts']}"
    if row["map"] == "broken_crown":
        return "Broken Crown 1v1" if len(row["teams"]) == 2 else "Broken Crown 1v2"
    return "Dry Wells"


def percentile(values: list[float], share: float) -> float:
    ordered = sorted(values)
    return ordered[max(math.ceil(share * len(ordered)) - 1, 0)]


def idle_rows(rows: list[Row]) -> list[Row]:
    return [r for r in rows if r["idle"] and not r["tower"]]


def waves(rows: list[Row]) -> list[tuple[str, Row]]:
    return [(seat["faction"], wave) for r in rows for seat in r["seats"] for wave in seat["waves"]]


def bot_vs_bot_lines(rows: list[Row]) -> list[str]:
    matches = [r for r in rows if not r["idle"]]
    open_ones = [r["job"] for r in matches if not r["ended"]]
    lines = [f"bot vs bot: {len(matches) - len(open_ones)} ended, {len(open_ones)} not ended by the cap"]
    return lines + [f"  not ended: {job}" for job in open_ones]


def idle_lines(rows: list[Row]) -> tuple[list[str], bool]:
    lines = ["idle defeat tick (min / median) against the floor:"]
    passed = True
    for group, floor in FLOORS.items():
        seats = [s for r in idle_rows(rows) if group_of(r) == group for s in r["idle"]]
        if not seats:
            lines.append(f"  {group}: no rows")
            continue
        ticks = [s["defeat_tick"] for s in seats if s["defeat_tick"] >= 0]
        open_count = len(seats) - len(ticks)
        ok = bool(ticks) and open_count == 0 and min(ticks) >= floor
        passed = passed and ok
        low = f"{min(ticks)} / {statistics.median(ticks):.0f}" if ticks else "- / -"
        lines.append(f"  {group}: {low} floor {floor} open {open_count} of {len(seats)} {'PASS' if ok else 'FAIL'}")
    return lines, passed


def vehicle_lines(rows: list[Row]) -> list[str]:
    lines = ["waves from wave 1 with no vehicle, factory standing / not (of waves from wave 1):"]
    for faction in FACTIONS:
        late = [w for f, w in waves(rows) if f == faction and w["wave"] >= 1]
        bare = [w for w in late if w["veh_value"] == 0]
        standing = sum(1 for w in bare if w["factory_up"])
        lines.append(f"  {faction}: {standing} / {len(bare) - standing} of {len(late)}")
    lines.append("vehicle share by value, wave 0 / 1 / 2 / 3+ (percent):")
    for faction in FACTIONS:
        cells = []
        for low, high in ((0, 0), (1, 1), (2, 2), (3, 10**6)):
            picked = [w for f, w in waves(rows) if f == faction and low <= w["wave"] <= high]
            value = sum(w["value"] for w in picked)
            cells.append(f"{100 * sum(w['veh_value'] for w in picked) / value:.0f}" if value else "-")
        lines.append(f"  {faction}: {' / '.join(cells)}")
    return lines


def factory_lines(rows: list[Row]) -> list[str]:
    lines = ["factories lost / rebuilt / never rebuilt, bot seats:"]
    for faction in FACTIONS:
        seats = [s for r in rows for s in r["seats"] if s["faction"] == faction]
        lost = sum(len(s["factory_lost"]) for s in seats)
        back = sum(len(s["factory_back"]) for s in seats)
        lines.append(f"  {faction}: {lost} / {back} / {lost - back} of {len(seats)} seats")
    return lines


def tower_lines(rows: list[Row]) -> list[str]:
    lines = ["tower killed (tick, -1 never), by bot faction:"]
    for faction in FACTIONS:
        ticks = [
            r["tower"]["died_tick"] for r in rows if r["tower"] and any(s["faction"] == faction for s in r["seats"])
        ]
        lines.append(f"  {faction}: {ticks if ticks else 'no rows'}")
    return lines


def spread_lines(rows: list[Row]) -> list[str]:
    lines = [
        "wave spread, median / p90 (cells): farthest unit from the centroid | centroid to the 3 slowest, at launch and at first contact:"
    ]
    for faction in FACTIONS:
        cells = []
        for moment in ("launch", "contact"):
            spreads = [w[moment] for f, w in waves(rows) if f == faction and w[moment]]
            for key in ("farthest", "slowest"):
                values = [s[key] for s in spreads]
                cells.append(f"{statistics.median(values):.1f} / {percentile(values, 0.9):.1f}" if values else "-")
        lines.append(f"  {faction}: launch {cells[0]} | {cells[1]}   contact {cells[2]} | {cells[3]}")
    slow: dict[str, dict[str, float]] = {}
    for faction, wave in waves(rows):
        for kind, speed in (wave["contact"] or {}).get("slow_units", []):
            slow.setdefault(faction, {})[kind] = speed
    lines.append(f"  slowest kinds at contact (speed): {slow}")
    return lines


def credit_lines(rows: list[Row]) -> list[str]:
    lines = ["credits held, mean after wave 0:"]
    for faction in FACTIONS:
        values = [
            s["credits_mean_after_wave0"]
            for r in rows
            for s in r["seats"]
            if s["faction"] == faction and s["credits_mean_after_wave0"] >= 0
        ]
        lines.append(f"  {faction}: {statistics.mean(values):.0f}" if values else f"  {faction}: -")
    return lines


def summarise(rows: list[Row], failed: list[str]) -> tuple[str, bool]:
    idle, floors_held = idle_lines(rows)
    lines = [f"BOT LAB {len(rows)} matches, {len(failed)} failed jobs"] + [f"  failed: {job}" for job in failed]
    for section in (
        bot_vs_bot_lines(rows),
        idle,
        vehicle_lines(rows),
        factory_lines(rows),
        tower_lines(rows),
        spread_lines(rows),
        credit_lines(rows),
    ):
        lines += section
    return "\n".join(lines), bool(rows) and floors_held and not failed


def main() -> int:
    folder = Path(sys.argv[1])
    text, ok = summarise(*load_rows(folder))
    print(text)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
