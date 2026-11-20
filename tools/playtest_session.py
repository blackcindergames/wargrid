#!/usr/bin/env python3
"""Read a playtest session file: print answers and markers, extract JPGs, prepare replays, compare recorded hash rows.

Output files (JPGs, .cmd) go next to the session file, never into the repository.
"""

import argparse
import base64
import json
import sys
from pathlib import Path


def load_session(path: Path) -> dict:
    session = json.loads(path.read_text())
    if session.get("format") != 1:
        raise SystemExit(f"unsupported session format {session.get('format')!r} (this tool reads 1)")
    for match in session["matches"]:
        for key in ("seed", "seat", "end_tick"):
            match[key] = int(match[key])
        for marker in match["markers"]:
            marker["tick"] = int(marker["tick"])
            marker["selected"] = [int(e) for e in marker["selected"]]
    for answer in session["answers"].values():
        answer["score"] = int(answer["score"])
    return session


def _jpg_path(path: Path, k: int, i: int) -> Path:
    return path.with_name(f"{path.stem}-m{k}-{i}.jpg")


def write_jpgs(session: dict, path: Path) -> list[Path | None]:
    out: list[Path | None] = []
    for k, match in enumerate(session["matches"], 1):
        for i, marker in enumerate(match["markers"], 1):
            if not marker.get("jpg"):
                out.append(None)
                continue
            target = _jpg_path(path, k, i)
            target.write_bytes(base64.b64decode(marker["jpg"]))
            out.append(target)
    return out


def summary_lines(session: dict, jpgs: list[Path | None]) -> list[str]:
    head = f"SESSION build={session['build']} focus={session['focus']} started={session['started']}"
    lines = [f"{head} matches={len(session['matches'])}"]
    lines += [f"CHECK {cid} {'yes' if done else 'no'}" for cid, done in session["checklist"].items()]
    lines += [f"ANSWER {qid} {a['score']} {a['text']}" for qid, a in session["answers"].items()]
    flat = iter(jpgs)
    for k, m in enumerate(session["matches"], 1):
        lines.append(
            f"MATCH {k} {m['mode']} {m['map']} seed={m['seed']} seat={m['seat']} end_tick={m['end_tick']} "
            f"build={_build(session, m)} result={m['result']}"
        )
        for i, mk in enumerate(m["markers"], 1):
            jpg = next(flat, None)
            camera = ",".join(str(c) for c in mk["camera"])
            selected = ",".join(str(e) for e in mk["selected"])
            lines.append(
                f"MARKER {k}.{i} tick={mk['tick']} {mk['kind']} text={json.dumps(mk['text'])} "
                f"comment={json.dumps(mk['comment'])} camera={camera} selected={selected} jpg={jpg or '-'}"
            )
    return lines


def _build(session: dict, match: dict) -> str:
    return match.get("build", session["build"])


def _write_hashes(match: dict, hashes: Path) -> None:
    rows = match.get("tick_hashes")
    if rows is None:
        hashes.unlink(missing_ok=True)
    else:
        hashes.write_text("".join(row + "\n" for row in rows))


def _parse_hash_rows(path: Path) -> list[tuple[int, str]]:
    rows = []
    lines = path.read_text().splitlines() if path.exists() else []
    for n, line in enumerate(lines, 1):
        tick, sep, digest = line.partition("\t")
        if not (sep and tick.isdigit() and digest):
            raise ValueError(f"malformed hash row {n} in {path.name}")
        rows.append((int(tick), digest))
    return rows


def compare_hashes(recorded: Path, ring: Path) -> tuple[int, str]:
    """Exit code and one line: 0 all recorded rows equal, 1 first problem, 2 malformed row."""
    try:
        rows, replayed = _parse_hash_rows(recorded), dict(_parse_hash_rows(ring))
    except (ValueError, OSError) as err:  # UnicodeError is a ValueError
        return 2, str(err)
    last_equal = None
    for tick, digest in rows:
        if tick not in replayed:
            return 1, f"replay ended before tick {tick}"
        if replayed[tick] != digest:
            earlier = f"last equal row at tick {last_equal}" if last_equal is not None else "no earlier recorded row"
            return 1, f"first differing row at tick {tick}, {earlier}"
        last_equal = tick
    return 0, ""


def replay_rows(session: dict, path: Path) -> list[str]:
    rows = []
    for k, m in enumerate(session["matches"], 1):
        if m.get("unfinished"):
            print(f"match {k} was cut short: no replay", file=sys.stderr)
            continue
        cmd = path.with_name(f"{path.stem}-m{k}.cmd")
        cmd.write_text("".join(line + "\n" for line in m["commands"]))
        _write_hashes(m, cmd.with_suffix(".hashes"))
        factions = "-" if m["mode"] == "online" else ",".join(m["factions"])
        ticks = ",".join(str(mk["tick"]) for mk in m["markers"]) or "-"
        row = [
            str(k),
            str(cmd),
            m["mode"],
            m["map"],
            str(m["seed"]),
            factions,
            str(m["end_tick"]),
            m.get("end_digest", ""),
            ticks,
            _build(session, m),
        ]
        rows.append("\t".join(row))
    return rows


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, nargs="?")
    parser.add_argument(
        "--replay-args", action="store_true", help="write .cmd files and print one replay row per match"
    )
    parser.add_argument(
        "--compare-hashes",
        nargs=2,
        type=Path,
        metavar=("RECORDED", "RING"),
        help="compare recorded rows with ring rows",
    )
    args = parser.parse_args(argv)
    if args.compare_hashes:
        code, line = compare_hashes(*args.compare_hashes)
        if line:
            print(line)
        return code
    if args.file is None:
        parser.error("the session file is required")
    try:
        session = load_session(args.file)
    except SystemExit as err:
        print(err, file=sys.stderr)
        return 2
    if args.replay_args:
        lines = replay_rows(session, args.file)
    else:
        lines = summary_lines(session, write_jpgs(session, args.file))
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
